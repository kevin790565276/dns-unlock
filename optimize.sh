#!/bin/bash

# ====================================================
# Project: Global VPS Optimizer (Custom for High Latency)
# Usage: curl -sL https://raw.githubusercontent.com/你的用户名/仓库名/main/opt.sh | sudo bash
# ====================================================

# 检查 Root 权限
[[ $EUID -ne 0 ]] && echo "错误：请使用 root 用户运行此脚本！" && exit 1

echo "开始执行全球节点网络深度优化..."

# 1. 备份 sysctl
[[ -f /etc/sysctl.conf ]] && cp /etc/sysctl.conf /etc/sysctl.conf.bak

# 2. 注入深度优化参数 (针对 Hy2, TCP BBR, 高延迟绕路)
cat > /etc/sysctl.conf << EOF
# IPv6 支持
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# BBR 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 缓冲区极致优化 (针对 200ms+ 延迟，解决长肥网络瓶颈)
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400

# 高并发与连接队列优化
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_max_tw_buckets = 10000
net.ipv4.ip_local_port_range = 1024 65535

# 跨国链路保活与握手优化
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_fastopen = 3

# 网络效率提升
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1

# 网卡处理预算
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000
net.ipv4.ping_group_range = 0 2147483647
EOF

# 3. 应用配置
sysctl -p && sysctl --system

# 4. 修复 Debian/Ubuntu 源并安装 haveged (补充熵池)
if [ -f /usr/bin/apt ]; then
    echo "检测到 Debian/Ubuntu 系统，正在修复源并安装 haveged..."
    sed -i '/backports/s/^/#/' /etc/apt/sources.list
    apt-get update -o Acquire::Languages=none
    apt-get install -y haveged
    systemctl enable --now haveged
elif [ -f /usr/bin/yum ]; then
    echo "检测到 CentOS/RHEL 系统..."
    yum install -y epel-release && yum install -y haveged
    systemctl enable --now haveged
fi

echo "------------------------------------------------"
echo "✅ 优化已完成！"
echo "当前算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "当前队列: $(sysctl -n net.core.default_qdisc)"
echo "最大缓冲区: $(sysctl -n net.core.rmem_max) 字节"
echo "------------------------------------------------"
