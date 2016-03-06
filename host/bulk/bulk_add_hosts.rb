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
require 'logger'

def main
  @logger = Logger.new("bulk_add.log")
  @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
  file  = @file
  begin
    filecontent = File.open(file)
  rescue Errno::ENOENT => e
    puts "Invalid CSV entered. Please make sure path/filename are correct."
    @logger.error "Invalid CSV entered. Please make sure path/filename are correct."
    exit(1)
  end
 
  string = rpc("getHostGroups") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  if hostgroups['status'] == 403
    puts "Authentication failed. Check the url, username, and password."
    @logger.error "Authentication failed. Check the url, username, and password."
    exit(1)
  else
    groupname = "lmsupport-import-#{Time.now.strftime "%Y%m%d%H%M%S"}".chomp
    rpc("addHostGroup", {"alertEnable" => false, "name" => groupname})

    my_arr=hostgroups['data']
    group_name_id_map = Hash.new
    my_arr.each do |value|
      group_name_id_map[value["fullPath"]] = value["id"]
    end
    lm_group_id = group_name_id_map[groupname]
  end

  @successful_uploads = []
  @failed_uploads = []
  @duplicate_uploads = []
  @total_uploads = 0
  csv = CSV.new(filecontent, {:headers => true})
  csv.each do |row|
    #Skip row in loop if the line is commented out (A.K.A. starts with a '#' character)
    next if row[0].start_with?('#')

    # validates presence of the hostname and collector id
    # next update: validate all rows before updating the account
    # give feedback on what lines/fields of the CSV will be problems
    if row["hostname"].nil? or row["collector_id"].nil?
      puts "Error: All hosts MUST have a valid hostname and collector ID"
      @logger.error "All hosts MUST have a valid hostname and collector ID. Check CSV for error."
      exit(1)
    end
    @hostname = row["hostname"]
    @collector_id = row["collector_id"]
    @description = row["description"]
    @properties = row["properties"]
    @link = row["link"]
    # check for a display_name
    if row["display_name"].nil?
      @display_name = @hostname
    else
      @display_name = row["display_name"]
    end
    
    # check for precense of a hostgroup and if there is, find the groupids 
    group_list = build_group_list(row["group_list"], lm_group_id, group_name_id_map)

    
    # check if properties are nil

    puts "Adding host #{@hostname} to LogicMonitor"
    puts "RPC Response:"

    host_args = {"hostName" =>@hostname, 
                 "displayedAs" =>@display_name, 
                 "agentId" => @collector_id, 
                 "hostGroupIds" => group_list.to_s, 
                 "description" => @description,
                 "link" => @link
                }
       
    
    host_args = host_args.merge(hash_to_lm(properties_to_hash(@properties)))

    response = rpc("addHost", host_args)
    response_json = JSON.parse(response)
    if response_json["status"] == 200
      puts response
      @successful_uploads << @hostname
    elsif response_json["status"] == 600
      puts "Error: #{response}"
      @logger.error "Error adding host #{@hostname}: #{response}"
      @duplicate_uploads << @hostname
    else
      puts "Error: #{response}"
      @logger.error "Error adding host #{@hostname}: #{response}"
      @failed_uploads << @hostname
    end
    @total_uploads = @total_uploads + 1
  end
  puts "------------------Bulk Add Summary------------------"
  puts "Number of Uploads Attempted: #{@total_uploads}"
  puts "Number of Devices Successfully Uploaded: #{@successful_uploads.size}"
  puts "Devices Successfully Uploaded: #{@successful_uploads}"
  puts "Number of Devices that already existed in Logicmonitor Account: #{@duplicate_uploads.size}"
  puts "Devices that already existed in Logicmonitor Account: #{@duplicate_uploads}"
  puts "Number of Devices Unsucessfully Uploaded: #{@failed_uploads.size}"
  puts "Devices Unsuccessfully Uploaded: #{@failed_uploads}"
end

#makes property hash based on property string (from csv)
#csv property format: propname0=propvalue0:propname1=propvalue1:propname2=propvalue2
def properties_to_hash(properties)
  property_hash = {}
  index = 0
  properties_valid = properties || ''
  props = properties_valid.split(":")
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
  hash.each do |key, value|
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
    @logger.error "SocketError: There was an issue communicating with #{url}. Please make sure everything is correct and try again."
  rescue Exception => e
    puts "There was an issue."
    @logger.error "Error: #{e.message}"
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
    group_name_id_map[value["fullPath"]] = value["id"]
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
  fullpathids << import_group_id.to_s
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

def get_group(fullpath)
  returnval = nil
  group_list = JSON.parse(rpc("getHostGroups", {}))
  if group_list["data"].nil?
    puts("Unable to retrieve list of host groups from LogicMonitor Account")
    @logger.error "Unable to retrieve list of host groups from LogicMonitor Account"
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
