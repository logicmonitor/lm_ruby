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
# Created for use as a RightScale RightScript.
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
# RightScale Marketplace
#
# Author: Ethan Culler-Mayeno

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

# Checks for the existance of a collector
# with description field == desc
# Returns a collector object or nil
def get_collector(desc)
  #collector_list_json = rpc("")
end

# Wrapper function for building LogicMonitor API URL's
# and executing the associated RPCs 
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
  rescue Error => e
    puts "There was an issue."
    puts e.message
  end
  return nil
end

