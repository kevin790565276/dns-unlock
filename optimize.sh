#!/bin/bash

# VPS 网络优化脚本 - 针对 Hysteria 2 (hy2) 优化
# 适用于 GitHub 部署
# 版本: 1.2.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 配置文件路径
SYSCTL_CONF="/etc/sysctl.d/99-hy2-network.conf"
LIMITS_CONF="/etc/security/limits.d/99-hy2-limits.conf"
JOURNALD_CONF="/etc/systemd/journald.conf.d/99-hy2-journald.conf"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    log_info "检测到操作系统: $OS $OS_VERSION"
}

# 备份配置文件
backup_config() {
    local file=$1
    if [ -f "$file" ]; then
        local backup_file="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup_file"
        log_info "已备份 $file -> $backup_file"
    fi
}

# 优化 sysctl 配置
optimize_sysctl() {
    log_info "正在优化 sysctl 配置..."
    
    if [ -f "$SYSCTL_CONF" ]; then
        backup_config "$SYSCTL_CONF"
    fi
    
    cat > "$SYSCTL_CONF" << 'EOF'
# 针对 Hysteria 2 的网络优化配置
# BBR 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 提升网络缓冲区
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.optmem_max = 65536
net.core.somaxconn = 65535

# TCP 优化
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_tw_buckets = 2000000

# UDP 优化（Hysteria 2 使用 UDP）
net.core.netdev_max_backlog = 65535
net.core.rps_sock_flow_entries = 32768
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.udp_mem = 65536 131072 262144

# 其他优化
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    sysctl -p "$SYSCTL_CONF"
    log_success "sysctl 配置优化完成"
}

# 优化 limits 配置
optimize_limits() {
    log_info "正在优化 limits 配置..."
    
    if [ -f "$LIMITS_CONF" ]; then
        backup_config "$LIMITS_CONF"
    fi
    
    cat > "$LIMITS_CONF" << 'EOF'
* soft nofile 512000
* hard nofile 512000
root soft nofile 512000
root hard nofile 512000
* soft nproc 512000
* hard nproc 512000
root soft nproc 512000
root hard nproc 512000
EOF
    
    log_success "limits 配置优化完成"
}

# 优化系统 journald
optimize_journald() {
    log_info "正在优化 journald 配置..."
    
    if [ -d /etc/systemd/journald.conf.d ]; then
        if [ -f "$JOURNALD_CONF" ]; then
            backup_config "$JOURNALD_CONF"
        fi
        
        cat > "$JOURNALD_CONF" << 'EOF'
[Journal]
Storage=persistent
SystemMaxUse=2G
SystemMaxFileSize=200M
MaxRetentionSec=1month
EOF
        log_success "journald 配置优化完成"
    fi
}

# 优化 irqbalance
optimize_irqbalance() {
    log_info "正在优化 irqbalance..."
    
    if command -v irqbalance &> /dev/null; then
        if systemctl is-active --quiet irqbalance; then
            log_info "irqbalance 已在运行"
        else
            systemctl enable --now irqbalance
            log_success "irqbalance 已启用"
        fi
    fi
}

# 检查并启用 BBR
enable_bbr() {
    log_info "正在检查 BBR 状态..."
    
    if modprobe tcp_bbr 2>/dev/null; then
        if lsmod | grep -q bbr; then
            log_success "BBR 已加载"
        else
            log_warn "BBR 未加载，尝试加载..."
            modprobe tcp_bbr
            log_success "BBR 已加载"
        fi
    else
        log_warn "系统可能不支持 BBR，继续执行其他优化"
    fi
}

# 安装必要工具
install_tools() {
    log_info "正在安装必要的网络工具..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y iptables-persistent net-tools dnsutils ethtool irqbalance
            ;;
        centos|rhel|fedora)
            yum install -y iptables-services net-tools bind-utils ethtool irqbalance
            ;;
        *)
            log_warn "不支持的操作系统，跳过工具安装"
            ;;
    esac
    
    log_success "网络工具安装完成"
}

