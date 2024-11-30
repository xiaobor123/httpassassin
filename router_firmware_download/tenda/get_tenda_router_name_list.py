import requests,os
from bs4 import BeautifulSoup

router_type = 'wifi4-routers'
# 目标URL
url = f'https://www.tenda.com.cn/products/{router_type}.html'

# 发送GET请求
response = requests.get(url)

# 检查请求是否成功
if response.status_code == 200:
    # 解析HTML内容
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # 定位到目标区域
    target_div = soup.select_one('body > div:nth-of-type(3) > div > div:nth-of-type(2) > div > div:nth-of-type(1)')
    
    # 提取所有a标签并获取title属性
    if target_div:
        routers = target_div.find_all('a', title=True)
        router_models = [router['title'] for router in routers]

        # 打印路由器型号列表
        for model in router_models:
            print(model)
        txt_file = os.path.join(os.path.dirname(__file__), router_type+'.txt')
        with open(txt_file, 'w') as f:
            f.write('\n'.join(router_models))
    else:
        print('未找到目标区域')
else:
    print(f'请求失败，状态码: {response.status_code}')
