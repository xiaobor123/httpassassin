import subprocess,os
# gh_file_path = "/home/minipython/greenhouse/Greenhouse/gh.py"
gh_file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "greenhouse","Greenhouse","gh.py")
base_path = "/home/liuweijun/mybin/xiaomiax9000"
outpath = os.path.join(base_path, "outpath")
workspace = os.path.join(base_path, "workspace")
logpath = os.path.join(base_path, "log")
cache_path = os.path.join(base_path, "cache_path")
#target_bin = "/home/liuweijun/mybin/xiaomivac/workspace/xiaomivac/_SStarOta.bin.extracted/squashfs-root/usr/sbin/httpd"
#bin_args = "-c /home/liuweijun/HttpdAssassin/router_firmware_download/xiaomi/workspace/xiaomi/_miwifi_ra70_firmware_cc424_1.0.168.bin.extracted/ubifs-root/2B4.ubi/_img-870537086_vol-ubi_rootfs.ubifs.extracted/squashfs-root/etc/sysapihttpd/sysapihttpd.conf"
ip = "192.168.0.5"
ports = "80"
max_cycles = 25
rh = True
brand = "xiaomi"
img_path = "/home/liuweijun/mybin/xiaomiax9000/miwifi_ra70_firmware_cc424_1.0.168.bin"
cmd = f"python3 {gh_file_path} --outpath {outpath} --workspace {workspace} --logpath={logpath} --cache_path={cache_path} --ip {ip} --ports={ports} --max_cycles={max_cycles} -rh --brand={brand} --img_path={img_path} "
print(cmd)
subprocess.run(cmd, shell=True,cwd=os.path.dirname(gh_file_path))
# python3 /gh/gh.py --outpath --workspace /tmp/scratch --logpath= --cache_path= --ip --ports= --max_cycles= -rh --brand= --img_path=
