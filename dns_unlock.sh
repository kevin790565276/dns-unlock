#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 域名列表 ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com github.com githubapp.com api.github.com openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

get_status() {
    CURRENT_DNS=$(grep "nameserver" $RESOLV_CONF | awk '{print $2}' | head -n 1)
    if [ -f "$CONF_FILE" ]; then
        # 还原回提取 server= 后缀 IP 的逻辑
        UNLOCK_IP=$(grep "server=" "$CONF_FILE" | head -n 1 | awk -F'/' '{print $4}')
    else
        UNLOCK_IP=""
    fi
    [[ "$CURRENT_DNS" == "127.0.0.1" ]] && DNS_STATUS="${GREEN}已接管${NC}" || DNS_STATUS="${RED}直连${NC}"
}

show_menu() {
    clear
    get_status
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}            DNS 流媒体解锁脚本 (标准版) ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前解锁 DNS: ${YELLOW}${UNLOCK_IP:-未配置}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq"
    echo -e "  ${GREEN}2.${NC} 配置解锁 DNS (server= 模式)"
    echo -e "  ${RED}3.${NC} 彻底还原系统"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
}

do_install() {
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    systemctl enable dnsmasq && systemctl restart dnsmasq
    sleep 2
}

do_config() {
    echo -ne "\n${CYAN}请输入解锁 DNS IP (例 1.1.1.1): ${NC}"
    read dns_ip
    
    # 彻底清理之前 NAT 模式留下的 iptables 规则
    iptables -t nat -F OUTPUT 2>/dev/null
    
    echo -e "${YELLOW}[*] 正在写入标准转发规则...${NC}"
    mkdir -p /etc/dnsmasq.d/
    echo "# Unlock Rules" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$d/$dns_ip" >> $CONF_FILE
    done

    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置已恢复标准模式${NC}"
    sleep 2
}

do_clear() {
    echo -e "\n${RED}[*] 正在彻底重置环境...${NC}"
    iptables -t nat -F OUTPUT 2>/dev/null
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 系统已完全还原${NC}"
    sleep 2
}

do_check() {
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n按回车键返回..."; read
}

# --- 启动检查 ---
[[ $EUID -ne 0 ]] && exit 1
while true; do
    show_menu
    read choice
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) do_check ;;
        0) exit 0 ;;
    esac
done
