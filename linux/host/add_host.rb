# add_host.rb
#
# This is a ruby script to handle the addition of devices into LogicMonitor WebApp
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
# Authors: Perry Yang, Ethan Culler-Mayeno
#


require 'json'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'optparse'   #not needed for RightScript  
