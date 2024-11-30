#!/bin/sh
qosflag=`uci get miqos.settings.enabled 2>/dev/null`
[ "$qosflag" -ne "1" ] && return 0

# EVENT: 1:up, 0:down
if [ "$EVENT" = "1" ]; then
    /etc/init.d/miqos device_in 00
else
    /etc/init.d/miqos device_out 00
fi
