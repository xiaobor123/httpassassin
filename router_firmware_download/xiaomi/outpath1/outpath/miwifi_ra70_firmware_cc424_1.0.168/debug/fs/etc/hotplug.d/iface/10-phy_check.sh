#!/bin/sh
#logger -p notice -t "hotplug.d" "10-phy_check.sh: run because of $INTERFACE $ACTION"

if [ "$INTERFACE" = "wan" -a "$ACTION" = "ifup" ]; then
        wan_speed=$(uci -q get xiaoqiang.common.WAN_SPEED)
        [ -z "$wan_speed" -o $wan_speed -eq 0 ] && return

        wan_port=$(uci -q get network.wan.ifname)

        cur_wan_speed=$(ethtool $wan_port | grep "Speed" | cut -d " " -f 2 | cut -d "M" -f 1)
        if [ $cur_wan_speed != $wan_speed ]; then
		    . /lib/xq-misc/phy_switch.sh
            if [ "$wan_speed" = "2500" -a "$wan_port" = "eth3" ]; then
			   return
            fi
            sw_set_wan_neg_speed $wan_speed
        fi
fi
