#!/bin/sh
# Copyright (C) 2020 Xiaomi

#
# $1 = opt. reset/update
# usage:
#      wan_check.sh reset/update
#

OPT=$1

case $OPT in 
    reset)
        ubus call wan_check reset
    ;;

    update)
       ubus call wan_check update
    ;;

    blink_on)
        ubus call wan_check blink_on
    ;;

    blink_off)
       ubus call wan_check blink_off
    ;;

    blink_discovery)
       ubus call wan_check blink_discovery
    ;;

     * ) 
        echo "usage: wan_check.sh reset/update" >&2
  ;;
esac

