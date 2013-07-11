# remove_collector.rb
#
# This is a ruby script to handle the deletion and uninstallation of LogicMonitor collectors.
#
# Requires:
# Ruby
# Ruby gems
#   json
# open-url
# net/http(s)
#
# Created for use as a RightScale RightScript.
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
# RightScale Marketplace
#
# Authors: Perry Yang, Ethan Culler-Mayeno
#

require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'optparse'   #not needed for RightScript  

opt_error = false
begin
  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: add_collector.rb -c <company> -u <user> -p <password> [-d]"

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

if opt_error
  exit 1
end

#
# RightScale Input handling here.
#
@company = @options[:company]
@user = @options[:user]
@password = @options[:password]
@name = `hostname`.strip
@debug = @options[:debug]
@install_dir = "/usr/local/logicmonitor"

#runs the utility functions and controls the flow of the program
def run(name, install_dir)

  agent_status = `service logicmonitor-agent status`
  unless agent_status.include?("not running")
    puts "LogicMonitor collector is running"
    puts `service logicmonitor-agent stop`
  end

  watchdog_status = `service logicmonitor-watchdog status`
  unless watchdog_status.include?("not running")
    puts "LogicMonitor watchdog is running"
    puts `service logicmonitor-watchdog stop`
  end

  collector = get_collector(name)  
  file_name = "/logicmonitorsetup" + collector["id"].to_s + "_" + get_arch + ".bin"
  install_file = install_dir + file_name
  agent_file = install_dir + "/agent/conf/agent.conf"
  if File.exists?(agent_file)
    uninstall_collector(install_dir)
  end
  if File.exists?(install_file)
    delete_installer(install_file)
  end
  if collector
    puts "Matching collector found on server"
    delete_collector(name)
  else
    puts "No matching collectors found"
  end
  
end


###################################################################
#                                                                 #
#       Functions for handling the LogicMonitor Collector         #
#                                                                 #
###################################################################

def delete_collector(name)
  puts "trying to delete collector"
  collector = get_collector(name)
  delete_response = rpc("deleteAgent", {"id" => collector["id"]})
  if @debug
    puts delete_response
  end
end

# Checks for the existance of a collector
# with description field == desc
# Returns a collector object or nil
def get_collector(name)
  collector = nil
  collector_list_json = rpc("getAgents", {})
  if @debug
      puts collector_list_json
  end
  collector_list = JSON.parse(collector_list_json)
  if collector_list["status"] == 200
    if @debug
      puts "List of existing collectors successfully retrieved"
    end
    collector_list["data"].each do |c|
      if c["description"].eql?(name)
        if @debug
          puts "Found collector with name matching #{name}"
        end
        collector = c
      end
    end
  else
    puts "Unable to retieve the list of existing collectors."
    puts "Server responded with #{collector_list_json}"
    puts "Exiting"
    exit 2
  end
  collector
end

###################################################################
#                                                                 #
#   Functions for handling the LogicMonitor Collector Installer   #
#                                                                 #
###################################################################

# Create the installer file
def delete_installer(install_file)
  puts "Deleting install file"
  `rm #{install_file}`
end

#returns the architecture of the current device
def get_arch
  arch = `uname -m`
  if arch.include?("64")
    return "64"
  else
    return "32"
  end
end


# Run the LogicMonitor collector installer
def uninstall_collector(install_dir)
  puts "Uninstalling LogicMonitor collector"
  execution = `#{install_dir}/agent/bin/uninstall.pl`
  puts execution.to_s
end


###################################################################
#                                                                 #
#   Utility functions                                             #
#                                                                 #
###################################################################


# Wrapper function for building LogicMonitor API URL's
# and executing the associated RPCs 
# returns a JSON string (the response from the LogicMonitor API) or nil
def rpc(action, args={})
  company = @company
  username = @user
  password =  @password
  url = "https://#{company}.logicmonitor.com/santaba/rpc/#{action}?"
  first_arg = true
  args.each_pair do |key, value|
    url << "#{key}=#{value}&"
  end
  url << "c=#{company}&u=#{username}&p=#{password}"
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
    puts "Exiting"
    exit 3
  rescue Error => e
    puts "There was an issue."
    puts e.message
    puts "Exiting"
    exit 4
  end
  return nil
end


# Execute the run function.
run(@name, @install_dir)