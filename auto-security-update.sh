#/bin/bash

# script to look for security updates, apply them automatically, and then check if reboot is needed
# is meant to run as cronjob
# CentOS specific!

# prerequisites

# make sure log file is present
touch /var/log/yum-auto-updates.log

# vars
DATE=$(date +%F\ %T)
LOG="/var/log/yum-auto-updates.log"
CHECK=$(which needs-restarting)
SHUTDOWN=$(which shutdown)
SYSTEMCTL=$(which systemctl)
SLEEP=$(which sleep)
REBOOT=$(which reboot)
REBOOT_VAR="255"

echo -e "\n$DATE" >> $LOG

# install "needs-restarting" binary, if becessary (from yum-utils)
[[ -z $(yum list installed | grep "yum-utils") ]] && yum install yum-utils && echo -e "yum-utils need to be installed..\tdone" >> $LOG

#####

# update package list (check for updates of ALREADY INSTALLED packages)
# yum check-update
# Probably unnecessary, because "yum upgrade" does this anyway.

# alt:
yum makecache && echo -e "cache has been updated" >> $LOG
# see: https://unix.stackexchange.com/questions/6252/what-is-yum-equivalent-of-apt-get-update

#####

# SECURITY upgrades only
# see: https://access.redhat.com/solutions/10021

# install packages that have a security errata issue:
yum update-minimal --security -y
echo -e "Security updates have been checked @ $(date +%T).\nPlease find more infos in local yum.log\n" >> $LOG

#####

# check for services that need reboot:
# needs-restarting -s

for service in $($CHECK -s); do
        $SYSTEMCTL restart $service && echo -e "$service\tneeded restart. Done." >> $LOG
done

#####

# check if general reboot is needed:
# needs-restarting -r

# exit 0 = NO reboot required
# exit 1 = reboot required

$CHECK -r
REBOOT_VAR=$?

# testing the reboot var - manually set to "1", so that reboot should occur
# REBOOT_VAR="1"

case $REBOOT_VAR in
        0)
        echo -e "$(date +%T)\tNo general reboot required. Resuming normal operation." >> $LOG
        ;;

        1)
        echo -e "$(date +%T)\tGeneral reboot required, doing so in 1 min.." >> $LOG
        wall "Server reboot in 1 minute! SAVE YOUR WORK!!"
        # $SHUTDOWN -r          # NOT working
        /usr/sbin/shutdown -r   # this works :)
        # $REBOOT               # NOT working
        $SLEEP 90               # to ensure reboot takes place!
        ;;

        *)
        echo -e "$(date +%T)\tSomething went wrong with the reboot necessity check - please evaluate." >> $LOG
        ;;
esac
