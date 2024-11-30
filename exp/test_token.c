#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <openssl/sha.h>
#include <curl/curl.h>

// 生成 nonce 的函数
char* nonce_create() {
    int type = 0;
    const char* device_id = "02:42:68:ee:c7:23";
    time_t current_time = time(NULL);  // 获取当前 Unix 时间戳
    int random_number = rand() % 10000;  // 生成 0 到 9999 之间的随机数

    // 分配内存并格式化字符串
    char* nonce = malloc(10000);
    snprintf(nonce, 10000, "%d_%s_%ld_%d", type, device_id, current_time, random_number);
    return nonce;
}

// 计算 SHA1 哈希的函数
char* sha1_hash(const char* data) {
    unsigned char hash[SHA_DIGEST_LENGTH];
    SHA1((unsigned char*)data, strlen(data), hash);

    // 转换为十六进制字符串
    char* hash_str = malloc(SHA_DIGEST_LENGTH * 2 + 1);
    for (int i = 0; i < SHA_DIGEST_LENGTH; i++) {
        sprintf(&hash_str[i * 2], "%02x", hash[i]);
    }
    return hash_str;
}

// 生成 oldPwd 的函数
char* generate_old_pwd(const char* pwd, const char* nonce, const char* key) {
    // 第一步：计算 pwd + key 的 SHA1 哈希
    char* step1_hash = sha1_hash(strcat(strdup(pwd), key));
    
    // 第二步：nonce + step1_hash 的 SHA1 哈希
    char* final_hash = sha1_hash(strcat(strdup(nonce), step1_hash));
    
    free(step1_hash);
    return final_hash;
}

// 回调函数，用于处理接收到的响应数据
static size_t write_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t total_size = size * nmemb;
    strncat((char*)userp, (char*)contents, total_size);
    return total_size;
}

int main() {
    // 定义请求的 URL
    const char* url = "http://172.17.0.5/cgi-bin/luci/api/xqsystem/login";
    
    // 固定的 key 值
    const char* key = "a2ffa5c9be07488bbb04a3a47d3c5f6a";
    
    // 示例使用
    char* nonce = nonce_create();  // 生成 nonce
    const char* pwd = "admin";  // 假设用户的密码
    char* generated_pwd = generate_old_pwd(pwd, nonce, key);
    
    printf("Generated oldPwd: %s\n", generated_pwd);

    // 使用 libcurl 发送 POST 请求
    CURL *curl;
    CURLcode res;
    
    // 初始化 libcurl
    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();
    
    if(curl) {
        // 设置请求的 URL
        curl_easy_setopt(curl, CURLOPT_URL, url);
        
        // 设置请求头
        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Accept: */*");
        headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded; charset=UTF-8");
        headers = curl_slist_append(headers, "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        
        // 设置 POST 数据
        char post_data[256];
        snprintf(post_data, sizeof(post_data), "username=admin&password=%s&logtype=2&nonce=%s", generated_pwd, nonce);
        
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_data);
        
        // 定义用于存储响应数据的缓冲区
        char response_data[10000] = {0};  // 预先分配一个较大的缓冲区
        
        // 设置回调函数来处理响应数据
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
        
        // 设置缓冲区用来存储响应内容
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)response_data);
        
        // 发送 POST 请求
        res = curl_easy_perform(curl);
        
        // 检查请求是否成功
        if(res != CURLE_OK) {
            fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
        } else {
            // 获取并打印 HTTP 响应状态码
            long response_code;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
            printf("HTTP Response Code: %ld\n", response_code);
            
            // 打印响应内容
            printf("Response Body: %s\n", response_data);
            char *token_ptr = strstr(response_data, "\"token\":\"");
            if (token_ptr) {
                token_ptr += 9;  // 跳过 "token":" 的长度
                char *token_end = strchr(token_ptr, '"');
                if (token_end) {
                    *token_end = '\0';
                    printf("Extracted Token: %s\n", token_ptr);
                }
            }
        }
        
        // 清理
        curl_easy_cleanup(curl);
        curl_slist_free_all(headers);
        curl_global_cleanup();
    }

    // 清理
    free(nonce);
    free(generated_pwd);
    curl_global_cleanup();
    //printf("123\n");
    return 0;
}
