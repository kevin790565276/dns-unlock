#!/bin/bash

# 定义颜色
export CYAN='\033[0;36m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

# 检查 root
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 运行！${NC}" && exit 1

# 还原功能
restore_sysctl() {
    echo -e "\n${YELLOW}正在尝试还原内核参数...${NC}"
    if [ -f /etc/sysctl.conf.bak ]; then
        mv /etc/sysctl.conf.bak /etc/sysctl.conf
        sysctl -p
        echo -e "${GREEN}✅ 已成功恢复原始备份配置！${NC}"
    else
        echo -e "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1" > /etc/sysctl.conf
        sysctl -p
        echo -e "${YELLOW}提示: 已初始化为基础转发配置。${NC}"
    fi
}

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}       ⚡ 全球 VPS 网络深度优化脚本 ⚡          ${NC}"
echo -e "${CYAN}=================================================${NC}"
echo -e "请选择操作："
echo -e ""
echo -e "  ${GREEN}1)${NC} 全球/美国/长线优化 ${YELLOW}(64M 缓冲区)${NC}"
echo -e "  ${GREEN}2)${NC} 港日/近距离/直连优化 ${YELLOW}(32M 缓冲区)${NC}"
echo -e "  ${RED}3)${NC} 一键还原所有优化    ${RED}(恢复备份)${NC}"
echo -e "  ${CYAN}0)${NC} 退出脚本"
echo -e ""
echo -e "${CYAN}-------------------------------------------------${NC}"

read -p "请输入选项 [0-3]: " choice

case $choice in
    1) BUF=67108864; MODE="全球/长距离 (64MB)" ;;
    2) BUF=33554432; MODE="港日/近距离 (32MB)" ;;
    3) restore_sysctl; rm -f optimize.sh; exit 0 ;;
    0) echo -e "${YELLOW}已退出。${NC}"; rm -f optimize.sh; exit 0 ;;
    *) echo -e "${RED}无效选择。${NC}"; rm -f optimize.sh; exit 1 ;;
esac

# 备份
[[ ! -f /etc/sysctl.conf.bak ]] && cp /etc/sysctl.conf /etc/sysctl.conf.bak

# --- 修改部分开始 ---
echo -e "\n${YELLOW}1. 正在写入 Hy2 核心优化参数...${NC}"
echo -e "   ${CYAN}# 扩大堆货区: net.core.netdev_max_backlog=10000${NC}"
echo -e "   ${CYAN}# 增加 CPU 处理上限: net.core.netdev_budget=600${NC}"
echo -e "   ${CYAN}# 增加 CPU 处理权重: net.core.netdev_budget_usecs=20000${NC}"
# --- 修改部分结束 ---

cat > /etc/sysctl.conf << EOF
# 基础转发与 BBR
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Hy2 CPU 队列优化
net.core.netdev_max_backlog = 10000
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000

# 缓冲区优化
net.core.rmem_max = $BUF
net.core.wmem_max = $BUF
net.ipv4.tcp_rmem = 4096 87380 $BUF
net.ipv4.tcp_wmem = 4096 65536 $BUF
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400

# 稳定性增强
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

echo -e "\n${YELLOW}2. 执行 sysctl -p 生效配置:${NC}"
sysctl -p

echo -e "\n${YELLOW}3. 检查并安装 haveged...${NC}"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq haveged > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q haveged > /dev/null 2>&1
fi
systemctl enable haveged > /dev/null 2>&1 && systemctl start haveged > /dev/null 2>&1

echo -e "\n${CYAN}-------------------------------------------------${NC}"
echo -e "${GREEN}✅ 优化配置成功！${NC}"
echo -e "当前模式: ${YELLOW}$MODE${NC}"
echo -e "关键验证: "
echo -e " - CPU 队列上限: ${CYAN}$(sysctl net.core.netdev_max_backlog | awk '{print $3}')${NC}"
echo -e " - CPU 权重时长: ${CYAN}$(sysctl net.core.netdev_budget_usecs | awk '{print $3}')${NC}"
echo -e " - BBR 拥塞算法: ${CYAN}$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
echo -e "${CYAN}-------------------------------------------------${NC}\n"

rm -f optimize.sh
