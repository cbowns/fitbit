#!/bin/zsh -x
# Created by Christopher Bowns on 2011-09-25
# Copyright 2011 Mechanical Pants Software

# here's the deal:
# 1. set /Library/LaunchDaemons/com.fitbit.fitbitd:
#      StandardErrorPath = "/private/var/log/fitbit.stderr";
# 2. kick launchd so it sees the new entry
# 3. install newsyslog.conf entry.

githubissues="https://github.com/cbowns/fitbit/issues/new"

fitbitplistshort="/Library/LaunchDaemons/com.fitbit.fitbitd"
fitbitplist="$fitbitplistshort.plist"
stderrkey="StandardErrorPath"
fitbitlogpath="/private/var/log/fitbitd.log"
fitbitjobkey="com.fitbit.fitbitd"

# 1.
#   defaults read /Library/LaunchDaemons/com.fitbit.fitbitd StandardErrorPath
# if non-zero status, continue.
# otherwise exit?
#   sudo defaults write /Library/LaunchDaemons/com.fitbit.fitbitd StandardErrorPath "/private/var/log/fitbitd.log"
# fix this plist to be world-readable:
#   sudo chmod a+r /Library/LaunchDaemons/com.fitbit.fitbitd.plist
# make the log path:
#   sudo touch /var/log/fitbitd.log
# and make it world-writable (otherwise launchd can't redirect output to it)
#   sudo chown nobody:admin /var/log/fitbitd.log
# load the new entry:
#   sudo launchctl unload /Library/LaunchDaemons/com.fitbit.fitbitd.plist
#   sudo launchctl load /Library/LaunchDaemons/com.fitbit.fitbitd.plist
# then grep launchctl list for our entry:
#   sudo launchctl list com.fitbit.fitbitd | grep StandardErrorPath
# if it exits with non-zero status, apologize.
	# todo: have some debugging option to turn on for issues? or a command to run install.sh with for more info?
defaults read $fitbitplistshort $stderrkey
exitStatus=$?
if [ $exitStatus != 0 ]; then
	echo "Setting up fitbitd output redirection"
	
	sudo defaults write $fitbitplistshort $stderrkey "$fitbitlogpath"
	sudo chmod a+r $fitbitplist
	
	sudo touch $fitbitlogpath
	sudo chown nobody:admin $fitbitlogpath
	
	sudo launchctl unload $fitbitplist
	sudo launchctl load $fitbitplist
	
	sudo launchctl list $fitbitjobkey | grep $stderrkey
	exitStatus=$?
	if [ $exitStatus != 0 ]; then
		echo "Couldn't find log redirection in launchd job! Please report an issue at $githubissues."
		exit 1
	else
		echo "fitbitd output redirection done"
	fi
else
	echo "fitbitd's output is already redirected to $fitbitlogpath, skipping launchd setup"
fi


# 2.
# install an entry for newsyslogd to rotate our logs on our behalf:

newsyslog=/etc/newsyslog.conf
syslogRotationEntry="/var/log/fitbitd.log 640 7 1000 * JN"

grep "/var/log/fitbitd.log" $newsyslog
exitStatus=$?
if [ $exitStatus != 0 ]; then
	echo "grep didn't find the log entry, installing."
	# some trickery here with tee to append it as root but not print the output:
	echo $syslogRotationEntry | sudo tee -a $newsyslog > /dev/null
else
	echo "grep succeeded"
fi


# 3. 
