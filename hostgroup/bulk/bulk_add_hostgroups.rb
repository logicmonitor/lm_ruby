# bulk_add_hostgroups.rb
#
# This is a ruby script to handle dynamic host group creation
#
# Requires:
# Ruby
# Ruby gems
# csv
# json
# open-url
# net/http(s)
# rbconfig
# optparse
# pp
# date
#
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
#
# Authors: Sam Dacanay, Ethan Culler-Mayeno, Perry Yang
#


# require 'rubygems'   #needed for Ruby 1.8.7 support
require 'csv'
require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'optparse'
require 'pp'
require 'date'

def main

  file = @file
  #this part is actually awesome. CSV doesn't allow quoting that doesn't encapsulate an entire column/row thingy.
  #in order to allow quoting in an appliesTo (which is pretty common), we make the quote_character of the csv object
  #a character that doesn't appear in our csv (hopefully)
  csv = CSV.open(file, quote_char: "\x00", :headers => true)

  #csv = CSV.new(filecontent, {:headers => true})

  csv.each do |row|
    #Skip row in loop if the line is commented out (A.K.A. starts with a '#' character)
    next if row[0].start_with?('#')

    # validates presence of the dynamic group name field

    if row["groupname"].nil?
      puts "Error: All host gropus MUST have a valid groupname entered"
      exit(1)
    end

    #set instance variables to the value of the row
    @groupname = row["groupname"]
    @appliesTo = row["appliesTo"]
    @grouppath = row["grouppath"]
    @description = row["description"] 
    @properties = row["properties"] 

    #make sure that the group path entered follows Linux directory structure (for consistency and user ease-of-use)
    if not @grouppath.start_with?("/")
        puts "Error: Invalid group path entered, must begin with '/'"
        exit(1)
    end
    @grouppath.slice!(0)

    #makes API call to grab existing host groups
    string = rpc("getHostGroups") 
    hostgroups= JSON.parse(string)
    my_arr=hostgroups['data']

    #for each hostgroup, create a key/value pair that maps a fullpath to its id
    group_name_id_map = {}
    my_arr.each do |value|
      group_name_id_map[value["fullPath"]] = value["id"]
    end

    puts "Adding HostGroup to #{@company}'s LogicMonitor Account"
    puts "RPC Response:"
    puts

    #most important part -> validates grouppath (if parent groups don't exist, creates them)
    #and returns the parentid of the group we are creating once the grouppath is validated.
    @parentid = get_parentid(@grouppath, group_name_id_map)

    #if appliesTo is not nil, assume group should be dynamic
    if @appliesTo.nil?
      static_args = {"alertEnable" => false, 
                   "name" => @groupname, 
                   "parentId" =>  @parentid, 
                   "description" => @description
                  }
      static_args = static_args.merge(hash_to_lm(properties_to_hash(@properties)))
      puts rpc("addHostGroup", static_args)
    #if appliesTo is nil, assume group should be static
    else
      dynamic_args = {"alertEnable" => false, 
                    "dGroup" => true, 
                    "name" => @groupname, 
                    "appliesTo" => @appliesTo, 
                    "parentId" => @parentid, 
                    "description" => @description
                   }
      dynamic_args = dynamic_args.merge(hash_to_lm(properties_to_hash(@properties)))
      puts rpc("addHostGroup", dynamic_args)
    end

  end
  puts
end

###################################################################
#                                                                 #
#                   Helper Functions Below                        #
#                                                                 #
###################################################################

#makes property hash based on property string (from csv)
#csv property format: propname0=propvalue0:propname1=propvalue1:propname2=propvalue2
def properties_to_hash(properties)
  property_hash = {}
  index = 0
  properties_valid = properties || ''
  props = properties.split(":")
  props.each do |p|
    eachProp = p.split("=")
    property_hash[eachProp[0]] = eachProp[1]
    index = index + 1
  end
  return property_hash
end

#takes property hash (from format {"propname0" => "propvalue0", "propname1" => "propvalue1"} to
# lm rpc api hash format {"propName0" => "nameOfProp", "propValue0" => "valueOfProp", "propName1"....}
def hash_to_lm(property_hash)
  lm_hash = {}
  index = 0
  hash = property_hash || {}
  hash.each_pair do |key, value|
    lm_hash["propName#{index}"] = key
    lm_hash["propValue#{index}"] = value
    index = index + 1
  end
  return lm_hash
end

#performs LM RPC based on action and args
def rpc(action, args={})
  auth_hash = {"c" => @company, "u" => @user, "p" => @password}
  uri = URI("https://#{@company}.logicmonitor.com/santaba/rpc/#{action}")
  uri.query = URI.encode_www_form(args.merge(auth_hash))
  begin
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(req)
    return response.body
  rescue SocketError => se
    puts "There was an issue communicating with #{url}. Please make sure everything is correct and try again."
  rescue Exception => e
    puts "There was an issue."
    puts e.message
  end
  return nil
