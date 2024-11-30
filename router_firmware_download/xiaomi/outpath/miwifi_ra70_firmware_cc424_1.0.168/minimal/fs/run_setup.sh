#!/bin/sh

/greenhouse/busybox sh /setup_dev.sh /greenhouse/busybox /ghdev
/greenhouse/busybox cp -r /ghtmp/* /tmp
/greenhouse/busybox cp -r /ghetc/* /etc

