# add_host.rb
#
# This is a ruby script that gets the count of currently active alerts broken down by severity
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
# Authors: Phil Schorr, Ethan
#

# require 'rubygems'   #needed for Ruby 1.8.7 support
require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'optparse'   #not needed for RightScript

def get_alerts()
  resp = rpc("getAlerts", {"level" => "warn"})
  alert_json = JSON.parse(resp)
  if alert_json['data'] 
    warns = 0
    error = 0
    crit = 0
    alert_json['data']['alerts'].each do | alert |
      if alert['level'].eql?("critical")
        crit = crit + 1
      elsif alert['level'].eql?("error")
        error = error + 1
      elsif alert['level'].eql?("warn")
        warns = warns + 1
      end
    end
  end
  puts "Alerts by severity:"
  puts "critical = #{crit.to_s}"
  puts "error = #{error.to_s}"
  puts "warn = #{warns.to_s}"
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
    opts.banner = "Usage: get_count_alerts.rb -c <company> -u <user> -p <password> -C <collectorName> [-d]"

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

#required inputs
@company = @options[:company]
@user = @options[:user]
@password = @options[:password]
@collector = @options[:collector]

get_alerts

