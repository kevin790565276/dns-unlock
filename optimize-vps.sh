#!/bin/bash
# VPS 极致优化脚本 V2.1 - 修复 5s 延迟问题
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
SYSCTL_CONF="/etc/sysctl.d/99-network-opt.conf"
LIMITS_CONF="/etc/security/limits.d/99-network-limits.conf"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_done() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

apply_optimization() {
    local mode=$1
    log_info "正在清理旧配置..."
    rm -f "$SYSCTL_CONF"
    
    log_info "正在注入 $mode 模式内核参数..."
    cat > "$SYSCTL_CONF" << EOF
# 基础公共优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.core.somaxconn = 65535
net.ipv4.tcp_syncookies = 1
EOF

    if [ "$mode" = "LOW_LATENCY" ]; then
        # 3ms 线路：关闭 MTU 探测，使用小缓冲区防止 Bufferbloat
        cat >> "$SYSCTL_CONF" << EOF
net.ipv4.tcp_rmem = 4096 16384 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.ipv4.tcp_mtu_probing = 0
net.core.rmem_max = 4194304
net.core.wmem_max = 4194304
EOF
    else
        # 跨海线路：开启 MTU 探测，使用大缓冲区
        cat >> "$SYSCTL_CONF" << EOF
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
EOF
    fi

    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    
    # 优化系统限制
    cat > "$LIMITS_CONF" << EOF
* soft nofile 512000
* hard nofile 512000
EOF
    log_done "优化成功！模式: $mode"
}

while true; do
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "         VPS 极致优化交互脚本 V2.1"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "  1. 低延迟模式 (适合 3ms 线路, 解决 5s 延迟问题)"
    echo -e "  2. 高延迟模式 (适合 跨海线路)"
    echo -e "  3. 还原配置 (返回默认状态)"
    echo -e "  0. 退出"
    echo ""
    read -p "请输入选项: " choice
    case $choice in
        1) apply_optimization "LOW_LATENCY" ;;
        2) apply_optimization "HIGH_LATENCY" ;;
        3) rm -f "$SYSCTL_CONF" "$LIMITS_CONF" && sysctl --system && log_done "已还原" ;;
        0) exit 0 ;;
    esac
    read -p "执行完毕，按回车返回菜单..."
done