# 优化防火墙规则
optimize_firewall() {
    log_info "正在优化防火墙规则..."
    
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    iptables -t raw -A PREROUTING -p udp -j NOTRACK
    iptables -t raw -A OUTPUT -p udp -j NOTRACK
    
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif command -v service &> /dev/null; then
        service iptables save
    fi
    
    log_success "防火墙规则优化完成"
}

# 禁用不必要的服务
disable_unnecessary_services() {
    log_info "正在禁用不必要的服务..."
    
    local services=("apparmor" "ufw" "firewalld" "apache2" "httpd" "named" "sendmail")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service"
            systemctl disable "$service"
            log_info "已禁用服务: $service"
        fi
    done
    
    log_success "不必要的服务已禁用"
}

# 执行优化
perform_optimize() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║              开始执行网络优化                   ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    detect_os
    enable_bbr
    optimize_sysctl
    optimize_limits
    optimize_journald
    optimize_irqbalance
    install_tools
    optimize_firewall
    disable_unnecessary_services
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   VPS 网络优化完成 - 针对 Hysteria 2${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}已完成的优化:${NC}"
    echo "  ✅ sysctl 网络参数优化"
    echo "  ✅ 文件描述符限制优化"
    echo "  ✅ BBR 拥塞控制"
    echo "  ✅ 防火墙规则优化"
    echo "  ✅ 系统日志优化"
    echo "  ✅ 中断平衡优化"
    echo "  ✅ 禁用不必要的服务"
    echo ""
    echo -e "${YELLOW}建议:${NC}"
    echo "  1. 重启系统以应用所有优化"
    echo "  2. 重启后运行: sysctl net.ipv4.tcp_congestion_control"
    echo "  3. 确保输出为 'bbr'"
    echo ""
}

# 还原配置
restore_config() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║              开始还原配置                       ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    detect_os
    
    log_info "正在还原配置..."
    
    # 删除我们创建的配置文件
    if [ -f "$SYSCTL_CONF" ]; then
        rm -f "$SYSCTL_CONF"
        log_info "已删除 $SYSCTL_CONF"
    fi
    
    if [ -f "$LIMITS_CONF" ]; then
        rm -f "$LIMITS_CONF"
        log_info "已删除 $LIMITS_CONF"
    fi
    
    if [ -f "$JOURNALD_CONF" ]; then
        rm -f "$JOURNALD_CONF"
        log_info "已删除 $JOURNALD_CONF"
    fi
    
    # 重新加载 sysctl
    if [ -f /etc/sysctl.conf ]; then
        sysctl -p /etc/sysctl.conf
    fi
    
    log_success "配置还原完成，建议重启系统"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║    VPS 网络优化脚本 - Hysteria 2 专用版       ║"
    echo "║                  版本 1.2.0                     ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}请选择操作:${NC}"
    echo ""
    echo "  1. 优化网络"
    echo "  2. 还原配置"
    echo "  0. 退出脚本"
    echo ""
    echo -ne "${YELLOW}请输入选项 [0-2]: ${NC}"
}

# 主函数
main() {
    # 检查是否有命令行参数
    if [ $# -gt 0 ]; then
        case "${1:-}" in
            --restore)
                check_root
                detect_os
                restore_config
                exit 0
                ;;
            --optimize)
                perform_optimize
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    fi
    
    # 交互式菜单模式
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                perform_optimize
                echo ""
                read -n 1 -s -p "按任意键返回菜单..."
                ;;
            2)
                restore_config
                echo ""
                read -n 1 -s -p "按任意键返回菜单..."
                ;;
            0)
                echo ""
                log_info "退出脚本"
                exit 0
                ;;
            *)
                echo ""
                log_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 显示帮助
show_help() {
    echo "VPS 网络优化脚本 - Hysteria 2 专用版"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --optimize    直接执行优化"
    echo "  --restore     直接还原配置"
    echo "  --help        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0              # 进入交互式菜单"
    echo "  $0 --optimize   # 直接执行优化"
    echo "  $0 --restore    # 直接还原配置"
    echo ""
}

# 运行主函数
main "$@"
