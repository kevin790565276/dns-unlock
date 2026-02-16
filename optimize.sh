#!/bin/bash

# 定义颜色
export CYAN='\033[0;36m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

# 检查 root
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 用户运行此脚本！${NC}" && exit 1

# 还原功能的函数
restore_sysctl() {
    echo -e "\n${YELLOW}正在尝试还原内核参数...${NC}"
    if [ -f /etc/sysctl.conf.bak ]; then
        mv /etc/sysctl.conf.bak /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
        echo -e "${GREEN}✅ 已成功恢复原始备份配置！${NC}"
    else
        # 如果没有备份，则清空当前配置并写入系统默认的基础转发
        cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
        sysctl -p > /dev/null 2>&1
        echo -e "${YELLOW}提示: 未找到备份文件，已初始化为基础转发配置。${NC}"
    fi
    echo -e "${CYAN}-------------------------------------------------${NC}\n"
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
    1)
        BUF=67108864
        MODE="全球/长距离线路 (64MB)"
        ;;
    2)
        BUF=33554432
        MODE="港日/近距离线路 (32MB)"
        ;;
    3)
        restore_sysctl
        rm -f optimize.sh
        exit 0
        ;;
    0)
        echo -e "${YELLOW}已退出脚本。${NC}"
        rm -f optimize.sh
        exit 0
        ;;
    *)
        echo -e "${RED}无效选项，脚本退出。${NC}"
        rm -f optimize.sh
        exit 1
        ;;
esac

# 备份原始配置（仅在不存在备份时备份）
if [ ! -f /etc/sysctl.conf.bak ]; then
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
fi

echo -e "\n${YELLOW}正在应用 $MODE 优化方案...${NC}"

# 写入内核参数
cat > /etc/sysctl.conf << EOF
# 基础优化
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 缓冲区优化
net.core.rmem_max = $BUF
net.core.wmem_max = $BUF
net.ipv4.tcp_rmem = 4096 87380 $BUF
net.ipv4.tcp_wmem = 4096 65536 $BUF
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400

# 并发与稳定性
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

# 使配置生效
sysctl -p > /dev/null 2>&1

# 静默安装 haveged
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq haveged >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q haveged >/dev/null 2>&1
fi
systemctl enable haveged > /dev/null 2>&1 && systemctl start haveged > /dev/null 2>&1

echo -e "\n${CYAN}-------------------------------------------------${NC}"
echo -e "${GREEN}✅ 优化成功配置！${NC}"
echo -e "当前模式: ${YELLOW}$MODE${NC}"
echo -e "原始备份: ${CYAN}/etc/sysctl.conf.bak${NC}"
echo -e "${CYAN}-------------------------------------------------${NC}\n"

# 自动清理
rm -f optimize.sh
