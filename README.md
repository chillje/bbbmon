# bbbmon
a simple BigBlueButton monitor and logging script using the bbb api.

### This works only on your BBB-Server!

![alt text](https://github.com/chillje/bbbmon/blob/master/figures/bbbmon_watch-mode.png?raw=true "bbbmon watch-mode")




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

###### examples:
```
watch -n3 --color bbbmon.sh -w -i eth1
watch -n3 --color bbbmon.sh -w -m
bbbmon.sh -l -m -f /var/log/bbbmon.log
```
