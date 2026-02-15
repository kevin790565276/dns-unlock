#!/bin/bash

# 1. 彻底清场，释放 53 端口
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null
pkill -9 gost 2>/dev/null

# 2. 暴力重置防火墙（解决 Timeout 关键）
iptables -F
iptables -P INPUT ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p tcp --dport 53 -j ACCEPT

# 3. 安装 Gost
if [ ! -f "/usr/local/bin/gost" ]; then
    wget -qO- https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz | gzip -d > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# 4. 【核心】创建系统服务，确保解锁进程永不被杀
cat << EOF > /etc/systemd/system/gost-dns.service
[Unit]
Description=Gost DNS Unlock Service
After=network.target

[Service]
Type=simple
# 监听 IPv4 的 53 端口，转发给香港阿里云 DNS
ExecStart=/usr/local/bin/gost -L udp://0.0.0.0:53/223.5.5.5:53 -L tcp://0.0.0.0:53/223.5.5.5:53
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 5. 启动并激活
systemctl daemon-reload
systemctl enable gost-dns
systemctl restart gost-dns

echo "------------------------------------------------"
echo "部署完成！"
echo "服务状态 (必须看到 active):"
systemctl status gost-dns --no-pager | grep "Active:"
echo "------------------------------------------------"
