#!/bin/bash
# VPS 通用网络优化脚本 - 2026 稳定版
# 适用范围: 20ms (直连) 到 250ms (跨海)
set -e

# 颜色定义
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

SYSCTL_CONF="/etc/sysctl.d/99-vps-universal.conf"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_done() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

# 核心优化
apply_universal_opt() {
    log_info "正在注入通用高性能参数..."
    
    # 彻底清理可能导致卡顿的旧配置
    rm -f /etc/sysctl.d/99-hy2-network.conf 2>/dev/null

    cat > "$SYSCTL_CONF" << EOF
# 1. 拥塞控制：BBR + FQ (跨海线路必备)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 2. 延迟修复：关闭 MTU 探测，防止握手时卡死 (解决 5s 延迟元凶)
net.ipv4.tcp_mtu_probing = 0

# 3. 缓冲区调优：初始值小(适合20ms响应)，最大值大(适合250ms高吞吐)
# 允许最大窗口达到 64MB，足以跑满 250ms 下的千兆带宽
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

# 4. 快速握手与连接优化
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fastopen = 3
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# 5. UDP 优化 (适合 Hy2/Hysteria)
net.core.netdev_max_backlog = 10000
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
EOF

    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    
    # 文件描述符限制
    echo -e "* soft nofile 512000\n* hard nofile 512000" > /etc/security/limits.d/99-opt.conf
    
    log_done "优化已完成！"
    echo -e "${YELLOW}当前配置生效范围：${NC}"
    echo -e "- 20ms 线路：首包响应极快，无探测开销"
    echo -e "- 250ms 线路：BBR 配合 64MB 窗口，确保跨海带宽跑满"
}

# 简单交互
clear
echo -e "${CYAN}==========================================${NC}"
echo -e "         VPS 通用网络优化脚本 V2.5"
echo -e "     (已通过 3ms/50ms/250ms 综合测试)"
echo -e "${CYAN}==========================================${NC}"
echo "  1. 执行通用优化"
echo "  2. 还原配置"
echo "  0. 退出"
echo ""
read -p "请输入选项: " choice
case $choice in
    1) apply_universal_opt ;;
    2) rm -f "$SYSCTL_CONF" && sysctl --system && log_done "已还原" ;;
    *) exit 0 ;;
esac
