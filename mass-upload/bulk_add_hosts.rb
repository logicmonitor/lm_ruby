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


def main
  id    = []
  names = []
  file  = @file
  filecontent = File.open(file)
  hostpaths = []
  @a = 0

  #update date to use ruby date functions (make this platform agnostic)
  # Currently this script can only be run on linux machines with a date command line function
  #  date = `date +"%Y%m%d%H%M%S"`
  #  date = Time.now.strftime "%Y%m%d%H%M%S"
  #  groupname = "lmsupport-import-"+"#{date}".chomp
  groupname = "lmsupport-import-#{Time.now.strftime "%Y%m%d%H%M%S"}".chomp
  rpc("addHostGroup", {"alertEnable" => false, "name" => groupname})
 
  string = rpc("getHostGroups") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  my_arr=hostgroups['data']
  
  group_name_id_map = Hash.new
  my_arr.each do |value|
    group_name_id_map[value["fullPath"]] = value["id"]
  end

  lm_group_id = group_name_id_map[groupname]
  csv = CSV.new(filecontent, {:headers => true})
  
  csv.each do |row|
    #Skip row in loop if the line is commented out (A.K.A. starts with a '#' character)
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

    # check for a display_name
    if row["display_name"].nil?
      @display_name = @hostname
    else
      @display_name = row["display_name"]
    end
    
    # check for precense of a hostgroup and if there is, find the groupids 
    group_list = build_group_list(row["group_list"], lm_group_id, group_name_id_map)

    puts "Adding host #{@hostname} to LogicMonitor"
    puts "RPC Response:"
    puts rpc("addHost", {"hostName" =>@hostname, "displayedAs" =>@display_name, "agentId" => @collector_id, "hostGroupIds" => group_list.to_s})

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
  url << "c=#{company}&u=#{username}&p=#{password}"
  #  puts(url)
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

def build_group_list(fullpaths, import_group_id, map)
  fullpathids = ""
  if not fullpaths.nil?
    path_array = fullpaths.split(":")
    path_array.each do |path|
      #Add dynamic group creation
      #This might want to be a flag?
      #if not group_name_id_map[path]
      #create group here
      #update group_name_map
      #end
      if map[path] #redundant check once dynamic group creation is added
        fullpathids << map[path].to_s
        fullpathids << ","
      end
    end
  end
  fullpathids << import_group_id.to_s
  return fullpathids
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
