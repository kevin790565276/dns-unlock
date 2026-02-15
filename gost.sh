#!/bin/bash

# 1. 彻底暴力清理 (防止端口冲突)
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null
pkill -9 gost 2>/dev/null
pkill -9 dnsmasq 2>/dev/null

# 2. 暴力开放防火墙
iptables -F
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p tcp --dport 53 -j ACCEPT
ip6tables -F 2>/dev/null
ip6tables -I INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null

# 3. 安装 Gost (如果不存在)
if [ ! -f "/usr/local/bin/gost" ]; then
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz"
    else
        URL="https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-armv8-2.11.5.gz"
    fi
    wget -qO- $URL | gzip -d > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# 4. 核心：创建 Systemd 服务并强制监听所有 IP (0.0.0.0 和 [::])
cat << EOF > /etc/systemd/system/gost-dns.service
[Unit]
Description=Gost DNS Service
After=network.target

[Service]
Type=simple
# 同时监听 IPv4 和 IPv6 的 53 端口，透传给香港阿里云 DNS
ExecStart=/usr/local/bin/gost -L udp://:53/223.5.5.5:53 -L tcp://:53/223.5.5.5:53
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 5. 重启并检查
systemctl daemon-reload
systemctl enable gost-dns
systemctl restart gost-dns

echo "部署完成！"
echo "请执行: systemctl status gost-dns 确保它是 active (running)"
