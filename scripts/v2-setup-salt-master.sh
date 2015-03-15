#!/bin/bash

#vars to parameterize
SALTMASTER=salt.do.phantomjscloud.com

######### pre-prep environment vars #########
### get our homedir, as it seems the ~ var gets destroyed later...
homedir=~
MY_PATH="`dirname \"$0\"`"
FILENAME="`basename \"$0\"`"
pushd $MY_PATH
MY_PATH=$(pwd)
MY_FOLDER=${PWD##*/} # folder name, without full path

nowDate=`eval date +%Y%m%d`
nowTime=`eval date +%H%M`
#now=`eval date +%Y%m%d":"%H%M` #not using this incase minute changes between this and previous line
now=$nowDate:$nowTime

###### 
## disable bash history (security mitigation for if our VM host provider gets hacked)
echo \# disable bash history >> $homedir/.bashrc
echo HISTFILE=\/dev\/null  >> $homedir/.bashrc

#get host name/ip (printenv to see env vars)
HOSTNAME=$(hostname)
IPADDRESS=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

########################################
###### setup truely non-interactive
export DEBIAN_FRONTEND=noninteractive #from http://snowulf.com/2008/12/04/truly-non-interactive-unattended-apt-get-install/ and https://bugs.launchpad.net/ubuntu/+source/eglibc/+bug/935681
# note: to use this, need "sudo -E" to copy env variables, otherwise will still get interactive prompts


# --------------------------------------------------------------------------------------------

function assertExitOk(){
set +x
local __errorCode=$?
echo "errorcode= $__errorCode"
local __alsoOk=$1
__alsoOk=${__alsoOk:-0}

if [ $__errorCode -ne 0 ]; then
	if [ "$__errorCode" != "$__alsoOk" ]; then
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo " !!!!!!!   INVALID EXIT CODE '$__errorCode' ENCOUNTERED IN LAST STATEMENT!  ABORTING!  !!!!!!!!!!!!!!!!!!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		exit $__errorCode
	fi
fi
if [ "$SILENT" != "true" ]; then
set -x
fi
}


# --------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------

#initial salt install, following: https://www.digitalocean.com/community/tutorials/how-to-install-salt-on-ubuntu-12-04

#SALT MASTER
sudo apt-get install python-software-properties -y -qq --force-yes
assertExitOk
sudo add-apt-repository ppa:saltstack/salt -y
assertExitOk
sudo apt-get update
assertExitOk
sudo apt-get install salt-master -y -qq --force-yes
assertExitOk
#enable required master ports, from: http://docs.saltstack.com/en/latest/topics/tutorials/firewall.html
ufw allow salt
assertExitOk

#accept our minon
#salt-key -a "$(hostname)" -y
#check status
#salt "*" test.ping
#salt "$(hostname)" network.ip_addrs



# --------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------
#log

cat >> $homedir/devops.log <<EOF
#############################################  DEVOPS LOG FILE FOR $HOSTNAME ($IPADDRESS)  #######################
$FILENAME success `eval date +%Y%m%d":"%H:%M`  ($HOSTNAME/$IPADDRESS)
EOF