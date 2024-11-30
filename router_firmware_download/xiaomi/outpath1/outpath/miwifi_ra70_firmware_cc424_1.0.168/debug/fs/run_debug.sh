#!/bin/sh

chroot /fs /run_setup.sh

chroot fs /qemu-aarch64-static -hackbind -hackproc -hacksysinfo -execve "/qemu-aarch64-static -hackbind -hackproc -hacksysinfo " -E LD_PRELOAD="libnvram-faker.so" /bin/sh /run_background.sh > /fs/GREENHOUSE_BGLOG 2>&1


chroot fs /qemu-aarch64-static -hackbind -hackproc -hacksysinfo -execve "/qemu-aarch64-static -hackbind -hackproc -hacksysinfo " -E LD_PRELOAD="libnvram-faker.so" /bin/sh /qemu_run.sh


while true; do sleep 10000; done