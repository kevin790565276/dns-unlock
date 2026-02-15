#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 自动安装快捷指令 ---
if [[ "$0" != "/usr/local/bin/dns" && "$0" != "dns" ]]; then
    cp "$0" /usr/local/bin/dns
    chmod +x /usr/local/bin/dns
    echo -e "${GREEN}[+] 快捷指令 'dns' 注册成功${NC}"
fi

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
        # 提取 IP 或 IP#端口 格式
        UNLOCK_IP=$(grep "server=" $CONF_FILE | head -n 1 | cut -d'/' -f4)
    else
        UNLOCK_IP="未配置"
    fi

    if [[ "$CURRENT_DNS" == "127.0.0.1" ]]; then
        DNS_STATUS="${GREEN}已接管 (127.0.0.1)${NC}"
    else
        DNS_STATUS="${RED}直连 ($CURRENT_DNS)${NC}"
    fi
}

show_menu() {
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}              DNS 流媒体 & AI 解锁 ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前解锁 DNS: ${YELLOW}${UNLOCK_IP:-未配置}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq 环境"
    echo -e "  ${GREEN}2.${NC} 配置 DNS 解锁添加规则"
    echo -e "  ${RED}3.${NC} 还原系统配置"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测 ${CYAN}(by oneclickvirt)${NC}"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
    read choice < /dev/tty
}

do_install() {
    echo -e "\n${YELLOW}[*] 正在安装 Dnsmasq 环境...${NC}"
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    if systemctl enable dnsmasq && systemctl restart dnsmasq; then
        echo -e "${GREEN}[+] Dnsmasq 服务安装并启动成功${NC}"
    else
        echo -e "${RED}[!] 启动失败，请检查端口 53${NC}"
    fi
    sleep 2
}

do_config() {
    echo -e "\n${YELLOW}提示: 普通小鸡输入 IP 即可 (例: 1.1.1.1)${NC}"
    echo -e "${YELLOW}      NAT 小鸡请输入 IP#端口 (例: 1.1.1.1#5353)${NC}"
    echo -ne "${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty

    # 放宽正则检查，只要包含 IP 结构即可
    if [[ ! $dns_ip =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo -e "${RED}[!] IP 格式错误${NC}"
        sleep 2 && return
    fi

    echo -e "${YELLOW}[*] 正在写入配置...${NC}"
    sed -i 's/^#conf-dir/conf-dir/' $MAIN_CONF
    grep -q "conf-dir=/etc/dnsmasq.d/,*.conf" $MAIN_CONF || echo "conf-dir=/etc/dnsmasq.d/,*.conf" >> $MAIN_CONF
    grep -q "server=8.8.8.8" $MAIN_CONF || { echo "server=8.8.8.8" >> $MAIN_CONF; echo "server=8.8.4.4" >> $MAIN_CONF; }

    mkdir -p /etc/dnsmasq.d/
    echo "# Unlock Rules" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$d/$dns_ip" >> $CONF_FILE
    done

    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    if systemctl restart dnsmasq; then
        echo -e "${GREEN}[+] 解锁规则配置成功！${NC}"
        echo -ne "\n${CYAN}按回车键返回菜单...${NC}"
        read < /dev/tty
    else
        echo -e "${RED}[!] 规则生效失败${NC}"
        sleep 2
    fi
}

do_clear() {
    echo -e "\n${YELLOW}[*] 正在还原...${NC}"
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 系统 DNS 已还原${NC}"
    sleep 2
}

do_check() {
    echo -e "\n${YELLOW}[*] 正在加载 oneclickvirt 检测环境...${NC}"
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    echo -e "${GREEN}[+] 检测工具启动成功...${NC}\n"
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n${CYAN}检测结束，按回车键返回菜单...${NC}"
    read < /dev/tty
}

[[ $EUID -ne 0 ]] && exit 1
if systemctl is-active --quiet systemd-resolved; then 
    systemctl stop systemd-resolved && systemctl disable systemd-resolved
fi

while true; do
    show_menu
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) do_check ;;
        0) exit 0 ;;
        *) sleep 1 ;;
    esac
done
