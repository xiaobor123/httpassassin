#!/bin/sh
# Copyright (C) 2020 Xiaomi
#

MILED_CONFIG="/etc/config/miled"
[ -e "$MILED_CONFIG" ] || return

ubus call miled refresh '{}'



