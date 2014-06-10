# bulk_add_hosts.rb
#
# This is a ruby script to handle the mass host imports
#
# Requires:
# Ruby
# Ruby gems
# csv
# json
# open-url
# net/http(s)
# rbconfig
#
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
#
# Authors: Perry Yang, Ethan Culler
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

GLOBAL_GROUP_ID =1
def main
  file  = @file
  filecontent = File.open(file)

  #update date to use ruby date functions (make this platform agnostic)
  # Currently this script can only be run on linux machines with a date command line function
  #  date = `date +"%Y%m%d%H%M%S"`
  #  date = Time.now.strftime "%Y%m%d%H%M%S"
  #  groupname = "lmsupport-import-"+"#{date}".chomp
  groupname = "lmsupport-import-#{Time.now.strftime "%Y%m%d%H%M%S"}".chomp
  string = rpc("getHostGroups") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  my_arr=hostgroups['data']
  
  group_name_id_map = Hash.new
  my_arr.each do |value| 
    if value["appliesTo"].eql?""
      group_name_id_map[value["fullPath"]] = value["id"]
    end
  end
      
  lm_group_id = group_name_id_map[groupname]
  csv = CSV.new(filecontent, {:headers => true})
  
  csv.each do |row|
    #Skip row in loop if the line is commented out (A.K.A. starts with a '#' character)
    sleep(1.0/100.0)
    next if row[0].start_with?('#')

    # validates presence of the hostname and collector id
    # next update: validate all rows before updating the account
    # give feedback on what lines/fields of the CSV will be problems
    if row["hostname"].nil? or row["collector_id"].nil?
      puts "Error: All hosts MUST have a valid hostname and collector ID"
      exit(1)
    end
    @hostname = row["hostname"]
    @collector_id = row["collector_id"]
    @description = row["description"]
    @properties = row["properties"]
    @display_name = row["display_name"]

    hosts_response = rpc("getHosts",{"hostGroupId"=>GLOBAL_GROUP_ID})
    hosts_json = JSON.parse(hosts_response)
    host_list = hosts_json["data"]["hosts"]
    host_list.each do |host|
      if (host["hostName"].eql?@hostname and host["agentId"].to_s.eql?@collector_id) or host["displayedAs"].eql?@display_name
        @hostId = host["id"]
      end
    end   
 
    # check for precense of a hostgroup and if there is, find the groupids 
    group_list = build_group_list(row["group_list"], "", group_name_id_map)
        

 
    puts "Updating host #{@hostname} to LogicMonitor"
    puts "RPC Response:"
    puts rpc("updateHost", {"hostName" =>@hostname, "id" => @hostId, "displayedAs" =>@display_name, "agentId" => @collector_id, "hostGroupIds" => group_list.to_s, "description" => @description})
  end
end

def rpc(action, args={})
  company = @company
  username = @user
  password = @password
  url = "https://#{company}.logicmonitor.com/santaba/rpc/#{action}?"
  args.each_pair do |key, value|
    url << "#{key}=#{value}&"
  end 
  url << "c=#{company}&u=#{username}&p=#{password}&"
  url << get_properties(@properties).to_s
  uri = URI(URI.encode url)
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

def group_id_map(fullpath)
  string = rpc("getHostGroups") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  my_arr=hostgroups['data']

  group_name_id_map = Hash.new
  my_arr.each do |value|
    if value["appliesTo"].eql?""
      group_name_id_map[value["fullPath"]] = value["id"]
    end
  end
  return group_name_id_map[fullpath]
end

def build_group_list(fullpaths, import_group_id, map)
  fullpathids = ""
  if not fullpaths.nil?
    path_array = fullpaths.split(":")
    path_array.each do |path|
      if map[path] #redundant check once dynamic group creation is added
        fullpathids << map[path].to_s
        fullpathids << ","
      else
        recursive_group_create(path,true)
        fullpathids << group_id_map(path).to_s
        fullpathids << ","
      end
    end
  end
 
  return fullpathids
end

def build_group_param_hash(fullpath, alertenable, parent_id)
  path = fullpath.rpartition("/")
  hash = {"name" => path[2]}
  hash.store("parentId", parent_id)
  hash.store("alertEnable", alertenable)
  return hash
end


def recursive_group_create(fullpath, alertenable)
  path = fullpath.rpartition("/")
  parent_path = path[0]
  puts("checking for parent: #{path[2]}")
  parent_id = 1
  if parent_path.nil? or parent_path.empty?
    puts("highest level")
  else
    parent = get_group(parent_path)
    if not parent.nil?
      puts("parent group exists")
      parent_id = parent["id"]
    else
      parent_ret = recursive_group_create(parent_path, true) #create parent group with basic information.
      unless parent_ret.nil?
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

def get_properties(properties)
  propindex=""
  if not @properties.nil?
    props = @properties.split(":")
    index = 0
    props.each do |p|
      eachProp = p.split("=")
      key = eachProp[0]
      value = eachProp[1]
      propindex << "propName#{index}=#{key}&propValue#{index}=#{value}&"
      index = index + 1
    end
    @propindex=propindex.chomp("&")
  end
end

def get_group(fullpath)
  returnval = nil
  group_list = JSON.parse(rpc("getHostGroups", {}))
  if group_list["data"].nil?
    puts("Unable to retrieve list of host groups from LogicMonitor Account")
    p group_list
  else
    group_list["data"].each do |group|
      if group["fullPath"].eql?(fullpath.sub(/^\//, ""))    #Check to see if group exists
        returnval = group
      end
    end
  end
  returnval
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
