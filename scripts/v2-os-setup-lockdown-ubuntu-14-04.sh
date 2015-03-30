#!/bin/bash
####################################
####################################
#Vars YOU MUST CONFIGURE!!!  Edit this section
NEWRELIC_LICENSEKEY=905129e714d35fcf6487c2c4e8e746f8277bf621
SERVICEACCOUNT_NAME=devops-service
SERVICEACCOUNT_GROUPNAME=service-runner
SERVICEACCOUNT_PUBLICKEYFILE=devops-service@v2-20150312.pub
SERVICEACCOUNT_PUBLICKEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAveoUpjZpsb64fmvBn8Osg6jWmbDr2Rz6Mz9hQtK5C4IA/ng2eMxzNyMr9wOj6ltDNnA3Ic8KLIK451lNlvyGCX3sT/bC8FUjyTk2fg87ZxZ+J2hGgC39Pvtiy0zDBg+wkeXVFyfLyuBzUzGW0h08eYh/kumdrAt5MaDNqK+EkQBJ46W7i6XBhf36+LosRRpGvO+EyLCjUdGt1+PQ7Hp2I2SYLUowFxT1x/yUDD5Kvb2VLIMyMHvzq7o5QQvkReywTG65u8xxewb+q/m/aRYLeFyl1JpiN9SEJRL/XSNtNzRSz5hKSaI7fZHBrbBzfOSOufqtSEg1LOt2A9Ay46k28++Cor1tQDB2sqrp+aPjuHu6dO4xgNdbBuQ8nnuvOrGuuEkRG65Ci4Uksap3g/cglOntdG7yAw31Ouf0vfhEGvax/b4oE6WriewATqUOQlMTRyenmT0lILCK+b3dSCQGELvhm3f25NX/Gt2XXxkBKEDT42y7Bj2rtIfp7X1eA+H9t8g0IFi8biFqvsSJDPo/Vegw1leTL3On0SsNeumhJs47ApfRjp4zj49A/GsNZXQZ4YB8OcqsJNtkrgt0eawZxDeN/8JchMLr35tombBxpNCdcNTvlOaPH+hOh9utWDl+tOOIYyRw14hiXPs3LUrR1jdT/UkcO+la64ZFnhuBePc= devops-service@v2 4096bit rsa-key-20150312"
TIMEZONE="America/Los_Angeles"
####################################
####################################

#write out our public key for ssh access later
cat > $SERVICEACCOUNT_PUBLICKEYFILE <<EOF
$SERVICEACCOUNT_PUBLICKEY
EOF

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

apt-get update

#enable multiverse packages, from:
sed -i "/^# deb.*multiverse/ s/^# //" /etc/apt/sources.list
apt-get update

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
apt-get install unattended-upgrades

cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

#mosh, better terminal.   from: https://mosh.mit.edu/#getting
apt-get install mosh  -y -qq --force-yes


#firewall, kinda from here: https://www.digitalocean.com/community/tutorials/additional-recommended-steps-for-new-ubuntu-14-04-servers
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow mosh
yes | ufw logging off
yes | ufw enable
assertExitOk

#timezone/ntp sync
echo $TIMEZONE > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
#ntp
apt-get install ntp -y -qq --force-yes

#swap files, simple instructions from https://www.digitalocean.com/community/tutorials/additional-recommended-steps-for-new-ubuntu-14-04-servers
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

#fail2ban https://www.digitalocean.com/community/tutorials/how-to-install-and-use-fail2ban-on-ubuntu-14-04
apt-get install fail2ban -y -qq --force-yes

#newrelic server logging, from: https://rpm.newrelic.com/accounts/926338/servers/get_started
echo deb http://apt.newrelic.com/debian/ newrelic non-free >> /etc/apt/sources.list.d/newrelic.list
wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
apt-get update
apt-get install newrelic-sysmond -y -qq --force-yes
nrsysmond-config --set license_key=$NEWRELIC_LICENSEKEY
/etc/init.d/newrelic-sysmond start

#utils
apt-get install rar -y -qq --force-yes
apt-get install unrar -y -qq --force-yes
sudo -E apt-get install nethogs -y -qq --force-yes > /dev/null  #http://stackoverflow.com/questions/1941242/the-not-so-useless-yes-bash-command-how-to-confirm-a-command-in-every-loop

#log execution of this script
cat >> $homedir/devops.log <<EOF
#############################################  DEVOPS LOG FILE FOR $HOSTNAME ($IPADDRESS)  #######################
$FILENAME success `eval date +%Y%m%d":"%H:%M`  ($HOSTNAME/$IPADDRESS)
EOF