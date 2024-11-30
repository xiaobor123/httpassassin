#!/bin/bash

# 检查是否提供了目录路径
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# 获取目录路径
directory_path=$1

# 进入固件下载目录
cd "$directory_path" || exit

# 遍历目录中的每一个zip文件
for zip_file in *.zip; do
    # 提取文件名并创建解压目录
    unzip_dir="${zip_file%.*}"
    mkdir -p "$unzip_dir"
    
    # 解压固件
    unzip "$zip_file" -d "$unzip_dir"

    # 查找固件文件名
    firmware_file=$(find "$unzip_dir" -type f -name "*.bin")

    # 检查是否找到了固件文件
    if [ -z "$firmware_file" ]; then
        echo "No firmware file found in the extracted directory for $zip_file."
        continue
    fi

    # 执行binwalk命令
    binwalk_output="$unzip_dir/binwalk_output.txt"
    binwalk -Me "$firmware_file" > "$binwalk_output"

    # 检查binwalk输出是否包含OpenSSL加密标志
    if grep -q "OpenSSL encryption" "$binwalk_output"; then
        echo "The firmware file $firmware_file contains OpenSSL encryption."
    else
        echo "The firmware file $firmware_file does not contain OpenSSL encryption."
    fi
done
