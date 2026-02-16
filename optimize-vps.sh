#!/bin/bash

# VPS 网络优化脚本 - 支持 TCP (xhttp, v2ray) 和 UDP (Hysteria 2)
# 适用于 GitHub 部署，支持 NAT 小鸡和受限环境
# 版本: 1.6.1

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
OPTIMIZE_MODE="both" # both, tcp, udp

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
    
    # 确保目录存在
    safe_mkdir "/etc/sysctl.d"
    
    if [ -f "$SYSCTL_CONF" ]; then
        backup_config "$SYSCTL_CONF"
    fi
    
    # 创建临时文件来收集可用的参数
    local temp_conf=$(mktemp)
    
    cat > "$temp_conf" << 'EOF'
# VPS 网络优化配置
# 支持 TCP (xhttp, v2ray) 和 UDP (Hysteria 2)
EOF

    # BBR 拥塞控制 (TCP) - 仅在非容器环境尝试
    if [ "$IS_CONTAINER" -eq 0 ]; then
        if check_sysctl_writable "net.core.default_qdisc"; then
            cat >> "$temp_conf" << 'EOF'

# BBR 拥塞控制 (TCP优化)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
        fi
    fi

    # 网络缓冲区 (通用) - 检查哪些可用
    local has_net_core=0
    if check_sysctl_writable "net.core.rmem_max"; then
        has_net_core=1
    fi
    
    if [ "$has_net_core" -eq 1 ]; then
        cat >> "$temp_conf" << 'EOF'

# 提升网络缓冲区 (通用)
EOF
        safe_sysctl "net.core.rmem_max" "67108864" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.core.wmem_max" "67108864" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.core.rmem_default" "65536" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.core.wmem_default" "65536" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.core.optmem_max" "65536" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.core.somaxconn" "65535" >> "$temp_conf" 2>/dev/null || true
    fi

    # TCP 优化
    if [ "$OPTIMIZE_MODE" = "both" ] || [ "$OPTIMIZE_MODE" = "tcp" ]; then
        cat >> "$temp_conf" << 'EOF'

# TCP 优化 (xhttp, v2ray, vmess等)
EOF
        # 只添加可用的 TCP 参数
        safe_sysctl "net.ipv4.tcp_rmem" "4096 87380 67108864" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_wmem" "4096 65536 67108864" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_syncookies" "1" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_tw_reuse" "1" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_timestamps" "0" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_sack" "1" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_fack" "1" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_window_scaling" "1" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_keepalive_time" "600" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_keepalive_intvl" "30" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_keepalive_probes" "3" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_fin_timeout" "30" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_max_syn_backlog" "65535" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.ip_local_port_range" "1024 65535" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_max_tw_buckets" "2000000" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_mtu_probing" "1" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.tcp_slow_start_after_idle" "0" >> "$temp_conf" 2>/dev/null || true
    fi

    # UDP 优化
    if [ "$OPTIMIZE_MODE" = "both" ] || [ "$OPTIMIZE_MODE" = "udp" ]; then
        cat >> "$temp_conf" << 'EOF'

# UDP 优化 (Hysteria 2, QUIC等)
EOF
        safe_sysctl "net.core.netdev_max_backlog" "65535" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.core.rps_sock_flow_entries" "32768" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.udp_rmem_min" "8192" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.udp_wmem_min" "8192" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "net.ipv4.udp_mem" "65536 131072 262144" >> "$temp_conf" 2>/dev/null || true
    fi

    # 其他优化
    cat >> "$temp_conf" << 'EOF'

# 其他优化 (通用)
EOF
    safe_sysctl "net.ipv4.conf.all.rp_filter" "0" >> "$temp_conf" 2>/dev/null || true
    safe_sysctl "net.ipv4.conf.default.rp_filter" "0" >> "$temp_conf" 2>/dev/null || true
    safe_sysctl "net.ipv4.icmp_echo_ignore_broadcasts" "1" >> "$temp_conf" 2>/dev/null || true
    safe_sysctl "net.ipv4.icmp_ignore_bogus_error_responses" "1" >> "$temp_conf" 2>/dev/null || true
    # VM 参数在容器中通常不可用，跳过
    if [ "$IS_CONTAINER" -eq 0 ]; then
        safe_sysctl "vm.swappiness" "10" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "vm.dirty_ratio" "15" >> "$temp_conf" 2>/dev/null || true
        safe_sysctl "vm.dirty_background_ratio" "5" >> "$temp_conf" 2>/dev/null || true
    fi

    # 移动临时文件到最终位置
    mv "$temp_conf" "$SYSCTL_CONF"
    
    # 尝试加载配置，忽略错误
    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
    
    log_success "sysctl 配置优化完成（已跳过受限参数）"
}

