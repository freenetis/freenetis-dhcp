#!/bin/bash
################################################################################
#                                                                              #
#  Author: Michal Kliment                                                      #
#  Description: This script generates config file of DHCP server               #
#  from FreenetIS                                                              #
#                                                                              #
#  Version: 0.1.3                                                              #
#                                                                              # 
################################################################################

# Version	
VERSION="0.1.3"

# Variables
CONFIG=/etc/freenetis/freenetis-dhcp.conf
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

# for old config backward compatibility
if [[ -z "$SERVER" && "$FULL_PATH" == *"etc-dhcp-dhcpd"* ]];
then
	SERVER="isc-dhcp"
fi

# DHCP server is old ISC DHCP
if [[ "$SERVER" == "isc-dhcp" ]];
then
	DHCP_CONF=${DHCP_CONF:="/etc/dhcp/dhcp.conf"}
	CUSTOM_DHCP_CONF=${CUSTOM_DHCP_CONF:="/etc/dhcp/dhcp.conf.custom"}
	FULL_PATH=$PATH_FN"/index.php/en/devices/export/"$DEVICE_ID"/debian-etc-dhcp-dhcpd/text"
# DHCP server is newer ISC KEA
elif [[ "$SERVER" == "isc-kea" ]];
then
	DHCP_CONF=${DHCP_CONF:="/etc/kea/kea-dhcp4.conf"}
	# custom dhcp config is not possible for ISC KEA
	CUSTOM_DHCP_CONF=""
	FULL_PATH=$PATH_FN"/index.php/en/devices/export/"$DEVICE_ID"/debian-etc-kea-kea-dhcp4/text"
# another DHCP servers are not implemented yet
else
	echo "[ERROR] `date -R`   Wrong configuration (SERVER not set properly)"
	exit 1
fi

# test downloaded config
test_config ()
{
	if [[ "$SERVER" == "isc-dhcp" ]];
	then
		dhcpd -4 -t -cf "$TMPFILE" &>/dev/null
	elif [[ "$SERVER" == "isc-kea" ]];
	then
		kea-dhcp4 -t "$TMPFILE" &>/dev/null
	fi
}

# restart DHCP server and test PID
restart_dhcp ()
{
	if [[ "$SERVER" == "isc-dhcp" ]];
	then
		killall -w dhcpd 2>/dev/null
		dhcpd -4 -q -cf "$DHCP_CONF"

		pidof -q dhcpd
	elif [[ "$SERVER" == "isc-kea" ]];
	then
		if pidof -q kea-dhcp4;
		then
			killall -s SIGHUP kea-dhcp4 2>/dev/null
		else
			systemctl start isc-kea-dhcp4-server.service
		fi

		pidof -q kea-dhcp4
	fi
}

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
	echo "[INFO] `date -R`   Downloading DHCP SERVER config from (${PATH_FN})"

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
			echo "[INFO] `date -R`   Testing new config..."
			# new config is valid
			if test_config;
			then
				echo "[INFO] `date -R`   New config is valid"
				echo "[INFO] `date -R`   Backuping old config to $DHCP_CONF.save"
				mv -f "$DHCP_CONF" "$DHCP_CONF".save
				echo "[INFO] `date -R`   Loading new config to $DHCP_CONF.save..."
				# copy config
				mv -f "$TMPFILE" "$DHCP_CONF"
				# make readable for all
				chmod +r "$DHCP_CONF"
				# restart DHCP server with new configuration
				echo "[INFO] `date -R`   Restarting DHCP server"
				if ! restart_dhcp;
				then
					echo "[ERROR] `date -R`   DHCP server is not running -> keeping old configuration"
					mv -f "$DHCP_CONF".save "$DHCP_CONF"
					# restart DHCP server with old configuration
					echo "[INFO] `date -R`   Restarting DHCP server"
					if restart_dhcp;
					then
						echo "[INFO] `date -R`   Restart completed"
					else
						echo "[ERROR] `date -R`   DHCP server is not running"
					fi
				else
					echo "[INFO] `date -R`   Restart completed"
				fi
			else
				echo "[ERROR] `date -R`   Invalid new config -> keeping old configuration"
				mv -f "$DHCP_CONF".save "$DHCP_CONF"
			fi
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
