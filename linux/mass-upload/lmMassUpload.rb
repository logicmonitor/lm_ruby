# lmMassUpload.rb
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
# Authors: Perry Yang
#

require 'csv'
require 'net/http'
require 'net/https'
require 'rbconfig'
require 'rubygems'
require 'json'


if (ARGV[0]==nil||ARGV[1]==nil||ARGV[2]==nil||ARGV[3]==nil)
  puts "\n\nUsage example: 'ruby massupload.rb csvfullPath companyname username password'\n\n\n"
end

def main
  id    = []
  names = []
  file  = ARGV[0]

  date = `date +"%Y%m%d%H%M%S"`
  (groupname = "lmsupport-import-"+"#{date}").chomp!
  apiGet("/rpc/addHostGroup?alertEnable=false&name=#{groupname}")
 
  string = apiGet("/rpc/getHostGroups?") #makes API call to grab host group
  hostgroups= JSON.parse(string)
  my_arr=hostgroups['data']

  group = Hash.new
  my_arr.each do |value|
    group[value["fullPath"]] = value["id"]
  end

  lmgroupid = group[groupname]

  CSV.foreach(file) do |row|
    next if row[0] =~ /^#/
    if (row[1]!=nil) #should not be nil anyway for any host to be added, for better logging outputs
      if (defined?(group[row[3]].nil?))
        groupid=group[row[3]]
        if (row[2]!=nil) #if the displayname is not nil
          action = "/rpc/addHost?hostName=#{row[1]}&displayedAs=#{row[2]}&agentId=#{row[0]}&hostGroupIds=#{groupid},#{lmgroupid}" 
          puts "\n Host: " + row[1] 
          puts apiGet(action)
        else
          action = "/rpc/addHost?hostName=#{row[1]}&displayedAs=#{row[1]}&agentId=#{row[0]}&hostGroupIds=#{groupid},#{lmgroupid}"
          puts "\n Host: " + row[1]
          puts apiGet(action)
        end
      end
    else
      if(row[2]!=nil) #if displayname is nil and there is no fullpath, just place it in root (and the lmsupport-import host group)
        action = "/rpc/addHost?hostName=#{row[1]}&displayedAs=#{row[2]}&agentId=#{row[0]}&hostGroupIds=#{lmgroupid}"
        puts "\n Host: " + row[1]
        puts apiGet(action)
      else
        action = "/rpc/addHost?hostName=#{row[1]}&displayedAs=#{row[1]}&agentId=#{row[0]}&hostGroupIds=#{lmgroupid}"
        puts "\n Host: " + row[1]
        puts apiGet(action)
      end
    end
  end
end

def apiGet(action)
  company  = ARGV[1]
  username = ARGV[2]
  password = ARGV[3]

  url = "https://#{company}.logicmonitor.com/santaba#{action}&c=#{company}&u=#{username}&p=#{password}"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, 443)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(req)
  return response.body
end

main()
