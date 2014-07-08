# bulk_add_hosts.rb
#
# This is a ruby script to handle dynamic host group creation
#
# Requires:
# Ruby
# Ruby gems
# csv
# json
# open-url
# net/http(s)
# rbconfig
# optparse
# pp
# date
#
# Authorized Sources:
# LogicMonitor: https://github.com/logicmonitor
#
# Authors: Sam Dacanay, Ethan Culler-Mayeno, Perry Yang
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

  


  string = rpc("getHostGroups")
  hgs = JSON.parse(string)
  my_arr = hgs['data']

  id_arr = Array.new
  my_arr.each do |value|
    idval = value['id']
    id_arr.push(idval)
  end

  #puts id_arr

  file = @file
  #this part is actually awesome. CSV doesn't allow quoting that doesn't encapsulate an entire column/row thingy.
  #in order to allow quoting in an appliesTo (which is pretty common), we make the quote_character of the csv object
  #a character that doesn't appear in our csv (hopefully)
  csv = CSV.open(file, quote_char: "\x00", :headers => true)

  #csv = CSV.new(filecontent, {:headers => true})

  csv.each do |row|
    #Skip row in loop if the line is commented out (A.K.A. starts with a '#' character)
    next if row[0].start_with?('#')

    # validates presence of the hostname and collector id
    # next update: validate all rows before updating the account
    # give feedback on what lines/fields of the CSV will be problems
    if row["dgroupname"].nil? or row["appliesTo"].nil?
      puts "Error: All hosts MUST have a valid hostname and collector ID"
      exit(1)
    end

    #set instance variables to the value of the row
    @dgroupname = row["dgroupname"]
    @appliesTo = row["appliesTo"]
    @parentid = row["parentid"]
    @description = row["description"] 
    @properties = row["properties"] 

    puts
    puts "Adding Dynamic Group #{@dgroupname} to LogicMonitor"
    puts "RPC Response:"
    puts

    #parentId should default to one (root group) if nothing is passed in for that value
    if @parentid.nil?
      @parentid = 1
    end

    #check if parentId exists in current host groups or is root group
    #this is to validate that an accurate parentId was passed into the csv
    if id_arr.include?(@parentid.to_i) || @parentid == 1
      #check if description is nil before adding
      if @description.nil?
        puts rpc("addHostGroup", {"alertEnable" => false, "dGroup" => true, "name" => @dgroupname, "appliesTo" => @appliesTo, "parentId" => @parentid})
      else
        puts rpc("addHostGroup", {"alertEnable" => false, "dGroup" => true, "name" => @dgroupname, "appliesTo" => @appliesTo, "description" => @description, "parentId" => @parentid})
      end
    else
      puts "Error: parentId does not exist for #{@dgroupname}"
    end
  end
  puts
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
  url << get_properties(@properties).to_s

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

def get_properties(properties)
  propindex=""
  if not @properties.nil?
    props = @properties.split(":")
    index = 0
    props.each do |p|
      eachProp = p.split("=")
      key = eachProp[0]
      value = eachProp[1]
      propindex << "propName#{index}=#{key}&propValue#{index}=#{value}&"
      index = index + 1
    end
    @propindex=propindex.chomp("&")
  end
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