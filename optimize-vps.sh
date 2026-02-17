#!/bin/bash

# VPS 网络优化脚本 - 支持 TCP (xhttp, v2ray) 和 UDP (Hysteria 2)
# 适用于 GitHub 部署，支持 NAT 小鸡和受限环境
# 版本: 2.0

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

# 优化模式
OPTIMIZE_MODE="both"

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
        OS_CODENAME=${VERSION_CODENAME:-}
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    log_info "检测到操作系统: $OS $OS_VERSION ${OS_CODENAME:+($OS_CODENAME)}"
}

# 检测是否为容器环境
detect_container() {
    IS_CONTAINER=0
    if [ -f /proc/1/cgroup ]; then
        if grep -qE "docker|lxc|openvz|container" /proc/1/cgroup; then
            IS_CONTAINER=1
        fi
    fi
    if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
        IS_CONTAINER=1
    fi
    if [ "$IS_CONTAINER" -eq 1 ]; then
        log_info "检测到容器环境 (NAT小鸡/OpenVZ/LXC)，将跳过受限参数"
    fi
}

# 检查 BBR 支持
check_bbr_support() {
    log_info "检查 BBR 支持..."
    
    # 检查可用的拥塞控制算法
    local available=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | cut -d'=' -f2 | xargs)
    log_info "可用的拥塞控制: $available"
    
    # 检查当前的拥塞控制
    local current=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d'=' -f2 | xargs)
    log_info "当前的拥塞控制: $current"
    
    if echo "$available" | grep -q bbr; then
        log_success "系统支持 BBR"
        return 0
    else
        log_warn "系统不支持 BBR"
        return 1
    fi
}

# 强制启用 BBR
force_enable_bbr() {
    log_info "正在强制启用 BBR..."
    
    # 尝试加载 BBR 模块
    modprobe tcp_bbr 2>/dev/null || true
    
    # 尝试直接设置 sysctl 参数
    log_info "设置: net.core.default_qdisc=fq"
    sysctl -w net.core.default_qdisc=fq 2>/dev/null || log_warn "无法设置 net.core.default_qdisc"
    
    log_info "设置: net.ipv4.tcp_congestion_control=bbr"
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || log_warn "无法设置 net.ipv4.tcp_congestion_control"
    
    # 添加到 /etc/sysctl.conf 确保重启后生效
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        log_info "已添加到 /etc/sysctl.conf: net.core.default_qdisc=fq"
    fi
    
    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        log_info "已添加到 /etc/sysctl.conf: net.ipv4.tcp_congestion_control=bbr"
    fi
    
    # 检查是否生效
    local current=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d'=' -f2 | xargs)
    if [ "$current" = "bbr" ]; then
        log_success "BBR 已成功启用！"
        return 0
    else
        log_warn "BBR 可能需要重启系统才能生效"
        log_warn "当前拥塞控制: $current"
        return 1
    fi
}

