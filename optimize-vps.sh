#!/bin/bash

# VPS 网络优化脚本 - 2.0 完整版
# 支持: TCP (xhttp/v2ray) & UDP (Hy2)
# 分类: 低延迟模式 (Low Latency) & 高延迟模式 (High Latency)

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SYSCTL_CONF="/etc/sysctl.d/99-hy2-network.conf"
LIMITS_CONF="/etc/security/limits.d/99-hy2-limits.conf"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_success() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

check_root() { [ "$EUID" -ne 0 ] && echo "请用root运行" && exit 1; }

# 核心优化参数配置
optimize_sysctl() {
    local mode=$1
    log_info "正在配置 $mode 模式参数..."
    
    local temp_conf=$(mktemp)
    cat > "$temp_conf" << EOF
# 基础公共参数
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_syncookies = 1
net.core.somaxconn = 65535
EOF

    if [ "$mode" = "LOW" ]; then
        # --- 低延迟模式 (适合 3ms 线路) ---
        cat >> "$temp_conf" << EOF
net.ipv4.tcp_rmem = 4096 16384 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_mtu_probing = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
    else
        # --- 高延迟模式 (适合跨海/弱网) ---
        cat >> "$temp_conf" << EOF
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
EOF
    fi

    mv "$temp_conf" "$SYSCTL_CONF"
    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
    log_success "$mode 模式优化应用成功！"
}

restore_config() {
    rm -f "$SYSCTL_CONF" "$LIMITS_CONF"
    log_success "配置已还原，建议重启系统。"
}

show_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "         VPS 网络优化脚本 V2.0"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "  ${GREEN}1.${NC} 低延迟模式 (适合香港/直连/3ms线路)"
    echo -e "  ${YELLOW}2.${NC} 高延迟模式 (适合美国/跨海/弱网)"
    echo -e "  ${RED}3.${NC} 还原所有配置"
    echo -e "  ${WHITE}0.${NC} 退出"
    echo -ne "\n请选择 [0-3]: "
}

# 主循环
main() {
    check_root
    while true; do
        show_menu
        read -r choice
        case $choice in
            1) optimize_sysctl "LOW" ; read -n1 -p "按任意键返回..." ;;
            2) optimize_sysctl "HIGH" ; read -n1 -p "按任意键返回..." ;;
            3) restore_config ; read -n1 -p "按任意键返回..." ;;
            0) exit 0 ;;
            *) echo -e "${RED}输入错误${NC}" ; sleep 1 ;;
        esac
    done
}

main "$@"
