################################################################################
#                                                                              #
#  Author: Michal Kliment                                                      #
#  Description: This script regenerate DHCP server from FreenetIS              #
#                                                                              #
#  Version: 0.1.3                                                              #
#                                                                              # 
################################################################################

############ CONFIG VALUES #####################################################

# Base PATH_FN to running FreenetIS instance
:global PATHFN "http://localhost/freenetis"

# ID of device from FreenetIS
:global DEVICEID 0

# Forced download
:global FORCED 0

############ SCRIPT - DO NOT CHANGE! ###########################################

# First run with forced download
:if ([:len [/file find name="dhcp.rsc"]] = 0) do={
:set FORCED 1
}

# Download script from FreenetIS
/tool fetch url="$PATHFN/en/devices/export/$DEVICEID/mikrotik-ip-dhcp-server/text/$FORCED" dst-path="dhcp.rsc"

# Waiting to end of downloading
:delay 3

# Run script
import dhcp.rsc
