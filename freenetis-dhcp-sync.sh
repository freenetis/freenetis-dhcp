#!/bin/bash
################################################################################
#                                                                              #
#  Author: Michal Kliment                                                      #
#  Description: This script generates config file of ISC DHCP server           #
#  from FreenetIS                                                              #
#                                                                              #
#  Version: 0.1.3                                                              #
#                                                                              # 
################################################################################

# Version	
VERSION="0.1.3"

# Variables
CONFIG=/etc/freenetis/freenetis-dhcp.conf
CUSTOM_DHCP_CONF=/etc/dhcp/dhcp.conf.custom
FORCED=1

# Vesion info? Only possible arg.
if [ $# -eq 1 ]; then
	if [ "$1" == "version"  ]; then
		echo "$VERSION"
		exit 0
	fi
fi

# Load variables
if [ -e $CONFIG ]; then 
	. $CONFIG || true
else
	echo "`date -R`   Config file is missing at path $CONFIG. Terminating..."
	exit 0
fi

# check config
if [[ ! "$DEVICE_ID" =~ ^[0-9]+$ ]] || [ $DEVICE_ID -lt 1 ]; then
	echo "[ERROR] `date -R`   Wrong configuration (ID not set properly)"
	exit 1
fi

if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]] || [ $TIMEOUT -lt 1 ]; then
	echo "[ERROR] `date -R`   Wrong configuration (TIMEOUT not set properly)"
	exit 1
fi

# endless loop
while true;
do
	#path
	if [ "$FORCED" = 1 ]; then # forced download (#474)
		DOWN_PATH="$FULL_PATH/1"
		FORCED=0
	else
		DOWN_PATH="$FULL_PATH"
	fi
	# download
	TMPFILE=`mktemp`
	echo "[INFO] `date -R`   Downloading ISC DHCP SERVER config from (${PATH_FN})"

	status=`curl -s -o "$TMPFILE" -w "%{http_code}" "$DOWN_PATH"`

	# make sure that config exist
	touch "$DHCP_CONF"

	# check download
	if [ "$status" = "200" ]; then
		# attach custom conf if exists
		if [ -r "$CUSTOM_DHCP_CONF" ]; then
			cat "$CUSTOM_DHCP_CONF" >> "$TMPFILE"
		fi
		# config has been change
		if [ `diff "$TMPFILE" "$DHCP_CONF" | wc -l` -gt 0 ]; then
			echo "[INFO] `date -R`   Downloaded (code: $status)"
			echo "[INFO] `date -R`   Backuping old config to $DHCP_CONF.save"
			mv -f "$DHCP_CONF" "$DHCP_CONF".save
			echo "[INFO] `date -R`   Loading new config to $DHCP_CONF.save..."
			# copy config
			mv -f "$TMPFILE" "$DHCP_CONF"
			#restart DHCP server
			echo "[INFO] `date -R`   Restarting ISC DHCP server"

			service isc-dhcp-server restart 2>&1 >/dev/null
		else
			echo "[INFO] `date -R`   No change -> keeping old configuration"
		fi
	elif [[ "$status" =~ ^30[0-9] ]]; then
		echo "[INFO] `date -R`   DHCP configuration not changed"
	elif [ "$status" = "404" ]; then
		echo "[ERROR] `date -R`   Download failed (code: $status). Wrong path to FreenetIS or device $DEVICE_ID not exists."
	elif [ "$status" = "403" ]; then
		echo "[ERROR] `date -R`   Download failed (code: $status). Device $DEVICE_ID not configured properly."
	else
		echo "[ERROR] `date -R`   Download failed (code: $status)"
	fi

	rm -f "$TMPFILE"
	sleep $TIMEOUT
done
