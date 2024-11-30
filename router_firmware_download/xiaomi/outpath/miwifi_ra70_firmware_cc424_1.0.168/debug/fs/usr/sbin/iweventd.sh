#!/bin/sh
clean_jobs() {
    for pid in $(pgrep -P $$); do
       kill $pid
    done
}

trap "clean_jobs" TERM

/usr/sbin/iwevent 2>&1 | while read line;do echo $line | grep "Custom driver event" | /usr/sbin/iwevent-call;done &
#for r3d mic diff event
/usr/sbin/hostapd_event 2>&1 | while read line;do echo $line | grep "Custom driver event" | /usr/sbin/iwevent-call;done  &
wait
