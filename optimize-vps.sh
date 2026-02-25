#!/bin/bash
# VPS Network Optimizer v2.1 (Pure Edition)
set -e

# 颜色
C_RED='\033[0;31m'
C_GRN='\033[0;32m'
C_YLW='\033[1;33m'
C_CYN='\033[0;36m'
C_NC='\033[0m'

# 路径
SYSCTL_CONF="/etc/sysctl.d/99-network.conf"

log_info() { echo -e "${C_GRN}[INFO]${C_NC} $1"; }
log_done() { echo -e "${C_CYN}[SUCCESS]${C_NC} $1"; }

# 核心优化函数
apply_opt() {
    local mode=$1
    log_info "正在配置 $mode 模式..."
    
    # 基础公共参数
    cat > "$SYSCTL_CONF" << EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.core.somaxconn = 8192
EOF

    if [ "$mode" = "LOW" ]; then
        # 低延迟 (3ms 专用)
        cat >> "$SYSCTL_CONF" << EOF
net.ipv4.tcp_rmem = 4096 16384 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_mtu_probing = 0
EOF
    else
        # 高延迟 (跨海)
        cat >> "$SYSCTL_CONF" << EOF
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF
    fi

    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
    log_done "$mode 模式已生效"
}

# 菜单
while true; do
    clear
    echo -e "${C_CYN}=== VPS 线路优化助手 ===${C_NC}"
    echo "1. 低延迟模式 (针对 3ms 直连/BGP)"
    echo "2. 高延迟模式 (针对 150ms+ 跨海)"
    echo "3. 还原配置"
    echo "0. 退出"
    read -p "请输入 [0-3]: " opt
    case $opt in
        1) apply_opt "LOW" ;;
        2) apply_opt "HIGH" ;;
        3) rm -f "$SYSCTL_CONF" && sysctl --system ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
    read -p "处理完成，按回车键继续..."
done
