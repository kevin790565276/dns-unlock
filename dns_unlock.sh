#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 深度补全域名列表 ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com github.com githubapp.com api.github.com openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai)
# 增加了 Netflix 关键 CDN 和 Spotify/Reddit 域名
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com nflxso.net netflix.net disneyplus.com disney-plus.net bamgrid.com bam.nr-data.net max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com scdn.co spotify.com reddit.com redditstatic.com redditmedia.com)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

get_status() {
    CURRENT_DNS=$(grep "nameserver" $RESOLV_CONF | awk '{print $2}' | head -n 1)
    if [ -f "$CONF_FILE" ]; then
        # 提取当前解析指向的 IP
        UNLOCK_IP=$(grep "address=" "$CONF_FILE" | head -n 1 | sed 's|.*/||')
    else
        UNLOCK_IP=""
    fi
    [[ "$CURRENT_DNS" == "127.0.0.1" ]] && DNS_STATUS="${GREEN}已接管${NC}" || DNS_STATUS="${RED}直连${NC}"
}

show_menu() {
    clear
    get_status
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}          NAT-SNI 强制解锁助手 (修复版) ${NC}"
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
}

do_install() {
    echo -e "\n${YELLOW}[*] 正在安装 Dnsmasq...${NC}"
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 环境就绪${NC}"
    echo -ne "\n按回车键继续..."; read
}

do_config() {
    echo -ne "\n${CYAN}请输入 SNI 公网 IP: ${NC}"; read sni_ip
    echo -ne "${CYAN}请输入映射端口 (NAT端口): ${NC}"; read sni_port

    if [[ ! $sni_ip =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo -e "${RED}[!] IP 格式错误${NC}"; sleep 2; return
    fi

    echo -e "${YELLOW}[*] 写入 Dnsmasq 强制解析...${NC}"
    mkdir -p /etc/dnsmasq.d/
    echo "# NAT SNI Rules" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "address=/$d/$sni_ip" >> $CONF_FILE
    done

    echo -e "${YELLOW}[*] 配置 iptables 端口重定向...${NC}"
    iptables -t nat -F OUTPUT 2>/dev/null
    iptables -t nat -A OUTPUT -d "$sni_ip" -p tcp --dport 443 -j DNAT --to-destination "$sni_ip:$sni_port"
    
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置已生效${NC}"
    echo -ne "\n按回车键返回菜单..."; read
}

do_clear() {
    echo -e "\n${RED}[*] 正在清理所有规则...${NC}"
    iptables -t nat -F OUTPUT 2>/dev/null
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 系统已还原${NC}"
    echo -ne "\n按回车键继续..."; read
}

do_check() {
    echo -e "\n${YELLOW}[*] 运行解锁检测工具...${NC}"
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n${CYAN}按回车键返回菜单...${NC}"; read
}

# --- 环境检查 ---
[[ $EUID -ne 0 ]] && exit 1
if systemctl is-active --quiet systemd-resolved; then 
    systemctl stop systemd-resolved && systemctl disable systemd-resolved
fi

# --- 循环逻辑 ---
while true; do
    show_menu
    read choice
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) do_check ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效输入${NC}"; sleep 1 ;;
    esac
done
