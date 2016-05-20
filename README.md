# lm_ruby
LogicMonitor is a cloud-based, full stack, IT infrastructure monitoring solution that allows you to manage your infrastructure from the cloud. *Lm_ruby* contains a set of stand-alone scripts which can be used to manage your LogicMonitor account programmatically. These scripts are intended to be functional examples of interaction with the LogicMonitor API in ruby.

##Prerequisites
In order to use these scripts there are a few things you will need.
- Access to a LogicMonitor account
- Sufficient permissions to perform the desired action
- A ruby run time environment (Ruby version 1.9.3 or later)

##Overview
This repository is not a complete set of scripts required to fully manage your LogicMonitor account, nor does it cover the full extent of the LogicMonitor API. Here's what we have so far.

####Upcoming features
- For bulk addition of hosts, the ability to create host groups to an arbitrary depth as part of the addition.
-

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

### collector/linux/add_collector.rb
This idempotent script creates a new LogicMonitor collector for a Linux device. This script assumes that you are running the script on the machine that you are wanting to install a new collector. For more information about collector management [click here](http://help.logicmonitor.com/using/managing-collectors/).

```
$> ruby add_collector.rb -h
Usage: add_collector.rb -c <company> -u <user> -p <password> [-d]
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
```
###collector/linux/remove_collector.rb
This idempotent script removes and existing LogicMonitor collector from a Linux device. This script assumes that you are running the script on the machine that you want to remove a collector from. For more information about collector management [click here](http://help.logicmonitor.com/using/managing-collectors/).

```
$> ruby remove_collector.rb -h
Usage: add_collector.rb -c <company> -u <user> -p <password> [-d]
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
```

###alerts/get_count_alerts.rb
This script prints the number of currently active (not cleared) alerts broken down by severity. For more information about managing your alerts [click here](http://help.logicmonitor.com/using/i-got-an-alert-now-what/).

```
$> ruby get_count_alerts.rb -h
Usage: get_count_alerts.rb -c <company> -u <user> -p <password> -C <collectorName> [-d]
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
$> ruby get_count_alerts.rb -c chimpco -u username -p password
Alerts by severity:
critical = 2
error = 0
warn = 0
```

###host/add_host.rb
This idempotent script adds a new device to monitoring in your LogicMonitor account. This addition includes setting host properties and group membership. If the groups required for the addition of this host do not exist, they will be created. For more information on managing hosts [click here](http://help.logicmonitor.com/using/managing-hosts/).

```
$> ruby add_host.rb -h
Usage: add_host.rb -c <company> -u <user> -p <password> -C <collectorName> -H <hostname> [-n <displayname> -D <description> -g <grouplist> -P <properties> -a <alertenable> -d]
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
    -C, --collector COLLECTOR        Collector to monitor this host
    -H, --name HOSTNAME              Hostname of this device
    -n, --displayname DISPLAYNAME    How this host should appear in LogicMonitor account
    -D, --description DESCRIPTION    Long text host description
    -g "/GROUP1,/PARENT/GROUP2,...", The set of groups (fullpath) the host should belong to
        --groups
    -P {"property1":"value1","property2":"value2",...},
        --properties                 JSON hash of host properties
    -a, --alertenable                Turn on alerting for the host
```


###host/remove_host.rb
This idempotent script removes a device from monitoring in your LogicMonitor account. Note: this does not remove host groups that contain this host even if they were created by adding this host.

```
$> ruby remove_host.rb -h
Usage: remove_host.rb -c <company> -u <user> -p <password> -C <collectorName> -H <hostname> [-n <displayname> -d]
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
    -C, --collector COLLECTOR        Collector to monitor this host
    -H, --name HOSTNAME              Hostname of this device
    -n, --displayname DISPLAYNAME    The human readable name for the host in your LogicMonitor account
```

###host/sdt_host.rb
This script places a host in scheduled down time (SDT) or maintenance mode. This will suppress alerting for the duration of the SDT. This script is not idempotent and the same device can be put into SDT multiple times.

```
$> ruby sdt_host.rb -h
Usage: sdt_host.rb -c <company> -u <user> -p <password> -H <hostname> [-C <collectorName> -n <displayname> -D <duration> -s <starttime> -d]
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
    -H, --name HOSTNAME              IP Address or FQDN of the host
    -C, --collector COLLECTOR        The FQDN of the collector monitoring this device (required if -h is set)
    -n, --displayname DISPLAYNAME    The human readable name for the host in your LogicMonitor account
    -s, --starttime STARTTIME        Time in the format "2013-07-23t00:00" for the start time of the SDT
    -D, --duration DURATION          How long this device should be in scheduled downtime. Format: 4d 6h 25
```


###mass-upload/bulk_add_hosts.rb
This script parses a CSV formated list of hosts and adds them to monitoring.

```
$> ruby bulk_add_hosts.rb -h
Usage: ruby bulk_add_hosts.rb -c <company> -u <user> -p <password> -f <file>
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
    -f, --file FILE                  A CSV file contaning the hosts to be added.
```

We have provided a sample CSV file [example.csv](./host/bulk/example.csv) to show the required set and order of the columns. This script currently requires any host groups specified in the script to already exist in the account.
To make sure that bulk_add_hosts can read the CSV file, you need to specify either the full path to the CSV file OR the relative path from the current working directory.

###mass-export/bulk_export_hosts.rb
This scipt exports all of your hosts into a CSV file

```
$> ruby bulk_export_hosts.rb -h
Usage: ruby bulk_add_hosts.rb -c <company> -u <user> -p <password> -f <file>
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
    -f, --file FILE                  The CSV file that willl be created containing your host export information
```

Best practice would be to run the host export script if you were to do a bulk update on multiple hosts. This ensures that you have the properly formatted CSV file and will make the multi-host update much quicker and easier.

###mass-update/bulk_update_hosts.rb
This script parses a CSV formated list of hosts updates the exists host according to the information provided in the CSV.

```
$> ruby bulk_update_hosts.rb -h
Usage: ruby bulk_add_hosts.rb -c <company> -u <user> -p <password> -f <file>
    -d, --debug                      Turn on debug print statements
    -c, --company COMPANY            LogicMonitor Account
    -u, --user USERNAME              LogicMonitor user name
    -p, --password PASSWORD          LogicMonitor password
    -f, --file FILE                  A CSV file contaning the hosts to be updated.
```

This will not work with hosts that do not already exist. A working update will probably be to add the host if they could not find this host and apply the settings. However, if the script fails out, the first step would be check if all the hosts in the CSV all exist
