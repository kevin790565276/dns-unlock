#!/bin/bash

# ====================================================
# 项目：流媒体 DNS 解锁 (落地机专用 - 香港优化版)
# 逻辑：UDP 透传模式 (仿 akdns)，彻底绕过本地 Hosts 干扰
# ====================================================

# 1. 权限检查
if [[ $EUID -ne 0 ]]; then
   echo "错误：请使用 root 权限运行此脚本"
   exit 1
fi

echo "开始部署香港解锁服务..."

# 2. 彻底释放 53 端口 (清理所有可能冲突的服务)
echo "正在清理 53 端口占用..."
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null
systemctl stop dnsmasq 2>/dev/null
pkill -9 gost 2>/dev/null
pkill -9 dnsmasq 2>/dev/null

# 3. 强制重置防火墙规则 (解决 Timeout 关键)
echo "正在重置防火墙..."
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables -t nat -F
ip6tables -F 2>/dev/null

# 4. 自动下载并安装 Gost
if [ ! -f "/usr/local/bin/gost" ]; then
    echo "正在下载 Gost..."
    ARCH=$(uname -m)
    GOST_VER="2.11.5"
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-amd64-$GOST_VER.gz"
    elif [[ "$ARCH" == "aarch64" ]]; then
        URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-armv8-$GOST_VER.gz"
    else
        echo "不支持的架构: $ARCH"; exit 1
    fi
    wget -qO- $URL | gzip -d > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# 5. 配置 Systemd 服务 (核心：香港本地 DNS 转发)
# 使用 223.5.5.5 (阿里云香港) 确保 Netflix 解析结果定位到香港区域
echo "配置 Systemd 服务 (UDP 透传模式)..."
cat << EOF > /etc/systemd/system/gost-dns.service
[Unit]
Description=Gost DNS HK Unlock Service
After=network.target

[Service]
Type=simple
# 核心逻辑：监听所有接口的 53 端口，直接转发给香港上游，不读取本地 hosts
ExecStart=/usr/local/bin/gost -L udp://:53/223.5.5.5:53
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动并激活
systemctl daemon-reload
systemctl enable gost-dns
systemctl restart gost-dns

echo "------------------------------------------------"
echo "部署成功！"
echo "服务状态：$(systemctl is-active gost-dns)"
echo "当前落地机 IP: $(curl -s ifconfig.me)"
echo "请在中转机运行：nslookup netflix.com $(curl -s ifconfig.me)"
echo "------------------------------------------------"
