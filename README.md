# bbbmon
a simple BigBlueButton monitor and logging script using the bbb api.

### This works only on your BBB-Server!

![alt text](https://github.com/chillje/bbbmon/blob/master/figures/bbbmon_watch-mode.png?raw=true "bbbmon watch-mode")


## Installation

###### dependencys:
```
apt install sha1sum curl xmlstarlet mpstat ifstat
```
###### recommendet:
```
apt install watch
```

###### install & usage:
```
cd $HOME/opt/
git clone <url to this git>
cd bbbmon
chmod +x bbbmon.sh
bbbmon.sh
```

###### Help
```
bbbmon.sh -h
ATTENTION: You have to use this on your BBB server.

usage bbbmon.sh: [OPTION...]
OPTIONs:
 -f|--file         path to the outputfile (default is stdout).
 -i|--iface        interface stats to be shown (depends on \"-s\").
 -l|--log          start logging of meeting informations in simple log-format.
 -m|--members      show also the members of a meeting.
 -s|--stats        show the performance monitor (depends on \"-w\") .
 -w|--watch        start watch mode (best use with external tool \"watch\", see examples.)
 -h|--help         print this help, then exit.

examples:
 * watch --color -n3 "bbbmon.sh -w -s -i eth0"
 * watch --color -n3 "bbbmon.sh -w -m"
 * bbb-mon.sh -l -f bbb-meetings.log
```


## Watch-Mode

###### examples for watch mode:
```
watch -n3 --color bbbmon.sh -w -i eth1
watch -n3 --color bbbmon.sh -w -m
```

## Log-Mode

You can use several logging options. 
A general log is used with "-l -f filename.log".
You will get a "filename.log" and a simple "total-log" called "filename.log.total" in the same
path.
The total-log is a simple summarize of "meetingsTotal, participantsTotal, videoTotal" and if neede
(by using options -s and/or -i) "meetingsTotal, participantsTotal, videoTotal, cpuIdle, iface-In, iface-Out" to determine the usage of the BBB-server.

###### examples for log mode:

```
bbbmon.sh -m -l -s -i ens32 -f bbb-meetings.log
bbbmon.sh -l -s -i ens32 -f bbb-meetings.log
bbbmon.sh -l -f bbb-meetings.log
```


If you want to use it as a normal log system you can do something like:

```
crontab -e
```
and set

```
* * * * *               bbbmon.sh -m -l -s -i ens32 -f /var/log/bbb/bbb-meetings.log >>/var/log/bbb/bbb-meetings.err 1>&1
* * * * * ( sleep  30 ; bbbmon.sh -m -l -s -i ens32 -f /var/log/bbb/bbb-meetings.log >>/var/log/bbb/bbb-meetings.err 2>&1 )
```

Now you have a log entry every 30 seconds.

..and if you want to log-rotate this:

```vim /etc/logrotate.d/bbbmon```

```
/var/log/bbb/bbb-meetings.*
{
    rotate 30
    daily
    missingok
    notifempty
    delaycompress
    compress
    postrotate
    endscript
}

```

