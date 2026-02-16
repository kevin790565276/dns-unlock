#!/bin/bash

# 定义颜色
export CYAN='\033[0;36m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 运行！${NC}" && exit 1

# 检查路径是否存在
check_and_set() {
    if [ -f "/proc/sys/${1//./\ /}" ] || sysctl "$1" >/dev/null 2>&1; then
        sysctl -w "$1=$2" >/dev/null 2>&1
        return 0
    else
        return 1
    fi
}

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}       ⚡ 全球 VPS 网络深度优化脚本 ⚡          ${NC}"
echo -e "${CYAN}       (支持 KVM / NAT / OpenVZ / LXC)         ${NC}"
echo -e "${CYAN}=================================================${NC}"
echo -e "请选择操作："
echo -e ""
echo -e "  ${GREEN}1)${NC} 全球/美国/长线优化 ${YELLOW}(64M 缓冲区)${NC}"
echo -e "  ${GREEN}2)${NC} 港日/近距离/直连优化 ${YELLOW}(32M 缓冲区)${NC}"
echo -e "  ${RED}3)${NC} 一键还原所有优化"
echo -e "  ${CYAN}0)${NC} 退出脚本"
echo -e ""
echo -e "${CYAN}-------------------------------------------------${NC}"

read -p "请输入选项 [0-3]: " choice

case $choice in
    1) BUF=67108864; MODE="全球/长距离 (64MB)" ;;
    2) BUF=33554432; MODE="港日/近距离 (32MB)" ;;
    3) [[ -f /etc/sysctl.conf.bak ]] && mv /etc/sysctl.conf.bak /etc/sysctl.conf && sysctl -p; rm -f optimize.sh; exit 0 ;;
    0) rm -f optimize.sh; exit 0 ;;
    *) rm -f optimize.sh; exit 1 ;;
esac

[[ ! -f /etc/sysctl.conf.bak ]] && cp /etc/sysctl.conf /etc/sysctl.conf.bak

echo -e "\n${YELLOW}1. 正在应用 Hy2/网络优化参数...${NC}"

# 使用临时文件避免 sysctl -p 满屏报错
cat > /etc/sysctl.d/99-optimize.conf << EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 10000
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000
net.core.rmem_max = $BUF
net.core.wmem_max = $BUF
net.ipv4.tcp_rmem = 4096 87380 $BUF
net.ipv4.tcp_wmem = 4096 65536 $BUF
net.ipv4.tcp_max_syn_backlog = 16384
net.core.somaxconn = 16384
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

echo -e "${YELLOW}2. 执行配置应用 (自动跳过不支持的参数):${NC}"
# 逐行加载，失败的静默跳过，成功地显示出来
while IFS= read -r line; do
    [[ "$line" =~ ^#.* ]] || [[ -z "$line" ]] && continue
    key=$(echo $line | cut -d'=' -f1 | tr -d ' ')
    value=$(echo $line | cut -d'=' -f2 | tr -d ' ')
    if sysctl -w "$key=$value" >/dev/null 2>&1; then
        echo -e "${GREEN}[成功]${NC} $key"
    else
        echo -e "${RED}[跳过]${NC} $key (架构限制)"
    fi
done < /etc/sysctl.d/99-optimize.conf

echo -e "\n${YELLOW}3. 检查并安装 haveged...${NC}"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq haveged > /dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q haveged > /dev/null 2>&1
fi
systemctl enable haveged > /dev/null 2>&1 && systemctl start haveged > /dev/null 2>&1

echo -e "\n${CYAN}-------------------------------------------------${NC}"
echo -e "${GREEN}✅ 优化尝试完成！${NC}"
echo -e "架构类型: ${YELLOW}$(systemd-detect-virt 2>/dev/null || echo "unknown")${NC}"
echo -e "当前模式: ${YELLOW}$MODE${NC}"
echo -e "提示: [跳过] 的项说明你的 NAT 架构不支持修改该内核参数。"
echo -e "${CYAN}-------------------------------------------------${NC}\n"

rm -f optimize.sh
