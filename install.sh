#!/bin/zsh
# A short script to clean up fitbitd's verbose logging, by redirecting it to a logfile.
# Created by Christopher Bowns on 2011-09-25
# Copyright 2011 Mechanical Pants Software

# here's the lowdown:
# 1. set /Library/LaunchDaemons/com.fitbit.fitbitd's StandardErrorPath to /var/log/fitbitd.log
# 2. kick launchd so it sees the new entry
# 3. install an entry in newsyslog.conf so we rotate and toss old logs periodically

githubissues="https://github.com/cbowns/fitbit/issues/new"

fitbitplistshort="/Library/LaunchDaemons/com.fitbit.fitbitd"
fitbitplist="$fitbitplistshort.plist"
stderrkey="StandardErrorPath"
stdoutkey="StandardOutPath"
fitbitlogpath_noprivate="/var/log/fitbitd.log"
fitbitlogpath="/private$fitbitlogpath_noprivate"
fitbitjobkey="com.fitbit.fitbitd"


{ defaults read $fitbitplistshort $stderrkey 2>&1 } > /dev/null
stdErrExists=$?
{ defaults read $fitbitplistshort $stdoutkey 2>&1 } > /dev/null
stdOutExists=$?
if [ $stdErrExists != 0 -o $stdOutExists != 0 ]; then
	echo "Setting up fitbitd output redirection"

	sudo defaults write $fitbitplistshort $stderrkey "$fitbitlogpath" 2>&1 > /dev/null
	sudo defaults write $fitbitplistshort $stdoutkey "$fitbitlogpath" 2>&1 > /dev/null
	sudo chmod a+r $fitbitplist

	sudo touch $fitbitlogpath
	sudo chown nobody:admin $fitbitlogpath

	sudo launchctl unload $fitbitplist
	sudo launchctl load $fitbitplist

	sudo launchctl list $fitbitjobkey | grep $stderrkey 2>&1 > /dev/null
	stdErrRedirected=$?
	sudo launchctl list $fitbitjobkey | grep $stdoutkey 2>&1 > /dev/null
	stdOutRedirected=$?
	if [ $stdErrRedirected != 0 -o $stdOutRedirected != 0 ]; then
		echo "Couldn't confirm log redirection in launchd job! Please report an issue at $githubissues."
		exit 1
	else
		echo "fitbitd output redirection done"
	fi
else
	echo "fitbitd's output is already redirected to $fitbitlogpath_noprivate, skipping launchd setup"
fi


newsyslogpath="/etc/newsyslog.conf"
syslogRotationEntry="/var/log/fitbitd.log 666 5 5000 * J /var/run/com.fitbit.fitbitd.pid 14"

grep $fitbitlogpath_noprivate $newsyslogpath 2>&1 > /dev/null
exitStatus=$?
if [ $exitStatus != 0 ]; then
	echo "Setting up fitbitd log rotation"
	# some trickery here with tee to append it as root but not print the output:
	echo $syslogRotationEntry | sudo tee -a $newsyslogpath
else
	echo "Log rotation for $fitbitlogpath_noprivate is already installed to $newsyslogpath, skipping"
fi