# 检查 sysctl 参数是否可写
check_sysctl_writable() {
    local param=$1
    if [ -e "/proc/sys/${param//./\/}" ]; then
        if sysctl -w "$param=1" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# 安全地设置 sysctl 参数
safe_sysctl() {
    local param=$1
    local value=$2
    if check_sysctl_writable "$param"; then
        sysctl -w "$param=$value" > /dev/null 2>&1 || true
        echo "$param = $value"
        return 0
    else
        log_warn "跳过不可设置的参数: $param"
        return 1
    fi
}

# 安全创建目录
safe_mkdir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || true
        if [ -d "$dir" ]; then
            log_info "已创建目录: $dir"
        fi
    fi
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
    log_info "正在优化 sysctl 配置 (模式: $OPTIMIZE_MODE)..."
    
    safe_mkdir "/etc/sysctl.d"
    
    if [ -f "$SYSCTL_CONF" ]; then
        backup_config "$SYSCTL_CONF"
    fi
    
    local temp_conf=$(mktemp)
    
    cat > "$temp_conf" << 'EOF'
# VPS 网络优化配置
EOF

    # BBR 拥塞控制 - 强制添加
    if [ "$IS_CONTAINER" -eq 0 ]; then
        cat >> "$temp_conf" << 'EOF'

# BBR 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
        # 强制启用 BBR
        force_enable_bbr
    fi

    local has_net_core=0
    if check_sysctl_writable "net.core.rmem_max"; then
        has_net_core=1
    fi
    
    if [ "$has_net_core" -eq 1 ]; then
        cat >> "$temp_conf" << 'EOF'

# 网络缓冲区
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.optmem_max = 65536
net.core.somaxconn = 65535
EOF
    fi

    if [ "$OPTIMIZE_MODE" = "both" ] || [ "$OPTIMIZE_MODE" = "tcp" ]; then
        cat >> "$temp_conf" << 'EOF'

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
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
EOF
    fi

    if [ "$OPTIMIZE_MODE" = "both" ] || [ "$OPTIMIZE_MODE" = "udp" ]; then
        cat >> "$temp_conf" << 'EOF'

# UDP 优化
net.core.netdev_max_backlog = 65535
net.core.rps_sock_flow_entries = 32768
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.udp_mem = 65536 131072 262144
EOF
    fi

    cat >> "$temp_conf" << 'EOF'

# 其他优化
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
# 专门应对高并发邻居环境
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000
EOF

    if [ "$IS_CONTAINER" -eq 0 ]; then
        cat >> "$temp_conf" << 'EOF'
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    fi

    mv "$temp_conf" "$SYSCTL_CONF"
    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
    
    log_success "sysctl 配置优化完成"
}

# 优化 limits 配置
optimize_limits() {
    log_info "正在优化 limits 配置..."
    
    safe_mkdir "/etc/security/limits.d"
    
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
        safe_mkdir "/etc/systemd/journald.conf.d"
        
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
    
    if [ "$IS_CONTAINER" -eq 1 ]; then
        log_info "容器环境，跳过 irqbalance"
        return
    fi
    
    if command -v irqbalance &> /dev/null; then
        if systemctl is-active --quiet irqbalance; then
            log_info "irqbalance 已在运行"
        else
            systemctl enable --now irqbalance 2>/dev/null || true
            log_success "irqbalance 已启用"
        fi
    fi
}

