#!/bin/bash

# ====================================================
# 项目：流媒体 DNS 解锁 (落地机极致稳固版)
# 特点：彻底禁用系统解析器，防止端口回抢
# ====================================================

echo "正在以极致模式部署落地机解锁环境..."

# 1. 彻底禁用 systemd-resolved (Racknerd 端口超时的头号元凶)
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null
# 强制解除软链接，防止系统自动恢复 resolv.conf
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 2. 暴力清理所有相关进程
pkill -9 gost 2>/dev/null
pkill -9 dnsmasq 2>/dev/null

# 3. 极致开放防火墙 (确保 UDP 53 绝对畅通)
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables -t nat -F
# 针对某些母机防火墙，明确放行 53
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p tcp --dport 53 -j ACCEPT

# 4. 自动下载 Gost (如果不存在)
if [ ! -f "/usr/local/bin/gost" ]; then
    ARCH=$(uname -m)
    [ "$ARCH" == "x86_64" ] && URL="https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz" || URL="https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-armv8-2.11.5.gz"
    wget -qO- $URL | gzip -d > /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
fi

# 5. 暴力后台启动 (手动执行能通的关键就是这行)
# 使用 0.0.0.0 锁定 IPv4，避免中转机通过 IPv6 连接导致超时
nohup /usr/local/bin/gost -L udp://0.0.0.0:53/223.5.5.5:53 -L tcp://0.0.0.0:53/223.5.5.5:53 > /dev/null 2>&1 &

echo "------------------------------------------------"
echo "落地机部署完成！"
echo "请执行以下命令检查，必须看到 gost 占用 0.0.0.0:53 ："
netstat -tunlp | grep :53
echo "------------------------------------------------"
