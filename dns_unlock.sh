#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# (快捷指令、域名列表部分保持不变...)
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com github.com githubapp.com api.github.com openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

get_status() {
    CURRENT_DNS=$(grep "nameserver" $RESOLV_CONF | awk '{print $2}' | head -n 1)
    if [ -f "$CONF_FILE" ]; then
        UNLOCK_IP=$(grep "address=" "$CONF_FILE" | head -n 1 | awk -F'/' '{print $4}')
    else
        UNLOCK_IP=""
    fi
    [[ "$CURRENT_DNS" == "127.0.0.1" ]] && DNS_STATUS="${GREEN}已接管${NC}" || DNS_STATUS="${RED}直连${NC}"
}

show_menu() {
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}          NAT-SNI 专用强制解锁版 ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前指向 SNI: ${YELLOW}${UNLOCK_IP:-未配置}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq 环境"
    echo -e "  ${GREEN}2.${NC} 配置 NAT 解锁规则 (IP+端口转发)"
    echo -e "  ${RED}3.${NC} 还原系统配置 (含清理防火墙)"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测 (by oneclickvirt)"
    echo -e "  ${BLUE}0.${NC} 退出"
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
    read choice < /dev/tty
}

do_config() {
    echo -ne "\n${CYAN}请输入 SNI 公网 IP (例: 45.127.35.233): ${NC}"
    read sni_ip < /dev/tty
    echo -ne "${CYAN}请输入映射后的 HTTPS 端口 (例: 46046): ${NC}"
    read sni_port < /dev/tty

    if [[ ! $sni_ip =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo -e "${RED}[!] IP 错误${NC}"
        sleep 2 && return
    fi

    echo -e "${YELLOW}[*] 正在配置 Dnsmasq 解析规则...${NC}"
    mkdir -p /etc/dnsmasq.d/
    echo "# NAT SNI Rules" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "address=/$d/$sni_ip" >> $CONF_FILE
    done

    echo -e "${YELLOW}[*] 正在配置 iptables 端口重定向...${NC}"
    # 先清理可能存在的旧规则防止重复
    iptables -t nat -D OUTPUT -d "$sni_ip" -p tcp --dport 443 -j DNAT --to-destination "$sni_ip:$sni_port" 2>/dev/null
    # 添加新规则
    iptables -t nat -A OUTPUT -d "$sni_ip" -p tcp --dport 443 -j DNAT --to-destination "$sni_ip:$sni_port"

    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置完成！443 流量已重定向至 $sni_port ${NC}"
    echo -ne "${CYAN}按回车键返回菜单...${NC}"
    read < /dev/tty
}

do_clear() {
    echo -e "\n${RED}[*] 正在清理配置与防火墙...${NC}"
    if [ -f "$CONF_FILE" ]; then
        OLD_IP=$(grep "address=" "$CONF_FILE" | head -n 1 | awk -F'/' '{print $4}')
        # 清理所有相关的 iptables NAT 规则
        iptables -t nat -F OUTPUT 2>/dev/null 
    fi
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 系统已还原${NC}"
    sleep 2
}

do_install() {
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    systemctl enable dnsmasq && systemctl restart dnsmasq
    sleep 1
}

do_check() {
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n${CYAN}按回车返回...${NC}"
    read < /dev/tty
}

[[ $EUID -ne 0 ]] && exit 1
while true; do show_menu; case "$choice" in 1) do_install ;; 2) do_config ;; 3) do_clear ;; 4) do_check ;; 0) exit 0 ;; *) sleep 1 ;; esac; done
