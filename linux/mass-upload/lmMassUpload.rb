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

@company  = ARGV[1]
@username = ARGV[2]
@password = ARGV[3]

def main
  id    = []
  names = []
  file  = ARGV[0]

  date = `date +"%Y%m%d%H%M%S"`
  (groupname = "lmsupport-import-"+"#{date}").chomp!
  rpc("addHostGroup", {"alertEnable" => false, "name" => groupname})
 
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
          puts "\n Host: " + row[1] 
          puts rpc("addhost", {"hostName" =>row[1], "displayedAs" =>row[2]}, "agentId" => row[0], "hostGroupIds" => "#{groupid},#{lmgroupid}"})
        else
          puts "\n Host: " + row[1]
          puts rpc("addhost", {"hostName" =>row[1], "displayedAs" =>row[1]}, "agentId" => row[0], "hostGroupIds" => "#{groupid},#{lmgroupid}"})
        end
      end
    else
      if(row[2]!=nil) #if displayname is nil and there is no fullpath, just place it the lmsupport-import host group
        puts "\n Host: " + row[1]
        puts rpc("addhost", {"hostName" =>row[1], "displayedAs" =>row[2]}, "agentId" => row[0], "hostGroupIds" => "#{lmgroupid}"})
      else
        puts "\n Host: " + row[1]
        puts rpc("addhost", {"hostName" =>row[1], "displayedAs" =>row[1]}, "agentId" => row[0], "hostGroupIds" => "#{lmgroupid}"})
      end
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

main()
