#!/bin/sh

logger -s -p 3 -t "memmarkshalling" "memory markshalling"

sync;sync;sync

echo 3 > /proc/sys/vm/drop_caches

echo 1 > /proc/sys/vm/compact_memory
