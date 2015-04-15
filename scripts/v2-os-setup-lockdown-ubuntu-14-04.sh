#!/bin/bash



####################################
####################################
#Vars YOU MUST CONFIGURE!!!  Edit this section

#NEWRELIC_LICENSEKEY=alkadjf #SET THIS IN THE ROOT SCRIPT, or do it here!!
SERVICEACCOUNT_NAME=devops-service
SERVICEACCOUNT_GROUPNAME=service-runner
SERVICEACCOUNT_PUBLICKEYFILE=jason.robert.swearingen@master-20150302.pub
SERVICEACCOUNT_PUBLICKEYURL="https://github.com/jasonswearingen/devops/raw/master/public-keys/$SERVICEACCOUNT_PUBLICKEYFILE"
TIMEZONE="America/Los_Angeles"
####################################
####################################


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

#get host name/ip (printenv to see env vars)
HOSTNAME=$(hostname)
IPADDRESS=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')


#log execution of this script
cat >> $homedir/devops.log <<EOF
$FILENAME start `eval date +%Y%m%d":"%H:%M`  ($HOSTNAME/$IPADDRESS)
EOF
###################################


###### 
## disable bash history (security mitigation for if our VM host provider gets hacked)
echo \# disable bash history >> $homedir/.bashrc
echo HISTFILE=\/dev\/null  >> $homedir/.bashrc

########################################
###### setup truely non-interactive
export DEBIAN_FRONTEND=noninteractive #from http://snowulf.com/2008/12/04/truly-non-interactive-unattended-apt-get-install/ and https://bugs.launchpad.net/ubuntu/+source/eglibc/+bug/935681
# note: to use this, need "sudo -E" to copy env variables, otherwise will still get interactive prompts


# --------------------------------------------------------------------------------------------
#function helper to check exit code of commands
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

###### log entirty to log file
set +x
{

aptgethelper update

#enable multiverse packages, from:
sed -i "/^# deb.*multiverse/ s/^# //" /etc/apt/sources.list
aptgethelper update


#download our keyfile for service account use later
curl -L --retry 20 --retry-delay 2 -o $SERVICEACCOUNT_PUBLICKEYFILE $SERVICEACCOUNT_PUBLICKEYURL

#roughly following guide from https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-14-04

#add service group/user
addgroup $SERVICEACCOUNT_GROUPNAME
assertExitOk
useradd $SERVICEACCOUNT_NAME --create-home --shell /bin/bash --groups $SERVICEACCOUNT_GROUPNAME
assertExitOk
#gpasswd -a $SERVICEACCOUNT_NAME sudo
mkdir /home/$SERVICEACCOUNT_NAME/.ssh
chmod 700 /home/$SERVICEACCOUNT_NAME/.ssh
assertExitOk
cat $SERVICEACCOUNT_PUBLICKEYFILE >> /home/$SERVICEACCOUNT_NAME/.ssh/authorized_keys
assertExitOk
chown $SERVICEACCOUNT_NAME:$SERVICEACCOUNT_NAME /home/$SERVICEACCOUNT_NAME -R
assertExitOk

#allow sudo without passwords.   does not work like this, must be done via the 'visudo' command!!!!!  
## don't know how to automate, and security concern with service account.
#cat >>  /etc/sudoers << EOF
## grant no-password access, from : https://superuser.com/questions/492405/sudo-without-password-when-logged-in-with-ssh-private-keys
#user ALL=(ALL)       NOPASSWD: ALL
#EOF

# only allow key based logins
sed -n 'H;${x;s/\#PasswordAuthentication yes/PasswordAuthentication no/;p;}' /etc/ssh/sshd_config > tmp_sshd_config
assertExitOk
cat tmp_sshd_config > /etc/ssh/sshd_config
assertExitOk
rm tmp_sshd_config 
assertExitOk


# disable root login
#sed -n 'H;${x;s/\PermitRootLogin yes/PermitRootLogin no/;p;}' /etc/ssh/sshd_config > tmp_sshd_config
#assertExitOk
#cat tmp_sshd_config > /etc/ssh/sshd_config
#assertExitOk
#rm tmp_sshd_config 
#assertExitOk

# -u devops-serviceSudo 
# ### add cron minimum settings for our devopsService user, if it doesn't already exist (don't want to overwrite existing crons)
sudo -u $SERVICEACCOUNT_NAME bash <<EOF
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/sbin
cd /home/$SERVICEACCOUNT_NAME
if ! [ "$(crontab -l)" ]; then 
	echo '# setup min env, as per: http://askubuntu.com/questions/264607/bash-script-not-executing-from-crontab, including /sbin for ifconfig access' > tmpCron
	echo "SHELL=/bin/sh" >> tmpCron
	echo "PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/sbin" >> tmpCron
	crontab tmpCron
	rm tmpCron
fi
EOF

########## also set cron min for root, if it doesn't already exist (don't want to overwrite existing crons)
if ! [ "$(crontab -l)" ]; then 
	echo '# setup min env, as per: http://askubuntu.com/questions/264607/bash-script-not-executing-from-crontab, including /sbin for ifconfig access' > tmpCron
	echo "SHELL=/bin/sh" >> tmpCron
	echo "PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/sbin" >> tmpCron
	crontab tmpCron
	rm tmpCron
fi

#auto update packages, from https://help.ubuntu.com/lts/serverguide/automatic-updates.html
aptgethelper install "unattended-upgrades -y -qq --force-yes"

cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

#mosh, better terminal.   from: https://mosh.mit.edu/#getting
aptgethelper install "mosh  -y -qq --force-yes"


#firewall, kinda from here: https://www.digitalocean.com/community/tutorials/additional-recommended-steps-for-new-ubuntu-14-04-servers
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow mosh
yes | ufw logging off
yes | ufw enable
assertExitOk

#timezone/ntp sync
#echo $TIMEZONE > /etc/timezone
#dpkg-reconfigure -f noninteractive tzdata
#ntp
aptgethelper install "ntp -y -qq --force-yes"

#swap files, simple instructions from https://www.digitalocean.com/community/tutorials/additional-recommended-steps-for-new-ubuntu-14-04-servers
fallocate -l 5G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

#fail2ban https://www.digitalocean.com/community/tutorials/how-to-install-and-use-fail2ban-on-ubuntu-14-04
aptgethelper install "fail2ban -y -qq --force-yes"

#newrelic server logging, from: https://rpm.newrelic.com/accounts/926338/servers/get_started
echo deb http://apt.newrelic.com/debian/ newrelic non-free >> /etc/apt/sources.list.d/newrelic.list
wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
aptgethelper update
aptgethelper install "newrelic-sysmond -y -qq --force-yes"
nrsysmond-config --set license_key=$NEWRELIC_LICENSEKEY
/etc/init.d/newrelic-sysmond start

#utils
aptgethelper install "rar unrar nethogs -y -qq --force-yes"  #http://stackoverflow.com/questions/1941242/the-not-so-useless-yes-bash-command-how-to-confirm-a-command-in-every-loop

echo ---------------------------------------------
echo SCRIPT COMPLETE.
} > $homedir/$FILENAME.$now.log 

#log execution of this script
cat >> $homedir/devops.log <<EOF
$FILENAME finish `eval date +%Y%m%d":"%H:%M`  ($HOSTNAME/$IPADDRESS)
EOF