#!/bin/sh

boot_status="$(cat /tmp/boot_check_done 2>/dev/null | grep boot_done)"
while [ "$boot_status" != "boot_done" ]
do
	sleep 2
	boot_status="$(cat /tmp/boot_check_done 2>/dev/null | grep boot_done)"
done

sleep 10
/bin/flash.sh $1

