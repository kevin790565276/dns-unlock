#!/bin/bash

# 检查 root
[[ $EUID -ne 0 ]] && echo "请用 root 运行" && exit 1

clear
echo "=================================="
echo "  ⚡ 全球 VPS 优化脚本 (完整版) "
echo "=================================="
echo "1) 全球/美国/长线 (64M 缓冲区)"
echo "2) 港日/近距离/直连 (32M 缓冲区)"
read -p "请选择 [1-2, 默认1]: " choice

[[ "$choice" == "2" ]] && BUF=33554432 || BUF=67108864

echo "正在应用优化 (缓冲区: $BUF)..."

# 写入内核参数
cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = $BUF
net.core.wmem_max = $BUF
net.ipv4.tcp_rmem = 4096 87380 $BUF
net.ipv4.tcp_wmem = 4096 65536 $BUF
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

sysctl -p

# 安装 haveged (静默安装)
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq haveged >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q haveged >/dev/null 2>&1
fi
systemctl enable haveged >/dev/null 2>&1 && systemctl start haveged >/dev/null 2>&1

echo "----------------------------------"
echo "✅ 优化完成！"
rm -f optimize.sh