# 优化 limits 配置
optimize_limits() {
    log_info "正在优化 limits 配置..."
    
    # 确保目录存在
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
        # 确保目录存在
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
    
    # 容器环境通常没有 irqbalance
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

# 检查并启用 BBR
enable_bbr() {
    log_info "正在检查 BBR 状态..."
    
    # 容器环境跳过 BBR
    if [ "$IS_CONTAINER" -eq 1 ]; then
        log_info "容器环境，跳过 BBR 检测"
        return
    fi
    
    if modprobe tcp_bbr 2>/dev/null; then
        if lsmod | grep -q bbr; then
            log_success "BBR 已加载"
        else
            log_warn "BBR 未加载，尝试加载..."
            modprobe tcp_bbr 2>/dev/null || true
            if lsmod | grep -q bbr; then
                log_success "BBR 已加载"
            else
                log_warn "无法加载 BBR，继续执行其他优化"
            fi
        fi
    else
        log_warn "系统可能不支持 BBR，继续执行其他优化"
    fi
}

# 临时禁用有问题的 backports 仓库
disable_backports_repo() {
    local sources_list="/etc/apt/sources.list"
    local sources_d="/etc/apt/sources.list.d"
    
    # 注释掉 backports 仓库
    if [ -f "$sources_list" ]; then
        if grep -i backports "$sources_list" > /dev/null; then
            backup_config "$sources_list"
            sed -i '/backports/s/^/#/' "$sources_list"
            log_info "已临时禁用 backports 仓库"
        fi
    fi
    
    # 检查 sources.list.d 目录
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
            # 先禁用有问题的 backports 仓库
            disable_backports_repo
            
            # 更新包列表（忽略错误）
            apt-get update 2>/dev/null || log_warn "apt-get update 有警告，继续执行"
            
            # 尝试安装工具，跳过不存在的包
            local packages=("net-tools" "ethtool" "irqbalance")
            
            # 检查并添加可用的包
            if apt-cache show iptables-persistent &> /dev/null; then
                packages+=("iptables-persistent")
            fi
            
            if apt-cache show dnsutils &> /dev/null; then
                packages+=("dnsutils")
            fi
            
            # 安装
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}" 2>/dev/null || log_warn "部分工具安装失败，继续执行"
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
                yum install -y "${packages[@]}" 2>/dev/null || log_warn "部分工具安装失败，继续执行"
            elif command -v dnf &> /dev/null; then
                dnf install -y "${packages[@]}" 2>/dev/null || log_warn "部分工具安装失败，继续执行"
            fi
            ;;
        *)
            log_warn "不支持的操作系统，跳过工具安装"
            ;;
    esac
    
    log_success "网络工具安装完成（或跳过）"
}

