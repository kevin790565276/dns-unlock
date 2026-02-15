#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}正在启动 Gost DNS 解锁服务端配置 (v2.0)...${NC}"

# 1. 权限与工具检查
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请用 root 运行${NC}" && exit 1
apt-get update && apt-get install -y wget curl gzip lsof || yum install -y wget curl gzip lsof

# 2. 下载 Gost (自动识别架构)
ARCH=$(uname -m)
GOST_VER="2.11.5"
if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-amd64-$GOST_VER.gz"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-armv8-$GOST_VER.gz"
else
    echo -e "${RED}不支持的架构: $ARCH${NC}" && exit 1
fi

wget -qO- $URL | gzip -d > /usr/local/bin/gost
chmod +x /usr/local/bin/gost

# 3. 智能处理 53 端口占用
echo -e "${GREEN}正在检查 53 端口...${NC}"
# 仅当 systemd-resolved 存在时才操作
if systemctl list-unit-files | grep -q systemd-resolved; then
    echo "检测到 systemd-resolved，正在关闭..."
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi

# 如果还是被其他进程占用（比如原有的 dnsmasq），直接提示
OCCUPIED_BY=$(lsof -i :53 -sTCP:LISTEN -t)
if [ ! -z "$OCCUPIED_BY" ]; then
    echo -e "${RED}警告: 53 端口仍被 PID $OCCUPIED_BY 占用，请手动检查！${NC}"
fi

# 4. 写入并启动服务
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

systemctl daemon-reload
systemctl enable gost-dns
systemctl restart gost-dns

# 5. 完成提示
SERVER_IP=$(curl -s ipv4.icanhazip.com)
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "部署成功！"
echo -e "解锁机 DNS: ${RED}${SERVER_IP}${NC}"
echo -e "状态检查: ${GREEN}$(systemctl is-active gost-dns)${NC}"
echo -e "请务必在安全组开启 ${RED}UDP 53${NC} 端口！"
echo -e "${GREEN}------------------------------------------------${NC}"
