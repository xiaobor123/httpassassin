#!/bin/sh

chroot /fs /run_setup.sh

chroot fs /qemu-aarch64-static -hackbind -hackproc -hacksysinfo -execve "/qemu-aarch64-static -hackbind -hackproc -hacksysinfo " -E LD_PRELOAD="libnvram-faker.so" /bin/sh /run_background.sh > /fs/GREENHOUSE_BGLOG 2>&1


chroot fs /qemu-aarch64-static -pconly -hackbind -hackproc -hacksysinfo -D /trace.log0 -d exec,nochain,page -execve "/qemu-aarch64-static -pconly -hackbind -hackproc -hacksysinfo -d exec,nochain,page -D /trace.log" -E LD_PRELOAD="libnvram-faker.so" /bin/sh qemu_run.sh > /fs/GREENHOUSE_STDLOG 2>&1
echo "Greenhouse_EXIT_CODE::"$? >> /fs/GREENHOUSE_STDLOG
echo "Greenhouse_EXIT_CODE::" > GH_DONE
while true; do sleep 10000; done
