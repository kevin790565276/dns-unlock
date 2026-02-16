#!/bin/bash

# 定义颜色
export CYAN='\033[0;36m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 运行！${NC}" && exit 1

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}       ⚡ 全球 VPS 网络深度优化脚本 ⚡          ${NC}"
echo -e "${CYAN}=================================================${NC}"
echo -e "  1) 全球/美国/长线优化 (64M)\n  2) 港日/近距离/直连优化 (32M)\n  3) 一键还原\n  0) 退出"
read -p "请输入选项 [0-3]: " choice

case $choice in
    1) BUF=67108864; MODE="全球/长距离 (64MB)" ;;
    2) BUF=33554432; MODE="港日/近距离 (32MB)" ;;
    3) 
        if [ -f /etc/sysctl.conf.bak ]; then
            mv /etc/sysctl.conf.bak /etc/sysctl.conf && sysctl -p
            echo -e "${GREEN}还原成功${NC}"
        fi
        rm -f optimize.sh && exit 0 ;;
    0) rm -f optimize.sh && exit 0 ;;
    *) rm -f optimize.sh && exit 1 ;;
esac

if [ ! -f /etc/sysctl.conf.bak ]; then cp /etc/sysctl.conf /etc/sysctl.conf.bak; fi

echo -e "\n${YELLOW}1. 正在写入 Hy2 核心优化参数...${NC}"

# 注意：我把那三行挪到了最显眼的位置
cat > /etc/sysctl.conf << EOF
# 基础转发与 BBR
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# --- Hy2 关键 CPU 队列优化 ---
net.core.netdev_max_backlog = 10000
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000

# --- 缓冲区优化 ---
net.core.rmem_max = $BUF
net.core.wmem_max = $BUF
net.ipv4.tcp_rmem = 4096 87380 $BUF
net.ipv4.tcp_wmem = 4096 65536 $BUF
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400

# --- 稳定性优化 ---
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

echo -e "${YELLOW}2. 执行 sysctl -p (请留意下方输出):${NC}"
sysctl -p

echo -e "\n${YELLOW}3. 检查 haveged...${NC}"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq haveged > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q haveged > /dev/null 2>&1
fi
systemctl enable haveged >/dev/null 2>&1 && systemctl start haveged >/dev/null 2>&1

echo -e "\n${CYAN}-------------------------------------------------${NC}"
echo -e "${GREEN}✅ 优化成功配置！${NC}"
echo -e "当前模式: ${YELLOW}$MODE${NC}"
echo -e "关键验证: "
# 强制手动查询一次，确保你看见结果
echo -e " - CPU 队列上限: ${CYAN}$(sysctl net.core.netdev_max_backlog)${NC}"
echo -e " - CPU 权重时长: ${CYAN}$(sysctl net.core.netdev_budget_usecs)${NC}"
echo -e "${CYAN}-------------------------------------------------${NC}\n"

rm -f optimize.sh