# 优化防火墙规则
optimize_firewall() {
    log_info "正在优化防火墙规则..."
    
    # 容器环境通常没有 iptables 权限
    if [ "$IS_CONTAINER" -eq 1 ]; then
        log_info "容器环境，跳过防火墙优化"
        return
    fi
    
    # 检查 iptables 是否可用
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
    
    # UDP 不跟踪 (仅在UDP模式或双模式下)
    if [ "$OPTIMIZE_MODE" = "both" ] || [ "$OPTIMIZE_MODE" = "udp" ]; then
        iptables -t raw -A PREROUTING -p udp -j NOTRACK 2>/dev/null || true
        iptables -t raw -A OUTPUT -p udp -j NOTRACK 2>/dev/null || true
        log_info "已启用 UDP NOTRACK"
    fi
    
    # 尝试保存规则
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
    
    # 容器环境跳过
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
    echo "╔═══════════════════════════════════════════════╗"
    echo "║              开始执行网络优化                   ║"
    echo "║         优化模式: ${OPTIMIZE_MODE^^}${NC}${CYAN}"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    detect_os
    detect_container
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
    echo -e "${CYAN}   VPS 网络优化完成${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}已完成的优化:${NC}"
    echo "  ✅ sysctl 网络参数优化（已跳过受限参数）"
    echo "  ✅ 文件描述符限制优化"
    if [ "$IS_CONTAINER" -eq 0 ]; then
        echo "  ✅ BBR 拥塞控制（如支持）"
        echo "  ✅ 防火墙规则优化"
        echo "  ✅ 系统日志优化"
        echo "  ✅ 中断平衡优化"
        echo "  ✅ 禁用不必要的服务"
    fi
    echo ""
    echo -e "${BLUE}适用协议:${NC}"
    if [ "$OPTIMIZE_MODE" = "both" ]; then
        echo "  TCP (xhttp, v2ray, vmess)"
        echo "  UDP (Hysteria 2, QUIC)"
    elif [ "$OPTIMIZE_MODE" = "tcp" ]; then
        echo "  TCP (xhttp, v2ray, vmess)"
    else
        echo "  UDP (Hysteria 2, QUIC)"
    fi
    echo ""
    if [ "$IS_CONTAINER" -eq 1 ]; then
        echo -e "${PURPLE}注意:${NC}"
        echo "  检测到容器环境 (NAT小鸡/OpenVZ/LXC)"
        echo "  部分内核参数无法修改，已自动跳过"
        echo ""
    fi
    echo -e "${YELLOW}建议:${NC}"
    echo "  1. 重启系统以应用所有优化"
    if [ "$IS_CONTAINER" -eq 0 ]; then
        echo "  2. 重启后运行: sysctl net.ipv4.tcp_congestion_control"
        echo "  3. 确保输出为 'bbr'"
    fi
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
        sysctl -p /etc/sysctl.conf 2>/dev/null || true
    fi
    
    log_success "配置还原完成，建议重启系统"
}

# 显示模式选择菜单
show_mode_menu() {
    echo ""
    echo -e "${PURPLE}请选择优化模式:${NC}"
    echo ""
    echo "  1. TCP+UDP 双模式 (默认) - 适合所有协议"
    echo "     包含: xhttp, v2ray, vmess, Hysteria 2, QUIC"
    echo ""
    echo "  2. 仅 TCP 模式 - 适合 TCP 协议"
    echo "     包含: xhttp, v2ray, vmess"
    echo ""
    echo "  3. 仅 UDP 模式 - 适合 UDP 协议"
    echo "     包含: Hysteria 2, QUIC"
    echo ""
    echo -ne "${YELLOW}请输入选项 [1-3, 默认1]: ${NC}"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║    VPS 网络优化脚本 - 支持 TCP 和 UDP          ║"
    echo "║              版本 1.6.1 - 支持 NAT 小鸡        ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}支持的协议:${NC}"
    echo "  TCP: xhttp, v2ray, vmess, trojan"
    echo "  UDP: Hysteria 2, QUIC"
    echo ""
    echo -e "${PURPLE}环境支持:${NC}"
    echo "  ✅ 独立服务器/KVM"
    echo "  ✅ NAT小鸡/OpenVZ/LXC"
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
                OPTIMIZE_MODE="${2:-both}"
                if [ "$OPTIMIZE_MODE" != "both" ] && [ "$OPTIMIZE_MODE" != "tcp" ] && [ "$OPTIMIZE_MODE" != "udp" ]; then
                    log_error "无效的优化模式: $OPTIMIZE_MODE"
                    show_help
                    exit 1
                fi
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
                # 选择优化模式
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
                        log_error "无效选项，使用默认模式 (both)"
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
    echo "VPS 网络优化脚本 - 支持 TCP 和 UDP"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --optimize [模式]  直接执行优化"
    echo "                     模式: both (默认), tcp, udp"
    echo "  --restore           直接还原配置"
    echo "  --help              显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                          # 进入交互式菜单"
    echo "  $0 --optimize               # 双模式优化 (TCP+UDP)"
    echo "  $0 --optimize tcp           # 仅 TCP 优化 (xhttp, v2ray)"
    echo "  $0 --optimize udp           # 仅 UDP 优化 (Hysteria 2)"
    echo "  $0 --restore                # 还原配置"
    echo ""
    echo "支持的协议:"
    echo "  TCP: xhttp, v2ray, vmess, trojan"
    echo "  UDP: Hysteria 2, QUIC"
    echo ""
    echo "环境支持:"
    echo "  ✅ 独立服务器/KVM"
    echo "  ✅ NAT小鸡/OpenVZ/LXC"
    echo ""
}

# 运行主函数
main "$@"
