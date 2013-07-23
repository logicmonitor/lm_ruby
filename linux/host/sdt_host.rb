# sdt_host.rb
#
# This is a ruby script to handle putting devices monitored by LogicMonitor into scheduled down time (SDT) or maintenance windows.
#
# Requires:
# Ruby
# Ruby gems
#   json
#   active_support
#   tzinfo
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

require 'rubygems'
require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'time'
require 'date'
require 'active_support/time'
require 'optparse'   #not needed for RightScript  


def run(hostname, displayname, collector, starttime, endtime)
  host_exist = get_host_by_displayname(displayname) || get_host_by_hostname(hostname, collector)
#  p host_exist
  if host_exist
    puts "Creating SDT for #{host_exist["displayedAs"]}"
    puts rpc("setHostSDT", {"id" => 0, "type" => 1, "notifyCC" => true, "hostId" => host_exist["id"],
      "year" => starttime.year, "month" => (starttime.month.to_i) - 1, "day" => starttime.day, "hour" => starttime.hour, "minute" => starttime.min,
      "endYear" => endtime.year, "endMonth" => (endtime.month.to_i) - 1, "endDay" => endtime.day, "endHour" => endtime.hour, "endMinute" => endtime.min})
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
  offset = get_offset/3600
  zone = ActiveSupport::TimeZone[offset].name
  Time.zone = zone 
  if timevar.nil? or timevar.strip.empty?
     if Time.zone.now.isdst
       return Time.zone.now - (60 * 60)
     else
       return Time.zone.now
     end
  elsif timevar.class == String
     if timevar.match(/^\d{4}-\d{2}-\d{2}t\d{2}:\d{2}/)
       t = timevar.match(/^(\d{4})-(\d{2})-(\d{2})t(\d{2}):(\d{2})/).captures
       time = Time.new(t[0], t[1], t[2], t[3], t[4], 0, offset)
       if time.isdst
         return time - (60*60)
       else
         return time
       end
      else
       puts "Start time was in an unrecognized format."
       puts "Exiting"
       exit 3
     end
  else
    puts "An unrecognized input for a time value was entered."
    puts "Time value #{timevar} with class #{timevar.class} is not supported."
    puts "exiting"
    exit 3
  end
end

#returns the end time from starttime and duration
def end_time(starttime, duration)
  endtime = starttime
  if duration
    seconds = 0
    duration.split(" ").each do |dur|
      if dur.include?("d")
        seconds = seconds + (60 * 60 * 24 * dur.to_i) #add seconds in the number of days
      elsif dur.include?("h")
        seconds = seconds + (60 * 60 * dur.to_i) #add seconds in the count of hours
      else
        seconds = seconds + (60 * dur.to_i) #add seconds in the count of minutes
      end
    end    
    return endtime + seconds
  else
    return endtime + (60*60) #default of 1 hour
  end
end



#return a host object from displayname
def get_host_by_displayname(displayname)
  host = nil
  host_json = rpc("getHost", {"displayName" => URI::encode(displayname)})
  host_resp = JSON.parse(host_json)
#  p host_resp
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
#    p hosts_resp
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

def get_offset
  offset_resp = JSON.parse(rpc("getTimeZoneSetting", {}))
  if offset_resp["status"] == 200 and not offset_resp["data"].nil?
    return offset_resp["data"]["offset"]
  else
    puts "Unable to retrieve time zone information from server"
    p offset_resp
    puts "Using GMT"
    return 0
  end
  
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

    opts.on("-C", "--collector COLLECTOR", "The FQDN of the collector monitoring this device (required if -h is set)") do |col|
      @options[:displayname] = col
    end
    
    opts.on("-n", "--displayname DISPLAYNAME", "The human readable name for the host in your LogicMonitor account") do |n|
      @options[:displayname] = n
    end

    opts.on("-s", "--starttime STARTTIME", "Time in the format \"2013-07-23t00:00\" for the start time of the SDT") do |s|
      @options[:starttime] = s
    end

    opts.on("-D", "--duration DURATION", "How long this device should be in scheduled downtime. Format: 4d 6h 25") do |dur|
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
@starttime = to_time(@options[:starttime])
@endtime = end_time(@starttime, @options[:duration])

run(@hostname, @displayname, @collector, @starttime, @endtime)