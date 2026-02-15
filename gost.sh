#!/bin/bash

# 1. 暴力清理（只杀冲突，不废话）
pkill -9 gost 2>/dev/null
pkill -9 dnsmasq 2>/dev/null
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

# 2. 彻底放开防火墙（针对 Timeout）
iptables -F
iptables -P INPUT ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT

# 3. 极速下载
if [ ! -f "/usr/local/bin/gost" ]; then
    wget -qO- https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz | gzip -d > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# 4. 【关键】完全模拟你手动的操作
# 我们不依赖脚本运行，我们直接把命令塞进系统的 rc.local 或者直接运行
# 这里强制绑定 IPv4 0.0.0.0 防止 IPv6 干扰
nohup /usr/local/bin/gost -L udp://0.0.0.0:53/223.5.5.5:53 -L tcp://0.0.0.0:53/223.5.5.5:53 > /dev/null 2>&1 &

# 5. 打印结果
sleep 1
echo "------------------------------------------------"
netstat -tunlp | grep :53
echo "只要上面显示了 gost，中转机就一定能通了！"
echo "------------------------------------------------"
