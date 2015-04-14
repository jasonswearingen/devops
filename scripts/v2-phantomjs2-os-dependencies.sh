#!/bin/bash

### WHAT IS THIS?
#### dependencies needed for phantomjs v2 (debian/ubuntu) to execute the linux binary.
#### these dependencies are the same as needed to build the linux binary, as found here: http://phantomjs.org/build.html



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


#log execution of this script
cat >> $homedir/devops.log <<EOF
$FILENAME start `eval date +%Y%m%d":"%H:%M`  ($HOSTNAME/$IPADDRESS)
EOF
###################################

############ wrapper over apt-get to download files (retries if download fails) and then perform action.  usage example:  aptgethelper install "nethogs rar -y -qq --force-yes"
function aptgethelper(){
local __cmd=$1
local __args=$2
local retry=10 count=0
set +x
    # retry at most $retry times, waiting 1 minute between each try
    while true; do

        # Tell apt-get to only download packages for upgrade, and send 
        # signal 15 (SIGTERM) if it takes more than 10 minutes
        if timeout --kill-after=60 60 apt-get -d $__cmd --assume-yes $__args; then
            break
        fi
        if (( count++ == retry )); then
            printf "apt-get download failed for $__cmd ,  $__args\n" >&2
            return 1
        fi
        sleep 60
    done

    # At this point there should be no more packages to download, so 
    # install them.
    apt-get $__cmd --assume-yes $__args
}

########################################
###### setup truely non-interactive
export DEBIAN_FRONTEND=noninteractive #from http://snowulf.com/2008/12/04/truly-non-interactive-unattended-apt-get-install/ and https://bugs.launchpad.net/ubuntu/+source/eglibc/+bug/935681
# note: to use this, need "sudo -E" to copy env variables, otherwise will still get interactive prompts

aptgethelper update


#dependencies of phantomjs v2 linux.
aptgethelper install "build-essential g++ flex bison gperf ruby perl libsqlite3-dev libfontconfig1-dev libicu-dev libfreetype6 libssl-dev libpng-dev libjpeg-dev   -y -qq --force-yes"

## install extra fonts
aptgethelper install "fontconfig libfreetype6 cabextract ttf-mscorefonts-installer unifont fonts-thai-tlwg -y -qq --force-yes"

#log execution of this script
cat >> $homedir/devops.log <<EOF
$FILENAME finish `eval date +%Y%m%d":"%H:%M`  ($HOSTNAME/$IPADDRESS)
EOF
