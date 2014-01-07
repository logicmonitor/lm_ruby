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


def main
  id    = []
  names = []
  file  = @file
  hostpaths = []
  $a = 0
  rstring = ""
  date = `date +"%Y%m%d%H%M%S"`
  (groupname = "lmsupport-import-"+"#{date}").chomp!
  rpc("addHostGroup", {"alertEnable" => false, "name" => groupname})

  string = rpc("getHostGroups") #makes API call to grab host group
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
    if (row[3]!=nil)
	if (row[3].include?(":"))
         row[3]=row[3].gsub(" ","_")
         row[3]=row[3].gsub(":"," ")
         hostpaths = row[3].split
           while $a < hostpaths.length
            hgroups = group[hostpaths[$a].gsub("_"," ")]
            output = hgroups.to_s + ","
            rstring << output
            $a+=1
            end
         rstring=rstring.chomp(",")
        if (row[2]!=nil) #if the displayname is not nil
        puts "\n Host: " + row[1] 
        puts rpc("addHost", {"hostName" =>row[1], "displayedAs" =>row[2], "agentId" => row[0], "hostGroupIds" => "#{rstring},#{lmgroupid}"})
        else
        puts "\n Host: " + row[1]
        puts rpc("addHost", {"hostName" =>row[1], "displayedAs" =>row[1], "agentId" => row[0], "hostGroupIds" => "#{rstring},#{lmgroupid}"})
        end      
      else
       groupid=group[row[3]]
      if (row[2]!=nil) #if the displayname is not nil
        puts "\n Host: " + row[1]
        puts rpc("addHost", {"hostName" =>row[1], "displayedAs" =>row[2], "agentId" => row[0], "hostGroupIds" => "#{groupid},#{lmgroupid}"})
        else
          puts "\n Host: " + row[1]
          puts rpc("addHost", {"hostName" =>row[1], "displayedAs" =>row[1], "agentId" => row[0], "hostGroupIds" => "#{groupid},#{lmgroupid}"})
        end
        end
   else
   if(row[2]!=nil) #if displayname is nil and there is no fullpath, just place it the lmsupport-import host group
        puts "\n Host: " + row[1]
        puts rpc("addHost", {"hostName" =>row[1], "displayedAs" =>row[2], "agentId" => row[0], "hostGroupIds" => "#{lmgroupid}"})
      else
        puts "\n Host: " + row[1]
        puts rpc("addHost", {"hostName" =>row[1], "displayedAs" =>row[1], "agentId" => row[0], "hostGroupIds" => "#{lmgroupid}"})
      end
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
#  puts(url)
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

###################################################################
#                                                                 #
#       Begin running part of the script                          #
#                                                                 #
###################################################################

pt_error = false
begin
  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby bulk_add_hosts.rb -c <company> -u <user> -p <password> -f <file>"

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
