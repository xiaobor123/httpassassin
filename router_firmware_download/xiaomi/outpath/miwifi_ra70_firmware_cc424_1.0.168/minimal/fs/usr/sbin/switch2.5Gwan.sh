#!/bin/sh
# Copyright (C) 2020 Xiaomi
# main
#wanlan_swap

OPT=$1
INIT=$2

wanlan_swap_log()
{
    logger -p debug -t wanlan_swap "$1"
}

wan_swap_lan()
{
    local wan_old=$(uci -q get network.wan.ifname)
    local wan6_exist=$(uci -q get network.wan_6.ifname)
    local wan_new="eth3"
    uci -q batch <<EOF
    set xiaoqiang.common.wan_port_type='1G'
    commit xiaoqiang


    set network.lan.ifname='eth0 eth1 eth2 eth4'
    set network.wan.ifname=$wan_new
    commit network

    set misc.sw_reg.sw_lan_ports='1 2 3 5'
    set misc.sw_reg.sw_wan_port='4'

    set misc.samba.et_ifname='eth0 eth1 eth2 eth4'
    commit misc

EOF
    [ -n "$wan6_exist" ] && uci set network.wan_6.ifname=$wan_new

    brctl delif br-lan $wan_new
    brctl addif br-lan $wan_old
    [ -z "$INIT" ] && /etc/init.d/network restart
    /etc/init.d/samba restart
}

lan_swap_wan()
{
    local wan_old=$(uci -q get network.wan.ifname)
    local wan6_exist=$(uci -q get network.wan_6.ifname)
    local wan_new="eth4"
    uci -q batch <<EOF
    set xiaoqiang.common.wan_port_type='2.5G'
    commit xiaoqiang

    set network.lan.ifname='eth0 eth1 eth2 eth3'
    set network.wan.ifname=$wan_new
    commit network

    set misc.sw_reg.sw_lan_ports='1 2 3 4'
    set misc.sw_reg.sw_wan_port='5'

    set misc.samba.et_ifname='eth0 eth1 eth2 eth3'
    commit misc
EOF
    [ -n "$wan6_exist" ] && uci set network.wan_6.ifname=$wan_new

    brctl delif br-lan $wan_new
    brctl addif br-lan $wan_old
    [ -z "$INIT" ] && /etc/init.d/network restart
    /etc/init.d/samba restart
}

OPT=$1

wanlan_swap_log "$OPT"

case $OPT in
    wan)
        lan_swap_wan
        return $?
    ;;

    lan)
        wan_swap_lan
        return $?
    ;;
esac

