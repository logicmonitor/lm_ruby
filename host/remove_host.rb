# remove_host.rb
#
# This is a ruby script to handle the removal of devices from LogicMonitor WebApp
#
# Requires:
# Ruby
# Ruby gems
#   json
# open-url
# net/http(s)
#
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
#
# Authors: Perry Yang, Ethan Culler-Mayeno
#

# require 'rubygems'   #needed for Ruby 1.8.7 support
require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'optparse'

def run(hostname, displayname, collector)
  host_exist = get_host_by_displayname(displayname) || get_host_by_hostname(hostname, collector)
  if host_exist
    delete_resp = rpc("deleteHost", {"hostId" => host_exist["id"], "deleteFromSystem" => true})
  else
    puts "Unable to find matching host"
    puts "Exiting"
    exit 1
  end 
end

###################################################################
#                                                                 #
#       Functions for handling the input strings                  #
#                                                                 #
###################################################################

def parse_groups(str)
  return str.gsub(", ", ",").split(",")
end

def parse_properties(properties)
  return JSON.parse(properties)
end

###################################################################
#                                                                 #
#       Functions for handling the LogicMonitor host              #
#                                                                 #
###################################################################

def remove_host(hostname, displayname, collector, description, groups, properties, alertenable)
  puts "d LogicMonitor host \"#{hostname}\""
  groups.each do |group|
    if get_group(group).nil?
      puts "Couldn't find parent group #{group}. Creating." 
      recursive_group_create( group, nil, nil, true)
    end
  end
  add_resp = rpc("addHost", build_host_hash(hostname, displayname, collector, description, groups, properties, alertenable))
  #puts add_resp
end

###################################################################
#                                                                 #
#   Utility functions                                             #
#                                                                 #
###################################################################


#return a host object from displayname
def get_host_by_displayname(displayname)
  host = nil
  host_json = rpc("getHost", {"displayName" => URI::encode(displayname)})
  #puts(host_json)
  host_resp = JSON.parse(host_json)
  if host_resp["status"] == 200
    host = host_resp["data"]
#      puts("Found host matching #{displayname}")
  end
  host
end

#requires hostname and collector
def get_host_by_hostname(hostname, collector)
  host = nil
  hosts_json = rpc("getHosts", {"hostGroupId" => 1})
  hosts_resp = JSON.parse(hosts_json)
  collector_resp = JSON.parse(rpc("getAgents", {}))
  if hosts_resp["status"] == 200
    hosts_resp["data"]["hosts"].each do |h|
      if h["hostName"].eql?(hostname)
#          puts("Found host with matching hostname: #{resource[:hostname]}")
#          puts("Checking agent match")
        if collector_resp["status"] == 200
          collector_resp["data"].each do |c|
            if c["description"].eql?(collector)
              host = h
            end
          end
        else
          puts("Unable to retrieve collector list from server")
        end
      end
    end
  else
    puts("Unable to retrieve host list from server" )
  end
  host
end


# create hash for add host RPC
def build_host_hash(hostname, displayname, collector, description, groups, properties, alertenable)
  h = {}
  h.store("hostName", hostname)
  h.store("displayedAs", displayname)
  agent = get_agent(collector)
  if agent
    h.store("agentId", agent["id"])
  end
  if description
    h.store("description", URI::encode(description))
  end
  group_ids = ""
  groups.each do |group|
    group_ids << get_group(group)["id"].to_s
    group_ids << ","
  end
  h.store("hostGroupIds", group_ids.chop)
  h.store("alertEnable", alertenable)
  index = 0
  unless properties.nil?
    properties.each_pair do |key, value|
      h.store("propName#{index}", key)
      h.store("propValue#{index}", value)
      index = index + 1
    end
  end
  h
end

