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


########################################
###### setup truely non-interactive
export DEBIAN_FRONTEND=noninteractive #from http://snowulf.com/2008/12/04/truly-non-interactive-unattended-apt-get-install/ and https://bugs.launchpad.net/ubuntu/+source/eglibc/+bug/935681
# note: to use this, need "sudo -E" to copy env variables, otherwise will still get interactive prompts

apt-get update



apt-get install build-essential g++ flex bison gperf ruby perl \
  libsqlite3-dev libfontconfig1-dev libicu-dev libfreetype6 libssl-dev \
  libpng-dev libjpeg-dev   -y -qq --force-yes

apt-get install ttf-mscorefonts-installer -y -qq --force-yes
  