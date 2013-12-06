# lm_ruby
LogicMonitor is a Cloud-based, full stack, IT infrastructure monitoring solution that allows you to manage your infrastructure monitoring from the Cloud. *Lm_ruby* contains a set of stand-alone scripts which can be used to manage your LogicMonitor account programmatically. These scripts are intended to be functional examples of interaction with the LogicMonitor API in ruby.

##Overview
This repository is not a complete set of scripts required to fully manage your LogicMonitor account, nor does it cover the full extend of the LogicMonitor API. Here's what we have so far.

####Platform specific tools
The following scripts are for managing specific types of devices.
**Linux collector management:**
- add_collector
- remove_collector

####Platform agnostic tools
**Host management:**
- add_host
- remove_host
- sdt_host
- mass_upload_hosts

**Alert management:**
- get_count_alerts

