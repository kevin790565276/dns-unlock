#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- 快捷指令注册 ---
if [[ "$0" != "/usr/local/bin/dns" && "$0" != "dns" ]]; then
    cp "$0" /usr/local/bin/dns && chmod +x /usr/local/bin/dns
    echo -e "${GREEN}[+] 快捷指令 'dns' 注册成功${NC}"
fi

# --- 域名列表 ---
GOOGLE_DOMAINS=(google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com github.com githubapp.com api.github.com openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

get_status() {
    CURRENT_DNS=$(grep "nameserver" $RESOLV_CONF | awk '{print $2}' | head -n 1)
    [ -f "$CONF_FILE" ] && UNLOCK_IP=$(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" $CONF_FILE | tail -n 1) || UNLOCK_IP="未配置"
    [[ "$CURRENT_DNS" == "127.0.0.1" ]] && DNS_STATUS="${GREEN}已接管 (127.0.0.1)${NC}" || DNS_STATUS="${RED}直连 ($CURRENT_DNS)${NC}"
}

show_menu() {
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}            DNS 流媒体 & AI 解锁 (兼容中转版) ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前解锁 DNS: ${YELLOW}${UNLOCK_IP}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq 环境"
    echo -e "  ${GREEN}2.${NC} 配置 DNS 解锁规则 ${YELLOW}(兼容 Realm)${NC}"
    echo -e "  ${RED}3.${NC} 还原系统配置"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测 （by oneclickvirt）"  
    echo -e "  ${PURPLE}5.${NC} 卸载 Dnsmasq 环境"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    echo -ne "${CYAN}请输入选项 [0-5]: ${NC}"
    read choice < /dev/tty
}

do_install() {
    echo -e "\n${YELLOW}[*] 正在安装 Dnsmasq 环境...${NC}"
    apt-get update && apt-get install -y dnsmasq || yum install -y dnsmasq
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 安装成功${NC}"
    sleep 2
}

do_config() {
    echo -ne "\n${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}[!] IP 错误${NC}" && sleep 2 && return

    # 兼容性核心：清理旧规则并设置兜底
    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > $CONF_FILE
    echo "server=1.1.1.1" >> $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do echo "server=/$d/$dns_ip" >> $CONF_FILE; done

    # 核心修复：防止死循环
    sed -i 's/^#conf-dir/conf-dir/' $MAIN_CONF
    grep -q "no-resolv" $MAIN_CONF || echo "no-resolv" >> $MAIN_CONF

    # 锁定 DNS，加入备用服务器防止 Realm 掉线
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    echo "nameserver 8.8.8.8" >> $RESOLV_CONF
    chattr +i $RESOLV_CONF

    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置成功，已兼容 Realm 中转${NC}"
    read -p "按回车返回..." < /dev/tty
}

do_clear() {
    echo -e "\n${YELLOW}[*] 正在还原系统设置...${NC}"
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    rm -f $CONF_FILE
    systemctl restart dnsmasq 2>/dev/null
    echo -e "${GREEN}[+] 还原成功${NC}"
    sleep 2
}

do_check() {
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    read -p "按回车返回..." < /dev/tty
}

do_uninstall() {
    do_clear
    systemctl stop dnsmasq && systemctl disable dnsmasq
    apt-get purge -y dnsmasq || yum remove -y dnsmasq
    rm -rf /etc/dnsmasq.d/ /usr/local/bin/dns
    echo -e "${GREEN}[+] 卸载完成${NC}"
    sleep 2
}

[[ $EUID -ne 0 ]] && exit 1
while true; do
    show_menu
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) do_check ;;
        5) do_uninstall ;;
        0) exit 0 ;;
    esac
done


