# add_collector.rb
#
# This is a ruby script to handle the creation and installation of LogicMonitor collectors.
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

#runs the utility functions and controls the flow of the program
def run(name, install_dir)
  puts "checking collector"
  collector = get_collector(name)
  if collector
    puts "Matching collector found on server"
  else
    puts "No matching collectors found"
    create_collector(name)
  end
  collector = get_collector(name)  
  unless Dir.exists?(install_dir)
    puts "Creating LogicMonitor installation directory"
    begin
      Dir.mkdir(install_dir, 0755)
    rescue SystemCallError => sce
      puts "Unable to create the installation directory."
      puts sce.inspect
      puts "Exiting"
      exit 6
    end
  end
  file_name = "/logicmonitorsetup" + collector["id"].to_s + "_" + get_arch + ".bin"
  install_file = install_dir + file_name
  if File.exists?(install_file)
    puts "Installer file exists."
    puts "Skipping download."
  else
    create_installer(install_file, collector["id"])
  end
  agent_file = install_dir + "/agent/conf/agent.conf"
  if File.exists?(agent_file)
    puts "Agent previously installed."
    puts "Skipping installation."
  else
    install_collector(install_dir, file_name)
  end
  ensure_running()
end


###################################################################
#                                                                 #
#       Functions for handling the LogicMonitor Collector         #
#                                                                 #
###################################################################

def create_collector(name)
  puts "trying to create a new collector"
  create_response = rpc("addAgent", {"autogen" => "true", "description" => name})
  if @debug
    puts create_response
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
def create_installer(install_file, id)
  puts "Downloading install file"
  File.open(install_file, "w+"){ |f|
    f.write(download_install_file("logicmonitorsetup", {"id" => id.to_s, "arch" => get_arch,}))
  }
  puts "Download complete"
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

# Call LogicMonitor RPC to request installer binary
def download_install_file(action, args={})
  company = @company
  username = @user
  password = @password
  url = "https://#{company}.logicmonitor.com/santaba/do/#{action}?"
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
    puts se.message
  rescue Error => e
    puts "There was an issue."
    puts e.message
  end
  return nil
end

# Run the LogicMonitor collector installer
def install_collector(install_dir, file_name)
  puts "Installing LogicMonitor collector"
  install_file = install_dir + file_name
  puts install_file
  File.chmod(0755, install_file)
  execution = `cd #{install_dir}; .#{file_name} -y`
  puts execution.to_s
end


# Ensure that the logicmonitor collector and watchdog are running
def ensure_running
  agent_status = `service logicmonitor-agent status`
  if agent_status.include?("not running")
    puts "LogicMonitor collector isn't running"
    puts `service logicmonitor-agent start`
  else
    puts "LogicMonitor collector is running"
  end

  watchdog_status = `service logicmonitor-watchdog status`
  if watchdog_status.include?("not running")
    puts "LogicMonitor watchdog isn't running"
    puts `service logicmonitor-watchdog start`
  end
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
    puts "There was an issue communicating with #{url}. Please make sure everything is correct and try again. Exiting"
    puts se.message
    exit 3
  rescue Error => e
    puts "There was an issue."
    puts e.message
    puts "Exiting"
    exit 4
  end
  return nil
end


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

@company = @options[:company]
@user = @options[:user]
@password = @options[:password]
@name = `hostname -f`.strip
@debug = @options[:debug]
@install_dir = "/usr/local/logicmonitor"

# Execute the run function.
run(@name, @install_dir)
