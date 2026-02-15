#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 域名列表 (针对 Netflix/Disney+ 深度补全) ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com github.com githubapp.com api.github.com openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com nflxso.net netflix.net disneyplus.com disney-plus.net bamgrid.com bam.nr-data.net max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com scdn.co reddit.com redditstatic.com redditmedia.com)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

get_status() {
    CURRENT_DNS=$(grep "nameserver" $RESOLV_CONF | awk '{print $2}' | head -n 1)
    if [ -f "$CONF_FILE" ]; then
        # 提取最后一条规则的 IP 供显示
        UNLOCK_IP=$(grep "address=" "$CONF_FILE" | tail -n 1 | sed 's|.*/||')
    else
        UNLOCK_IP=""
    fi
    [[ "$CURRENT_DNS" == "127.0.0.1" ]] && DNS_STATUS="${GREEN}已接管${NC}" || DNS_STATUS="${RED}直连${NC}"
}

# --- 功能函数 ---
do_install() {
    echo -e "\n${YELLOW}[*] 正在安装 Dnsmasq 环境...${NC}"
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 安装完成${NC}"
    echo -ne "\n按回车键继续..."; read
}

do_config() {
    echo -ne "\n${CYAN}请输入 SNI 公网 IP: ${NC}"; read sni_ip
    echo -ne "${CYAN}请输入映射端口 (NAT端口): ${NC}"; read sni_port

    if [[ ! $sni_ip =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo -e "${RED}[!] 格式错误！${NC}"; sleep 2; return
    fi

    echo -e "${YELLOW}[*] 正在配置解析规则...${NC}"
    mkdir -p /etc/dnsmasq.d/
    echo "# NAT SNI Rules" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "address=/$d/$sni_ip" >> $CONF_FILE
    done

    echo -e "${YELLOW}[*] 正在配置流量重定向...${NC}"
    iptables -t nat -F OUTPUT 2>/dev/null
    iptables -t nat -A OUTPUT -d "$sni_ip" -p tcp --dport 443 -j DNAT --to-destination "$sni_ip:$sni_port"
    
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置成功！${NC}"
    echo -ne "\n按回车键返回主菜单..."; read
}

do_clear() {
    echo -e "\n${RED}[*] 正在清理规则...${NC}"
    iptables -t nat -F OUTPUT 2>/dev/null
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 系统已还原${NC}"
    echo -ne "\n按回车键继续..."; read
}

do_check() {
    echo -e "\n${YELLOW}[*] 运行 oneclickvirt 检测工具...${NC}"
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n${CYAN}按回车键返回主菜单...${NC}"; read
}

# --- 菜单循环 ---
[[ $EUID -ne 0 ]] && echo "请以 root 运行" && exit 1
while true; do
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}          NAT-SNI 专用强制解锁助手 ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前指向 SNI: ${YELLOW}${UNLOCK_IP:-未配置}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq 环境"
    echo -e "  ${GREEN}2.${NC} 配置 DNS 解锁添加规则"
    echo -e "  ${RED}3.${NC} 还原系统配置"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测 ${CYAN}(by oneclickvirt)${NC}"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
    read choice
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) do_check ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
done
