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
# NOTE: This script keys off the displayname of the device
#
#
#
# Created for use as a RightScale RightScript.
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
# RightScale Marketplace
#
# Authors: Perry Yang, Ethan Culler-Mayeno
#

# require 'rubygems'   #needed for Ruby 1.8.7 support
require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'time'
require 'date'
require 'optparse'   #not needed for RightScript  


def run(hostname, displayname, collector, starttime, endtime)
  host_exist = get_host_by_displayname(displayname) || get_host_by_hostname(hostname, collector)
#  p host_exist
  if host_exist
    puts "Creating SDT for #{hostname}"
    puts rpc("setHostSDT", {"id" => 0, "type" => 1, "notifyCC" => true, "hostId" => host_exist["id"],
      "year" => starttime.year, "month" => starttime.month, "day" => starttime.day, "hour" => starttime.hour, "minute" => starttime.min,
      "endYear" => endtime.year, "endMonth" => endtime.month, "endDay" => endtime.day, "endHour" => endtime.hour, "endMinute" => endtime.min})
  else
    puts "Unable to find matching host"
    puts "Exiting"
    exit 1
  end 
end


###################################################################
#                                                                 #
#   Utility functions                                             #
#                                                                 #
###################################################################

#return a time object from a comma separated string representing the time
def to_time(timevar)
  if timevar.class == Time
    return timevar
  elsif timevar.class == String
    time_array = timevar.gsub(/\s+/, "").split(",")
    p time_array
    if time_array.length < 5
      puts "Non-default time values must be in the format \"year, month, day, hour, minute\""
      puts "Exiting"
      exit 3
    end
    return Time.new(time_array[0], time_array[1], time_array[2], time_array[3], time_array[4])
  else
    puts "An unrecognized input for a time value was entered."
    puts "Time value #{timevar} with class #{timevar.class} is not supported."
    puts "exiting"
    exit 3
  end
end

#returns the end time from starttime and duration
def end_time(starttime, duration)
  if duration
    endtime = starttime
    duration.split(" ").each do |d|
      case d[-1]
      when "y"
        endtime = Time.new(endtime.year + d.to_i, endtime.month, endtime.day, endtime.hour, endtime.min)
      when "m"
        endtime = Time.new(endtime.year, endtime.month + d.to_i, endtime.day, endtime.hour, endtime.min)
      when "d"
        endtime = Time.new(endtime.year, endtime.month, endtime.day + d.to_i, endtime.hour, endtime.min)
      when "h"
        endtime = Time.new(endtime.year, endtime.month, endtime.day, endtime.hour + d.to_i, endtime.min)
      else
        endtime = Time.new(endtime.year, endtime.month, endtime.day, endtime.hour, endtime.min + d.to_i)
      end
    end
    return endtime
  else
    return endtime + (60*60) #default of 1 hour
  end
end



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
  if collector
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
  end
  host
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
    opts.banner = "Usage: add_collector.rb -c <company> -u <user> -p <password> -C <collectorName> [-h <hostname> -n <displayname> -D <description> -g <grouplist> -P <properties> -a <alertenable> -d]"

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

    opts.on("-h", "--hostname HOSTNAME", "IP Address or FQDN of the host") do |n|
      @options[:displayname] = n
    end

    opts.on("-C", "--collector COLLECTOR", "The FQDN of the collector monitoring this device (required if -h is set)") do |n|
      @options[:displayname] = n
    end
    
    opts.on("-n", "--displayname DISPLAYNAME", "The human readable name for the host in your LogicMonitor account") do |n|
      @options[:displayname] = n
    end

    opts.on("-s", "--starttime STARTTIME", "Time in the format \"year, month, day, hour, min\" for the start time of the SDT") do |s|
      @options[:starttime] = s
    end

    opts.on("-D", "--duration DURATION", "How long this device should be in scheduled downtime. Format: 1y 2m 4d 6h 25") do |dur|
      @options[:duration] = dur
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

#optional/default inputs
@displayname = @options[:displayname] || `hostname -f`.strip
@hostname = @options[:hostname] || `hostname -f`.strip
@collector = @options[:collector]
@starttime = to_time(@options[:starttime] || Time.now)
@endtime = end_time(@starttime, @options[:duration])

run(@hostname, @displayname, @collector, @starttime, @endtime)