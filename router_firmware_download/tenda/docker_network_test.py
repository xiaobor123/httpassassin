import docker

# 创建 Docker 客户端对象
client = docker.from_env()

# 列出所有网络
docker_networks = client.networks.list()

# 遍历网络并打印详细信息
for network in docker_networks:
    print(f"Network ID: {network.id}")
    print(f"Network Name: {network.name}")
    print(f"Network Scope: {network.attrs['Scope']}")
    print(f"IPAM Configurations:")
    ipam_configs = network.attrs['IPAM']['Config']
    for config in ipam_configs:
        print(f"  - Subnet: {config['Subnet']}")
        print(f"    Gateway: {config['Gateway']}")
    print("---")