end

#function to update the hash map after groups are created
def group_id_map_update(fullpath, oldmap)
  string = rpc("getHostGroups") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  my_arr=hostgroups['data']

  group_name_id_map = oldmap
  my_arr.each do |value|
    group_name_id_map[value["fullPath"]] = value["id"]
  end
  return group_name_id_map
end

#check fullpath of group being created and if there is a parent group that
#doesn't exist, create it (statically). Returns the parentid
def get_parentid(fullpath, map)

  if not fullpath.nil?
    path = fullpath.rpartition("/")
    parent_path = path[0]

    if map[parent_path] #redundant check once dynamic group creation is added
       parentid = map[parent_path].to_s
    else
      recursive_group_create(parent_path,false)
      map = group_id_map_update(fullpath, map)
      parentid = map[parent_path].to_s
    end

  end

  return parentid

end

#updates the group hash with name, parentId, and alertEnable
def build_group_param_hash(fullpath, alertenable, parent_id)
  path = fullpath.rpartition("/")
  hash = {"name" => path[2]}
  hash.store("parentId", parent_id)
  hash.store("alertEnable", alertenable)
  return hash
end

#retrieves the group json object based on fullpath
def get_group(fullpath)
  returnval = nil
  group_list = JSON.parse(rpc("getHostGroups", {}))
  if group_list["data"].nil?
    puts("Unable to retrieve list of host groups from LogicMonitor Account")
  else
    group_list["data"].each do |group|
      if group["fullPath"].eql?(fullpath.sub(/^\//, ""))    #Check to see if group exists
        returnval = group
      end
    end
  end
  return returnval
end

def recursive_group_create(fullpath, alertenable)
  path = fullpath.rpartition("/")
  parent_path = path[0]
  puts("Checking to see if #{path[2]} exists...")
  parent_id = 1
  if parent_path.nil? or parent_path.empty?
    puts("Parent Path is at highest level...")
  else
    parent = get_group(parent_path)
    if not parent.nil?
      puts("Parent Group exists...")
      parent_id = parent["id"]
    else
      puts("Creating Parent Group...")
      parent_ret = recursive_group_create(parent_path, true) #create parent group with basic information.
      unless parent_ret.nil?
        puts("Parent Groups Created...")
        parent_id = parent_ret
      end
    end
  end
  hash = build_group_param_hash(fullpath, alertenable, parent_id)
  resp_json = rpc("addHostGroup", hash)
  resp = JSON.parse(resp_json)
  if resp["data"].nil?
    nil
  else
    resp["data"]["id"]
  end
end

###################################################################
#                                                                 #
#       Begin running part of the script                          #
#                                                                 #
###################################################################

pt_error = false
begin
  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby bulk_add_hosts.rb -c <company> -u <user> -p <password> -f <file>"

    opts.on("-d", "--debug", "Turn on debug print statements") do |v|
      @options[:debug] = v
    end

    opts.on("-c", "--company COMPANY", "LogicMonitor Account") do |c|
      @options[:company] = c
    end

    opts.on("-u", "--user USERNAME", "LogicMonitor user name") do |u|
      @options[:user] = u
    end

    opts.on("-p", "--password PASSWORD", "LogicMonitor password") do |p|
      @options[:password] = p
    end

    opts.on("-f", "--file FILE", "A CSV file contaning the hosts to be added") do |f|
      @options[:file] = f
    end
    
  end.parse!
rescue OptionParser::MissingArgument => ma
  puts ma.inspect
  opt_error = true
end  

begin
  raise OptionParser::MissingArgument if @options[:company].nil?
rescue  OptionParser::MissingArgument => ma
  puts "Missing option: -c <company>"
  opt_error = true
end  

begin
  raise OptionParser::MissingArgument if @options[:user].nil?
rescue  OptionParser::MissingArgument => ma
  puts "Missing option: -u <username>"
  opt_error = true
end  

begin
  raise OptionParser::MissingArgument if @options[:password].nil?
rescue  OptionParser::MissingArgument => ma
  puts "Missing option: -p <password>"
  opt_error = true
end  

begin
  raise OptionParser::MissingArgument if @options[:file].nil?
rescue  OptionParser::MissingArgument => ma
  puts "Missing option: -f <file>"
  opt_error = true
end  

if opt_error
  exit 1
end

#required inputs
@company = @options[:company]
@user = @options[:user]
@password = @options[:password]
@file = @options[:file]

main()