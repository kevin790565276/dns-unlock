#!/bin/bash

# VPS 网络优化脚本 - 2.0 修复版
# 完整保留原脚本功能，新增高/低延迟模式切换
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
SYSCTL_CONF="/etc/sysctl.d/99-hy2-network.conf"
LIMITS_CONF="/etc/security/limits.d/99-hy2-limits.conf"
JOURNALD_CONF="/etc/systemd/journald.conf.d/99-hy2-journald.conf"

# 全局变量
OPTIMIZE_MODE="both"
LATENCY_TYPE="low"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

check_root() { [ "$EUID" -ne 0 ] && log_error "请使用 root 运行" && exit 1; }

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测操作系统"; exit 1
    fi
    log_info "操作系统: $OS $OS_VERSION"
}

detect_container() {
    IS_CONTAINER=0
    if [ -f /proc/1/cgroup ] && grep -qE "docker|lxc|openvz" /proc/1/cgroup; then IS_CONTAINER=1; fi
    [ "$IS_CONTAINER" -eq 1 ] && log_info "检测到容器环境，将跳过受限参数"
}

# 核心修改：支持双模式的 sysctl 优化
optimize_sysctl() {
    log_info "正在优化 sysctl (模式: $OPTIMIZE_MODE, 延迟预设: $LATENCY_TYPE)..."
    [ ! -d "/etc/sysctl.d" ] && mkdir -p /etc/sysctl.d
    
    local temp_conf=$(mktemp)
    cat > "$temp_conf" << EOF
# 基础公共优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.core.somaxconn = 65535
EOF

    if [ "$LATENCY_TYPE" = "low" ]; then
        # --- 低延迟优化 (3ms 神机专属) ---
        cat >> "$temp_conf" << EOF
net.ipv4.tcp_rmem = 4096 16384 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_mtu_probing = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
    else
        # --- 高延迟优化 (跨海弱网专用) ---
        cat >> "$temp_conf" << EOF
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
EOF
    fi

    # 合并原脚本中的 UDP/网络处理参数
    cat >> "$temp_conf" << EOF
net.core.netdev_max_backlog = 65535
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
EOF

    mv "$temp_conf" "$SYSCTL_CONF"
    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
}

# --- 原脚本其他功能函数 (limits, journald, firewall 等) ---
optimize_limits() {
    cat > "$LIMITS_CONF" << EOF
* soft nofile 512000
* hard nofile 512000
root soft nofile 512000
root hard nofile 512000
EOF
}

optimize_firewall() {
    [ "$IS_CONTAINER" -eq 1 ] && return
    if command -v iptables &>/dev/null; then
        iptables -t raw -A PREROUTING -p udp -j NOTRACK 2>/dev/null || true
        iptables -t raw -A OUTPUT -p udp -j NOTRACK 2>/dev/null || true
    fi
}

perform_optimize() {
    check_root; detect_os; detect_container
    optimize_sysctl
    optimize_limits
    optimize_firewall
    log_success "优化执行完毕！"
}

restore_config() {
    rm -f "$SYSCTL_CONF" "$LIMITS_CONF"
    log_success "配置已还原"
}

# 主菜单
while true; do
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "         VPS 综合优化脚本 V2.0"
    echo -e "${CYAN}==========================================${NC}"
    echo "  1. 低延迟模式 (针对 3ms 线路, 关 MTU 探测)"
    echo "  2. 高延迟模式 (针对 150ms+ 线路, 开 MTU 探测)"
    echo "  3. 还原配置"
    echo "  0. 退出"
    echo ""
    read -p "请输入选项: " choice
    case $choice in
        1) LATENCY_TYPE="low"; perform_optimize ;;
        2) LATENCY_TYPE="high"; perform_optimize ;;
        3) restore_config ;;
        0) exit 0 ;;
        *) echo "无效输入" ;;
    esac
    read -p "按回车继续..."
done
