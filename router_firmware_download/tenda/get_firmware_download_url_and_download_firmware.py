import os
import requests

# 从文件中读取keys值
keys_list = []
titie = 'wifi5-routers'
BASE_PATH = os.path.join(os.path.dirname(__file__), titie)

def get_path_func(loc):
    return os.path.join(BASE_PATH, loc)

with open(get_path_func(titie + ".txt"), 'r') as file:
    keys_list = file.readlines()

# 目标URL
url = 'https://www.tenda.com.cn/ashx/LoadDownloads.ashx'

# 请求头
headers = {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'Cookie': 'Hm_lvt_40aeb5e05a2c1dff33f597e5db16be20=1718182898,1718784661,1719125215,1719384444; ASP.NET_SessionId=hnzo2gl4rww01yt2bntimqxr; Hm_lpvt_40aeb5e05a2c1dff33f597e5db16be20=1719388519',
    'Dnt': '1',
    'Origin': 'https://www.tenda.com.cn',
    'Referer': 'https://www.tenda.com.cn/download/default.html',
    'Sec-Ch-Ua': '"Not/A)Brand";v="8", "Chromium";v="126", "Microsoft Edge";v="126"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"Windows"',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-origin',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0',
    'X-Requested-With': 'XMLHttpRequest',
}

# 保存D_BankUrl的文件
output_file = get_path_func(titie + "_firmware_urls.txt")
# 创建保存固件的文件夹
firmware_dir = get_path_func('downloaded_firmware')
os.makedirs(firmware_dir, exist_ok=True)

# 保存所有D_BankUrl
all_urls = []

# 处理每个key
for key in keys_list:
    # 请求体
    data = {
        'pid': '',
        'tid': '',
        'keys': key.strip()
    }

    # 发送POST请求
    response = requests.post(url, headers=headers, data=data)

    # 检查请求是否成功
    if response.status_code == 200:
        result = response.json()
        if result:
            # 筛选出包含“升级软件”字样且后缀为.zip或.rar的文件
            firmware_urls = [item['D_BankUrl'] for item in result if '升级软件' in item['D_title'] and (item['D_BankUrl'].endswith('.zip') or item['D_BankUrl'].endswith('.rar'))]
            if firmware_urls:
                latest_firmware_url = max(firmware_urls, key=lambda url: url.split('/')[-1])
                all_urls.append(latest_firmware_url)

                # 下载最新固件
                firmware_response = requests.get(f'https:{latest_firmware_url}')
                if firmware_response.status_code == 200:
                    filename = os.path.join(firmware_dir, latest_firmware_url.split('/')[-1])
                    with open(filename, 'wb') as f:
                        f.write(firmware_response.content)
                    print(f'固件下载成功: {filename}')
                else:
                    print(f'下载固件失败，状态码: {firmware_response.status_code}')
            else:
                print(f'没有符合条件的固件信息: {key.strip()}')
        else:
            print(f'没有找到固件信息: {key.strip()}')
    else:
        print(f'请求失败，状态码: {response.status_code}')

# 将所有D_BankUrl保存到文件中
with open(output_file, 'w') as f:
    for url in all_urls:
        f.write(f'https:{url}\n')

print(f'所有固件链接已保存到文件: {output_file}')
