#! /bin/bash

### BEGIN INIT INFO
# Provides:          freenetis-dhcp
# Required-Start:    $remote_fs
# Required-Stop:     $remote_fs
# Should-Start:      $network $syslog
# Should-Stop:       $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop freenetis DHCP sync daemon
# Description:       FreenetIS initialization DHCP synchronization script.
### END INIT INFO

################################################################################
#                                                                              #
# This script serves for initialization of DHCP of IS FreenetIS                #
#                                                                              #
# Author  Ondrej Fibich 2013                                                   #
# Email   ondrej.fibic@gmail.com                                               #
#                                                                              #
# Name    freenetis-dhcp.init.sh                                               #
# Version 0.1.1                                                                #
#                                                                              #
################################################################################

#Load variables from config file
CONFIG=/etc/freenetis/freenetis-dhcp.conf

# Path to DHCP synchronization file
DHCP_SYNCFILE=/usr/sbin/freenetis-dhcp-sync

#Load variables
if [ -f ${CONFIG} ]; then
	. $CONFIG;
else
	echo "Config file is missing at path $CONFIG."
	echo "Terminating..."
	exit 0
fi

start_dhcp ()
{
	if [ `ps aux | grep "$DHCP_SYNCFILE" | grep -v grep | wc -l` -gt 0 ]; then
		echo "Already started"
		return 0
	fi

	cat /dev/null > "$LOG_FILE"

	echo -n "Starting FreenetIS DHCP deamon: "
	nohup "$DHCP_SYNCFILE" >> "$LOG_FILE" 2>&1 &

	# test if daemon is started
	if [ `ps aux | grep "$DHCP_SYNCFILE" | grep -v grep | wc -l` -gt 0 ];
	then
		echo "OK"
	else
		echo "FAILED!"
	fi

	return 0
}

stop_dhcp ()
{
	if [ `ps aux | grep "$DHCP_SYNCFILE" | grep -v grep | wc -l` -lt 1 ]; then
		echo "Already stopped"
		return 0
	fi

	#Killing of process by sigterm
	echo -n "Stopping FreenetIS DHCP deamon: "
	set +e
	killall freenetis-dhcp-sync
	set -e

	# test if daemon is stopped
	if [ `ps aux | grep "$DHCP_SYNCFILE" | grep -v grep | wc -l` -eq 0 ];
	then
		echo "OK"
	else
		echo "FAILED!";
	fi

	return 0
}

status_dhcp ()
{
	if [ `ps aux | grep "$DHCP_SYNCFILE" | grep -v grep | wc -l` -gt 0 ]; then
		echo -n "Freenetis DHCP is running with PID "
		echo `ps aux | grep "$DHCP_SYNCFILE" | grep -v grep | awk '{print $2}'`
		return 0
	else
		echo "Freenetis DHCP is not running"
		return 0
	fi
}

usage_dhcp ()
{
	echo "usage : `echo $0` (start|stop|restart|status|help)"
}

help_dhcp ()
{
	echo "  start - initialization of synchronization of DHCP"
	echo "  stop - stops synchronization of DHCP"
	echo "  restart - restarts synchronization of DHCP"
	echo "  status - returns current state of DHCP synchronization"
	echo "  help - prints help for DHCP synchronization"
}

# Is parameter #1 zero length?
if [ -z "$1" ]; then
	usage_dhcp
	exit 0
fi;

case "$1" in

	start)
		start_dhcp
		exit 0
	;;

	restart|reload|force-reload) # reload is same thing as reload
		stop_dhcp
		start_dhcp
		exit 0
	;;

	stop)
		stop_dhcp
		exit 0
	;;

	status)
		status_dhcp
		exit 0
	;;

	help)
		usage_dhcp
		help_dhcp
		exit 0
	;;

	*)
		usage_dhcp
		exit 0
	;;

esac

exit 0
