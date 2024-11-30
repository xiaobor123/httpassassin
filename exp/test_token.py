import requests,time,random
import hashlib



# 生成 nonce 的函数
def nonce_create():
    type = 0
    device_id = '02:42:68:ee:c7:23'
    current_time = int(time.time())  # 获取当前 Unix 时间戳
    random_number = random.randint(0, 9999)  # 生成 0 到 9999 之间的随机数
    return f"{type}_{device_id}_{current_time}_{random_number}"

# 计算 SHA1 哈希的函数
def sha1_hash(data):
    return hashlib.sha1(data.encode()).hexdigest()

# 生成 oldPwd 的函数
def generate_old_pwd(pwd, nonce, key):
    # 第一步：计算 pwd + key 的 SHA1 哈希
    step1_hash = sha1_hash(pwd + key)
    
    # 第二步：nonce + step1_hash 的 SHA1 哈希
    final_hash = sha1_hash(nonce + step1_hash)
    
    return final_hash

if __name__ == "__main__":
    # 定义请求的 URL
    url = "http://172.17.0.3/cgi-bin/luci/api/xqsystem/login"
    # 请求头
    headers = {
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "Cookie": "psp=admin|||2|||0; __guid=209511506.42092784015174060.1726622689372.4326; monitor_count=5",
        "Host": "172.17.0.4",
        "Origin": "http://172.17.0.3",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        "X-Requested-With": "XMLHttpRequest"
    }

    # POST 请求的数据 (假设登录请求需要以下字段)



    # 固定的 key 值
    key = 'a2ffa5c9be07488bbb04a3a47d3c5f6a'



    # 示例使用
    nonce = nonce_create()  # 生成 nonce
    pwd = 'admin'  # 假设用户的密码
    generated_pwd = generate_old_pwd(pwd, nonce, key)

    print(f"Generated oldPwd: {generated_pwd}")
    payload = {
        "username": "admin",  # 假设用户名
        "password": generated_pwd,  # 假设密码
        "logtype":"2",
        "nonce": nonce    
    }
    print(payload)


    # 发送 POST 请求
    response = requests.post(url, headers=headers, data=payload)

    # 输出请求状态码和响应内容
    print("Status Code:", response.status_code)
    print("Response Body:", response.text)
