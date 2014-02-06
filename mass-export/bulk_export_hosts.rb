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
  descriptions = []
  collectorID = []
  hostpaths = []
  hostnames = []
  properties = []
  @a = 0
  @b = 0  
  @c = 0
CSV.open("#{@file}", "w") do |csv|
  csv << ["collector_id","hostname","display_name","group_list","description","properties"]
  string = rpc("getHostGroups") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  my_arr=hostgroups['data']
  my_arr.each do |value|
  id = id.push("1")#to get the ids from root
  id = id.push(value["id"])
 end
 while @a < id.size 
  hostids = rpc("getHosts",{"hostGroupId"=>id[@a]})
  hosts = JSON.parse(hostids)
  h_ids = hosts["data"]["hosts"]
  h_ids.each do |values|
  names = names.push(values["displayedAs"])
  end
  @a=@a+1
  end
  names = names.uniq #gets all the display names of the hosts in the account

while @b < names.size
hostsInfo = rpc("getHost",{"displayName"=>names[@b]})
host_info = JSON.parse(hostsInfo)
collectorID = collectorID.push(host_info["data"]["agentId"])
descriptions = descriptions.push(host_info["data"]["description"])
hostpaths=hostpaths.push(host_info["data"]["properties"]["system.groups"].gsub(",",":"))
hostnames=hostnames.push(host_info["data"]["hostName"])

host_info["data"]["properties"].each do |f|
if not (f[0].include?("system"))
properties[@b]=properties.push("#{f[0]}=#{f[1]}")  
properties.compact
end
end
@b+=1
end


while @c < names.size
csv << [collectorID[@c],hostnames[@c],names[@c],hostpaths[@c],descriptions[@c],properties[@c]]
@c=@c+1
end
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


pt_error = false
begin
  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby bulk_add_hosts.rb -c <company> -u <user> -p <password> -f <new filename>"

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
