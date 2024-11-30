#!/bin/sh
#logger -p notice -t "hotplug.d" "90-wan_light_chech.sh: run because of $INTERFACE $ACTION"


wanif=$(uci -q get network.wan.ifname)
if [ "$INTERFACE" = "wan" -o "$INTERFACE" = "$wanif" ]; then
    [ "$ACTION" = "ifdown" -o "$ACTION" = "ifup" ] && {
        /usr/sbin/wan_check.sh reset &
        /usr/sbin/wan_check.sh update &
    }
fi
