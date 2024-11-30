#!/bin/sh
# Copyright (C) 2020 Xiaomi

usage() {
	echo "$0 get_chan_2g"
	echo "$0 get_chan_5g"
	echo "$0 get_chan_5g_nbh"
	echo "$0 set_chan_2g XX"
	echo "$0 set_chan_5g XX"
	echo "$0 set_chan_5g_nbh XX"
	exit 1
}

BHTAG="game"
BHTAG_SEC="5g"
bh_tag=$(uci -q get misc.backhauls.backhaul)
[ -z "$bh_tag" ] && bh_tag="$BHTAG"
[ "$bh_tag" = "$BHTAG" ] && {
	bhdev=$bh_tag
	nbhdev=$(echo $BHTAG_SEC | sed 'y/g/G/')
} || {
	bhdev=$(echo $bh_tag | sed 'y/g/G/')
	nbhdev=$BHTAG
}

log(){
	logger -t "mqtt_xqwhc_channel: " -p9 "$1"
}

check_bh_radio(){
	chan=$1
	[ "$bh_tag" = "$BHTAG" -a "$chan" -gt 64 ] && {
		log " xqwhc_channel, bh channel change to $chan, bh radio change $BHTAG -> $BHTAG_SEC"
		ifname_bh_ap=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)
		/usr/sbin/topomon_action.sh wifi_ap_if_down $ifname_bh_ap
		bh_tag=$BHTAG_SEC
		bhdev=$(echo $bh_tag | sed 'y/g/G/')
		nbhdev=$BHTAG
		uci -q set misc.backhauls.backhaul="$BHTAG_SEC"
		uci commit misc
		ifname_bh_ap=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)
		/usr/sbin/topomon_action.sh wifi_ap_if_up $ifname_bh_ap
	}
	[ "$bh_tag" != "$BHTAG" -a "$chan" -ge 36 -a "$chan" -le 64 ] && {
		log " xqwhc_channel, bh channel change to $chan, bh radio change $BHTAG_SEC -> $BHTAG"
		ifname_bh_ap=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)
		/usr/sbin/topomon_action.sh wifi_ap_if_down $ifname_bh_ap
		bh_tag=$BHTAG
		bhdev=$bh_tag
		nbhdev=$(echo $BHTAG_SEC | sed 'y/g/G/')
		uci -q set misc.backhauls.backhaul="$BHTAG"
		uci commit misc
		ifname_bh_ap=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)
		/usr/sbin/topomon_action.sh wifi_ap_if_up $ifname_bh_ap
	}
}


get_chan_2g() {
local ap_ifname_2g=$(uci -q get misc.wireless.ifname_2G)
local channel_2g="`iwlist $ap_ifname_2g channel | grep -Eo "\(Channel.*\)" | grep -Eo "[1-9]+"`"
echo "$channel_2g"
}

#get channel on 5g bh radio
get_chan_5g() {
local ap_ifname_5g=$(uci -q get misc.wireless.ifname_$bhdev)
local channel_5g="`iwlist $ap_ifname_5g channel | grep -Eo "\(Channel.*\)" | grep -Eo "[0-9]+"`"
echo "$channel_5g"
}

#get channel on 5g nbh radio
get_chan_5g_nbh() {
local ap_ifname_5g_nbh=$(uci -q get misc.wireless.ifname_$nbhdev)
local channel_5g_nbh="`iwlist $ap_ifname_5g_nbh channel | grep -Eo "\(Channel.*\)" | grep -Eo "[0-9]+"`"
echo "$channel_5g_nbh"
}

set_chan_2g() {
local channel=$1
local ap_ifname_2g=$(uci -q get misc.wireless.ifname_2G)
iwconfig $ap_ifname_2g channel $channel
}

#set channel on 5g bh radio
set_chan_5g() {
local new_channel=$1
local netmode=$(uci -q get xiaoqiang.common.NETMODE)
if [ "$netmode" = "whc_re" ]; then
	local ap_ifname_5g=$(uci -q get misc.wireless.ifname_$bhdev)
	local current_channel="`iwlist $ap_ifname_5g channel | grep -Eo "\(Channel.*\)" | grep -Eo "[0-9]+"`"
	local bit_rate=`iwinfo $ap_ifname_5g info | grep 'Bit Rate' | awk -F: '{print $2}' | awk '{gsub(/^\s+|\s+$/, "");print}'`
	if [ "$new_channel" != "$current_channel" -a "$bit_rate" != "unknown" ] ; then
		iwconfig $ap_ifname_5g channel $new_channel
	fi
fi
}

#set channel on 5g nbh radio
set_chan_5g_nbh() {
local new_channel=$1
local netmode=$(uci -q get xiaoqiang.common.NETMODE)
if [ "$netmode" = "whc_re" ]; then
	local ap_ifname_5g_nbh=$(uci -q get misc.wireless.ifname_$nbhdev)
	local current_channel="`iwlist $ap_ifname_5g_nbh channel | grep -Eo "\(Channel.*\)" | grep -Eo "[0-9]+"`"
	local bit_rate=`iwinfo $ap_ifname_5g_nbh info | grep 'Bit Rate' | awk -F: '{print $2}' | awk '{gsub(/^\s+|\s+$/, "");print}'`
	if [ "$new_channel" != "$current_channel" -a "$bit_rate" != "unknown" ] ; then
		iwconfig $ap_ifname_5g_nbh channel $new_channel
	fi
fi
}

case "$1" in
	get_chan_2g)
	get_chan_2g
	;;
	get_chan_5g)
	get_chan_5g
	;;
	get_chan_5g_nbh)
	get_chan_5g_nbh
	;;
	set_chan_2g)
	set_chan_2g "$2"
	;;
	set_chan_5g)
	check_bh_radio "$2"
	set_chan_5g "$2"
	;;
	set_chan_5g_nbh)
	set_chan_5g_nbh "$2"
	;;
	*)
	usage
	;;
esac
