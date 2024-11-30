#!/bin/sh

cleanup() {
    # 等待一些时间确保所有进程都启动并运行
    sleep 1

    # 打印当前进程列表并过滤掉 PID 为 1 的进程
    ps | /fuzz_bins/utils/grep 'qemu' | /fuzz_bins/utils/grep -v 'grep' | /fuzz_bins/utils/grep -v ' 1 ' > /tmp/pids

    # 读取进程列表
    out=$(cat /tmp/pids)
    

    # 如果找到进程
    if [ -n "$out" ]; then
        # 遍历每个进程，获取其 PID 并强制 kill 掉
        while read -r line; do
            pid=$(echo $line | /fuzz_bins/utils/awk '{print $1}')
            echo "Process still exists: $pid, killing it." >> /tmp/log
            kill -9 $pid
        done < /tmp/pids
    fi
}

# 调用 cleanup 函数
cleanup