# 临时禁用有问题的 backports 仓库
disable_backports_repo() {
    local sources_list="/etc/apt/sources.list"
    local sources_d="/etc/apt/sources.list.d"
    
    if [ -f "$sources_list" ]; then
        if grep -i backports "$sources_list" > /dev/null; then
            backup_config "$sources_list"
            sed -i '/backports/s/^/#/' "$sources_list"
            log_info "已临时禁用 backports 仓库"
        fi
    fi
    
    if [ -d "$sources_d" ]; then
        for file in "$sources_d"/*.list; do
            if [ -f "$file" ] && grep -i backports "$file" > /dev/null; then
                backup_config "$file"
                sed -i '/backports/s/^/#/' "$file"
                log_info "已临时禁用 $file 中的 backports 仓库"
            fi
        done
    fi
}

# 安装必要工具
install_tools() {
    log_info "正在安装必要的网络工具..."
    
    case $OS in
        ubuntu|debian)
            disable_backports_repo
            apt-get update 2>/dev/null || log_warn "apt-get update 有警告，继续执行"
            
            local packages=("net-tools" "ethtool" "irqbalance")
            
            if apt-cache show iptables-persistent &> /dev/null; then
                packages+=("iptables-persistent")
            fi
            
            if apt-cache show dnsutils &> /dev/null; then
                packages+=("dnsutils")
            fi
            
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}" 2>/dev/null || log_warn "部分工具安装失败"
            ;;
        centos|rhel|fedora)
            local packages=("net-tools" "ethtool" "irqbalance")
            
            if command -v yum &> /dev/null; then
                if rpm -q iptables-services &> /dev/null || yum list available iptables-services &> /dev/null; then
                    packages+=("iptables-services")
                fi
                if rpm -q bind-utils &> /dev/null || yum list available bind-utils &> /dev/null; then
                    packages+=("bind-utils")
                fi
                yum install -y "${packages[@]}" 2>/dev/null || log_warn "部分工具安装失败"
            elif command -v dnf &> /dev/null; then
                dnf install -y "${packages[@]}" 2>/dev/null || log_warn "部分工具安装失败"
            fi
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
    
    if [ "$IS_CONTAINER" -eq 1 ]; then
        log_info "容器环境，跳过防火墙优化"
        return
    fi
    
    if ! command -v iptables &> /dev/null; then
        log_warn "iptables 不可用，跳过防火墙优化"
        return
    fi
    
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t nat -X 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    iptables -t mangle -X 2>/dev/null || true
    
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true
    
    if [ "$OPTIMIZE_MODE" = "both" ] || [ "$OPTIMIZE_MODE" = "udp" ]; then
        iptables -t raw -A PREROUTING -p udp -j NOTRACK 2>/dev/null || true
        iptables -t raw -A OUTPUT -p udp -j NOTRACK 2>/dev/null || true
        log_info "已启用 UDP NOTRACK"
    fi
    
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save 2>/dev/null || true
    elif command -v service &> /dev/null; then
        service iptables save 2>/dev/null || true
    fi
    
    log_success "防火墙规则优化完成"
}

# 禁用不必要的服务
disable_unnecessary_services() {
    log_info "正在禁用不必要的服务..."
    
    if [ "$IS_CONTAINER" -eq 1 ]; then
        log_info "容器环境，跳过服务管理"
        return
    fi
    
    local services=("apparmor" "ufw" "firewalld" "apache2" "httpd" "named" "sendmail")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            log_info "已禁用服务: $service"
        fi
    done
    
    log_success "不必要的服务已禁用"
}

# 执行优化
perform_optimize() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       开始执行网络优化"
    echo "       优化模式: ${OPTIMIZE_MODE^^}"
    echo "=========================================="
    echo -e "${NC}"
    
    check_root
    detect_os
    detect_container
    optimize_sysctl
    optimize_limits
    optimize_journald
    optimize_irqbalance
    install_tools
    optimize_firewall
    disable_unnecessary_services
    
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}   VPS 网络优化完成${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    echo -e "${GREEN}已完成的优化:${NC}"
    echo "  - sysctl 网络参数优化"
    echo "  - 文件描述符限制优化"
    echo "  - 强制启用 BBR"
    if [ "$IS_CONTAINER" -eq 0 ]; then
        echo "  - 防火墙规则优化"
        echo "  - 系统日志优化"
        echo "  - 中断平衡优化"
        echo "  - 禁用不必要的服务"
    fi
    echo ""
    echo -e "${YELLOW}重要:${NC}"
    echo "  必须重启系统才能应用所有优化！"
    echo ""
    echo -e "${YELLOW}重启后验证:${NC}"
    echo "  运行: sysctl net.ipv4.tcp_congestion_control"
    echo "  必须输出: bbr"
    echo ""
}

# 还原配置
restore_config() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       开始还原配置"
    echo "=========================================="
    echo -e "${NC}"
    
    check_root
    detect_os
    
    log_info "正在还原配置..."
    
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
    
    # 从 /etc/sysctl.conf 中移除 BBR 配置
    if [ -f /etc/sysctl.conf ]; then
        sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
        log_info "已从 /etc/sysctl.conf 中移除 BBR 配置"
        sysctl -p /etc/sysctl.conf 2>/dev/null || true
    fi
    
    log_success "配置还原完成，建议重启系统"
}

# 检查当前状态
check_status() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       检查当前状态"
    echo "=========================================="
    echo -e "${NC}"
    
    check_root
    detect_os
    detect_container
    
    echo ""
    echo -e "${BLUE}网络状态:${NC}"
    
    # 检查拥塞控制
    local current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d'=' -f2 | xargs)
    local available_cc=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | cut -d'=' -f2 | xargs)
    
    echo "  当前拥塞控制: ${current_cc:-unknown}"
    echo "  可用拥塞控制: ${available_cc:-unknown}"
    
    if [ "$current_cc" = "bbr" ]; then
        echo -e "  ${GREEN}BBR 已启用${NC}"
    else
        echo -e "  ${YELLOW}BBR 未启用${NC}"
    fi
    
    # 检查文件描述符
    local ulimit_n=$(ulimit -n)
    echo "  文件描述符限制: $ulimit_n"
    
    # 检查我们的配置文件
    echo ""
    echo -e "${BLUE}配置文件:${NC}"
    
    if [ -f "$SYSCTL_CONF" ]; then
        echo -e "  ${GREEN}$SYSCTL_CONF 存在${NC}"
    else
        echo -e "  ${YELLOW}$SYSCTL_CONF 不存在${NC}"
    fi
    
    if [ -f "$LIMITS_CONF" ]; then
        echo -e "  ${GREEN}$LIMITS_CONF 存在${NC}"
    else
        echo -e "  ${YELLOW}$LIMITS_CONF 不存在${NC}"
    fi
    
    # 检查 /etc/sysctl.conf 中的 BBR 配置
    echo ""
    echo -e "${BLUE}/etc/sysctl.conf:${NC}"
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        echo -e "  ${GREEN}包含: net.core.default_qdisc=fq${NC}"
    fi
    if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null; then
        echo -e "  ${GREEN}包含: net.ipv4.tcp_congestion_control=bbr${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}提示:${NC}"
    echo "  如果 BBR 未启用，请先运行优化，然后重启系统"
    echo ""
}

# 显示菜单
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "    VPS 网络优化脚本"
    echo "    版本 1.9.0 "
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}请选择操作:${NC}"
    echo ""
    echo "  1. 优化网络"
    echo "  2. 还原配置"
    echo "  3. 检查状态"
    echo "  0. 退出脚本"
    echo ""
    echo -ne "${YELLOW}请输入选项 [0-3]: ${NC}"
}

# 显示模式选择
show_mode_menu() {
    echo ""
    echo -e "${PURPLE}请选择优化模式:${NC}"
    echo ""
    echo "  1. TCP+UDP 双模式 (默认)"
    echo "  2. 仅 TCP 模式"
    echo "  3. 仅 UDP 模式"
    echo ""
    echo -ne "${YELLOW}请输入选项 [1-3, 默认1]: ${NC}"
}

# 主函数
main() {
    if [ $# -gt 0 ]; then
        case "${1:-}" in
            --restore)
                check_root
                detect_os
                restore_config
                exit 0
                ;;
            --optimize)
                OPTIMIZE_MODE="${2:-both}"
                if [ "$OPTIMIZE_MODE" != "both" ] && [ "$OPTIMIZE_MODE" != "tcp" ] && [ "$OPTIMIZE_MODE" != "udp" ]; then
                    log_error "无效的优化模式: $OPTIMIZE_MODE"
                    exit 1
                fi
                perform_optimize
                exit 0
                ;;
            --status)
                check_status
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    fi
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                show_mode_menu
                read -r mode_choice
                
                case $mode_choice in
                    1|"")
                        OPTIMIZE_MODE="both"
                        ;;
                    2)
                        OPTIMIZE_MODE="tcp"
                        ;;
                    3)
                        OPTIMIZE_MODE="udp"
                        ;;
                    *)
                        log_error "无效选项，使用默认模式"
                        OPTIMIZE_MODE="both"
                        ;;
                esac
                
                perform_optimize
                echo ""
                read -n 1 -s -p "按任意键返回菜单..."
                ;;
            2)
                restore_config
                echo ""
                read -n 1 -s -p "按任意键返回菜单..."
                ;;
            3)
                check_status
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

# 运行主函数
main "$@"
