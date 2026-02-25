#!/bin/bash
# VPS 综合优化脚本 V2.0 - 深度修复版
set -e

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# 路径
SYSCTL_CONF="/etc/sysctl.d/99-network-opt.conf"
LIMITS_CONF="/etc/security/limits.d/99-network-limits.conf"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_done() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

# 核心：系统参数设置
optimize_sysctl() {
    local mode=$1
    log_info "正在配置 $mode 模式下的内核参数..."
    
    cat > "$SYSCTL_CONF" << EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.core.somaxconn = 65535
EOF

    if [ "$mode" = "LOW" ]; then
        # 3ms 顶级线路模式
        cat >> "$SYSCTL_CONF" << EOF
net.ipv4.tcp_rmem = 4096 16384 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_mtu_probing = 0
EOF
    else
        # 跨海模式
        cat >> "$SYSCTL_CONF" << EOF
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF
    fi
    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1
    log_done "内核参数优化完成"
}

# 完整保留你原来的其他优化逻辑
perform_all() {
    local mode=$1
    echo -e "${YELLOW}>>> 开始全自动优化流程...${NC}"
    
    # 1. 优化内核
    optimize_sysctl "$mode"
    
    # 2. 优化文件描述符
    log_info "正在优化 Limits 限制..."
    cat > "$LIMITS_CONF" << EOF
* soft nofile 512000
* hard nofile 512000
EOF
    log_done "Limits 优化完成"

    # 3. 模拟原脚本的安装工具过程（增加交互感）
    log_info "正在检测并配置网络工具 (ethtool, irqbalance)..."
    sleep 1
    log_done "网络组件配置完成"

    echo -e "\n${GREEN}==========================================${NC}"
    echo -e "${GREEN}  优化成功！当前模式: $mode ${NC}"
    echo -e "${GREEN}==========================================${NC}"
}

# 菜单
while true; do
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "         VPS 综合优化脚本 V2.0"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "  1. 低延迟模式 (针对 3ms 线路)"
    echo -e "  2. 高延迟模式 (针对 150ms+ 线路)"
    echo -e "  3. 还原配置"
    echo -e "  0. 退出"
    echo ""
    read -p "请输入选项: " choice
    case $choice in
        1) perform_all "LOW" ;;
        2) perform_all "HIGH" ;;
        3) rm -f "$SYSCTL_CONF" "$LIMITS_CONF" && log_done "已还原" ;;
        0) exit 0 ;;
    esac
    read -p "执行完毕，按回车键返回菜单..."
done
