#!/bin/sh
cd /
/sbin/procd &
/sbin/ubusd &
ln -sf /usr/bin/util-linux-flock /usr/bin/flock
echo "WAUST-8WAUDT" > /etc/TZ
/usr/sbin/datacenter &
/usr/sbin/plugincenter &
/usr/bin/spawn-fcgi -a 127.0.0.1 -p 8920 -U nobody -C 0 -F 2 -- /usr/bin/fcgi-cgi -c 2
cp /fuzz_bins/qemu/afl-qemu-trace-aarch64 /usr/bin/afl-qemu-trace
cp /qemu-aarch64-static /qemu-static
touch /GH_SUCCESSFUL_BIND
mkdir -p /scratch
cp -a /fuzz/* /scratch
cd /scratch
export AFL_ENTRYPOINT=0x0000005500027688
export LD_BIND_LAZY=1
export AFL_NO_AFFINITY=1
/sbin/uci set xiaoqiang.common.INITTED=1
/sbin/uci commit



#exec /fuzz_bins/bin/afl-fuzz -t 1000 -Q -x /scratch/dictionary -i /scratch/seeds -o /scratch/output -- /usr/sbin/sysapihttpd
#GH_DRYRUN=1 /usr/bin/afl-qemu-trace -strace -hookhack -hackbind -hackproc -execve "/qemu-static -hackbind -hackproc" -- /usr/sbin/sysapihttpd 

