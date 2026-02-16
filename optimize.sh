#!/bin/bash

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以 root 权限运行！"
   exit 1
fi

echo "================================================="
echo "  ⚡ 全球 VPS 网络深度优化脚本 (增强版) "
echo "================================================="
echo "请选择您的线路类型："
echo "1) 全球/美国/长距离绕路 (64M 缓冲区 - 延迟 >150ms)"
echo "2) 港日/近距离/直连线路 (32M 缓冲区 - 延迟 <100ms)"
echo "-------------------------------------------------"

# 关键修复：添加 < /dev/tty 确保在管道模式下也能接收键盘输入
read -p "请输入选项 [1-2, 默认1]: " choice < /dev/tty

# 设置缓冲区大小
if [ "$choice" == "2" ]; then
    BUF_SIZE=33554432
    MODE_NAME="港日/近距离线路 (32MB)"
else
    BUF_SIZE=67108864
    MODE_NAME="全球/长距离线路 (64MB)"
fi

echo "-------------------------------------------------"
echo "正在为您执行 $MODE_NAME 优化方案..."

# 写入内核参数
cat > /etc/sysctl.conf << EOF
# 基础网络转发
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0

# 拥塞控制与队列调度
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 关键缓冲区优化 (根据选择动态调整)
net.core.rmem_max = $BUF_SIZE
net.core.wmem_max = $BUF_SIZE
net.ipv4.tcp_rmem = 4096 87380 $BUF_SIZE
net.ipv4.tcp_wmem = 4096 65536 $BUF_SIZE
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400

# 并发与稳定性优化
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_max_tw_buckets = 10000
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000
net.ipv4.ping_group_range = 0 2147483647
EOF

# 使配置生效
sysctl -p

# 安装 haveged 增强系统熵值
if [ -f /usr/bin/apt ]; then
    apt update && apt install -y haveged
elif [ -f /usr/bin/yum ]; then
    yum install -y haveged
fi
systemctl enable haveged && systemctl start haveged

echo "-------------------------------------------------"
echo "✅ 优化已完成！"
echo "当前线路模式: $MODE_NAME"
echo "-------------------------------------------------"
