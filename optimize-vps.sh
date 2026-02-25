#!/bin/bash

# VPS 网络优化脚本 - 智能识别线路环境
# 版本: 2.0.0 (支持低延迟/高延迟双模)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置文件路径
SYSCTL_CONF="/etc/sysctl.d/99-network-opt.conf"
LIMITS_CONF="/etc/security/limits.d/99-network-limits.conf"

# 默认全局变量
OPTIMIZE_MODE="both"
LATENCY_TARGET="low"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

check_root() { [ "$EUID" -ne 0 ] && log_error "请使用 root 运行" && exit 1; }

detect_os() {
    if [ -f /etc/os-release ]; then . /etc/os-release; OS=$ID; else exit 1; fi
}

detect_container() {
    IS_CONTAINER=0
    if [ -f /proc/1/cgroup ] && grep -qE "docker|lxc|openvz" /proc/1/cgroup; then IS_CONTAINER=1; fi
}

optimize_sysctl() {
    log_info "正在执行 [${LATENCY_TARGET^^} 模式] 优化..."
    
    local temp_conf=$(mktemp)
    
    # 基础公共优化
    cat > "$temp_conf" << EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.core.somaxconn = 8192
EOF

    if [ "$LATENCY_TARGET" = "low" ]; then
        # --- 低延迟模式参数 (针对 3ms 顶级线路) ---
        cat >> "$temp_conf" << EOF
net.ipv4.tcp_rmem = 4096 16384 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_mtu_probing = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_budget = 1000
EOF
    else
        # --- 高延迟模式参数 (针对 150ms+ 跨海线路) ---
        cat >> "$temp_conf" << EOF
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_budget = 600
EOF
    fi

    mv "$temp_conf" "$SYSCTL_CONF"
    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
    log_success "sysctl 优化完成"
}

# 快捷函数：还原配置
restore_config() {
    rm -f "$SYSCTL_CONF" "$LIMITS_CONF"
    log_success "配置已还原，建议重启"
}

show_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "         VPS 网络优化脚本 V2.0"
    echo -e "      (当前线路建议: 3ms选低延迟)"
    echo -e "${CYAN}==========================================${NC}"
    echo "  1. 优化网络 (低延迟模式 - 适合直连/香港BGP)"
    echo "  2. 优化网络 (高延迟模式 - 适合跨海/弱网)"
    echo "  3. 还原配置"
    echo "  0. 退出"
    echo -ne "\n${YELLOW}请输入选项: ${NC}"
}

main() {
    check_root
    detect_os
    detect_container
    
    show_menu
    read -r choice
    case $choice in
        1) LATENCY_TARGET="low"; optimize_sysctl; ;;
        2) LATENCY_TARGET="high"; optimize_sysctl; ;;
        3) restore_config; ;;
        0) exit 0; ;;
        *) log_error "无效选项"; sleep 1; main; ;;
    esac
}

main "$@"