# Return a collector object based on the description
def get_agent(description)
  agents = JSON.parse(rpc("getAgents", {}))
  ret_agent = nil
  if agents["data"]
    agents["data"].each do |agent|
      if agent["description"].eql?(description)
        ret_agent = agent
      end
    end
  else
    puts("Unable to get list of collectors from the server")
  end
  ret_agent
end


#Build the proper hash for the RPC function
def build_group_param_hash(fullpath, description, properties, alertenable, parent_id)
  path = fullpath.rpartition("/")
  hash = {"name" => URI::encode(path[2])}
  hash.store("parentId", parent_id)
  hash.store("alertEnable", alertenable)
  unless description.nil?
      hash.store("description", URI::encode(description))
  end
  index = 0
  unless properties.nil?
    properties.each_pair do |key, value|
      hash.store("propName#{index}", key)
      hash.store("propValue#{index}", value)
      index = index + 1
    end
  end
  hash
end


def recursive_group_create(fullpath, description, properties, alertenable)
  path = fullpath.rpartition("/")
  parent_path = path[0]
#    puts("checking for parent: #{path[2]}")
  parent_id = 1
  if parent_path.nil? or parent_path.empty?
    puts("highest level")
  else
    parent = get_group(parent_path)
    if not parent.nil?
#        puts("parent group exists")
      parent_id = parent["id"]
    else
      parent_ret = recursive_group_create(parent_path, nil, nil, true) #create parent group with basic information.
      unless parent_ret.nil?
        parent_id = parent_ret
      end
    end
  end
  hash = build_group_param_hash(fullpath, description, properties, alertenable, parent_id)
  resp_json = rpc("addHostGroup", hash)
  resp = JSON.parse(resp_json)
  if resp["data"].nil?
    nil
  else
    resp["data"]["id"]
  end
end


# return a group object if "fullpath" exists or nil
def get_group(fullpath)
  returnval = nil 
  group_list = JSON.parse(rpc("getHostGroups", {}))
  if group_list["data"].nil? 
    puts("Unable to retrieve list of host groups from LogicMonitor Account")
  else
    group_list["data"].each do |group|
      if group["fullPath"].eql?(fullpath.sub("/", ""))    #Check to see if group exists          
        returnval = group
      end
    end
  end
  returnval
end

def rpc(action, args={})
  company = @company
  username = @user
  password = @password
  url = "https://#{company}.logicmonitor.com/santaba/rpc/#{action}?"
  first_arg = true
  args.each_pair do |key, value|
    url << "#{key}=#{value}&"
  end
  url << "c=#{company}&u=#{username}&p=#{password}"
  #puts(url)
  uri = URI(url)
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

###################################################################
#                                                                 #
#       Begin running part of the script                          #
#                                                                 #
###################################################################

opt_error = false
begin
  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: remove_host.rb -c <company> -u <user> -p <password> -C <collectorName> -H <hostname> [-n <displayname> -d]"

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

    opts.on("-C", "--collector COLLECTOR", "Collector to monitor this host") do |collector|
      @options[:collector] = collector
    end
    
    opts.on("-H", "--name HOSTNAME", "Hostname of this device") do |hname|
      @options[:name] = hname
    end
    
    opts.on("-n", "--displayname DISPLAYNAME", "The human readable name for the host in your LogicMonitor account") do |n|
      @options[:displayname] = n
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
  raise OptionParser::MissingArgument if @options[:collector].nil?
rescue  OptionParser::MissingArgument => ma
  puts "Missing option: -H <hostname>"
  opt_error = true
end  


begin
  raise OptionParser::MissingArgument if @options[:name].nil?
rescue  OptionParser::MissingArgument => ma
  puts "Missing option: -H <hostname>"
  opt_error = true
end  

if opt_error
  exit 1
end

#required inputs
@company = @options[:company]
@user = @options[:user]
@password = @options[:password]
@collector = @options[:collector]
@hostname = @options[:name]

#optional/default inputs
@displayname = @options[:displayname] || @hostname

run(@hostname, @displayname, @collector)