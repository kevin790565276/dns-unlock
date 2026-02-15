#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}正在启动 Gost DNS 解锁服务端配置...${NC}"

# 1. 权限检查
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须使用 root 权限运行此脚本${NC}"
   exit 1
fi

# 2. 安装必要工具
apt-get update && apt-get install -y wget curl gzip lsof

# 3. 下载 Gost
ARCH=$(uname -m)
GOST_VER="2.11.5"
echo -e "检测到架构: ${ARCH}"

if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-amd64-$GOST_VER.gz"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-armv8-$GOST_VER.gz"
else
    echo -e "${RED}不支持的架构${NC}"
    exit 1
fi

wget -qO- $URL | gzip -d > /usr/local/bin/gost
chmod +x /usr/local/bin/gost

# 4. 处理 53 端口冲突
if lsof -i :53 > /dev/null; then
    echo -e "${GREEN}正在清理 53 端口占用...${NC}"
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    # 避免断网，设置临时 DNS
    rm /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi

# 5. 写入 Systemd 服务
cat << EOF > /etc/systemd/system/gost-dns.service
[Unit]
Description=Gost DNS Unlock Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L udp://:53?dns=8.8.8.8,1.1.1.1
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动并验证
systemctl daemon-reload
systemctl enable gost-dns
systemctl restart gost-dns

SERVER_IP=$(curl -s ipv4.icanhazip.com)
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "部署成功！"
echo -e "你的解锁机 DNS 地址为: ${RED}${SERVER_IP}${NC}"
echo -e "请确保防火墙已开启 ${RED}UDP 53${NC} 端口"
echo -e "${GREEN}------------------------------------------------${NC}"
