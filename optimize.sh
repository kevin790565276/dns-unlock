#!/bin/bash

# 定义颜色
export CYAN='\033[0;36m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 运行！${NC}" && exit 1

# 更加强力的架构检测
VIRT=$(systemd-detect-virt 2>/dev/null)
[[ -z "$VIRT" ]] && [[ -d /proc/vz ]] && VIRT="openvz"
[[ -z "$VIRT" ]] && VIRT="unknown/nat"

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

echo -e "\n${YELLOW}1. 正在准备 Hy2 核心优化参数...${NC}"
echo -e "   ${CYAN}# 扩大堆货区: net.core.netdev_max_backlog=10000${NC}"
echo -e "   ${CYAN}# 增加 CPU 处理上限: net.core.netdev_budget=600${NC}"
echo -e "   ${CYAN}# 增加 CPU 处理权重: net.core.netdev_budget_usecs=20000${NC}"
echo -e "   ${CYAN}# 调整 TCP/UDP 缓冲区: $MODE${NC}"

cat > /tmp/sysctl_opt.conf << EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.netdev_max_backlog=10000
net.core.netdev_budget=600
net.core.netdev_budget_usecs=20000
net.core.rmem_max=$BUF
net.core.wmem_max=$BUF
net.ipv4.tcp_rmem=4096 87380 $BUF
net.ipv4.tcp_wmem=4096 65536 $BUF
net.ipv4.tcp_max_syn_backlog=16384
net.core.somaxconn=16384
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=20
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
EOF

echo -e "\n${YELLOW}2. 执行配置应用 (逐行检测兼容性):${NC}"
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    if sysctl -w "$key=$value" >/dev/null 2>&1; then
        echo -e "   ${GREEN}[OK]${NC} $key = $value"
        sed -i "/^$key/d" /etc/sysctl.conf
        echo "$key = $value" >> /etc/sysctl.conf
    else
        echo -e "   ${RED}[SKIP]${NC} $key (内核锁定)"
    fi
done < /tmp/sysctl_opt.conf

echo -e "\n${YELLOW}3. 检查 haveged (环境适配):${NC}"
if command -v haveged >/dev/null 2>&1; then
    HAVEGED_STATUS="${GREEN}已就绪${NC}"
else
    # 尝试安装，不成功也不报错，安静处理
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq haveged >/dev/null 2>&1 || yum install -y -q haveged >/dev/null 2>&1
    if systemctl is-active --quiet haveged 2>/dev/null; then
        HAVEGED_STATUS="${GREEN}安装并启动成功${NC}"
    else
        HAVEGED_STATUS="${YELLOW}跳过 (NAT环境通常无需安装)${NC}"
    fi
fi

BBR_MODULE=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
[[ "$BBR_MODULE" == "bbr" ]] && BBR_STATUS="${GREEN}已开启 (bbr)${NC}" || BBR_STATUS="${RED}未开启 ($BBR_MODULE)${NC}"

echo -e "\n${CYAN}-------------------------------------------------${NC}"
echo -e "${GREEN}✅ 优化任务执行完毕！${NC}"
echo -e "虚拟化架构: ${YELLOW}$VIRT${NC}"
echo -e "BBR 加速状态: $BBR_STATUS"
echo -e "Haveged 状态: $HAVEGED_STATUS"
echo -e "提示: 关键的 BBR 开启成功即代表优化已生效！"
echo -e "${CYAN}-------------------------------------------------${NC}\n"

rm -f /tmp/sysctl_opt.conf optimize.sh
