#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ "$0" != "/usr/local/bin/dns" && "$0" != "dns" ]]; then
    cp "$0" /usr/local/bin/dns
    chmod +x /usr/local/bin/dns
fi

GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)

# 仅保留 Copilot 全场景核心域名
AI_DOMAINS=(
  copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com
  githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com
  github.com githubapp.com api.github.com
  openai.com chatgpt.com oaistatic.com oaiusercontent.com
  anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai
)

STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com spotify.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

show_menu() {
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}              DNS 流媒体 & AI 解锁 ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq"
    echo -e "  ${GREEN}2.${NC} 配置解锁规则"
    echo -e "  ${RED}3.${NC} 还原系统配置"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
    read choice < /dev/tty
}

do_install() {
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    systemctl enable dnsmasq && systemctl start dnsmasq
    sleep 1
}

do_config() {
    echo -ne "\n${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}IP 错误${NC}" && sleep 1 && return

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
    systemctl restart dnsmasq
    echo -e "${GREEN}配置已更新${NC}"
    sleep 2
}

do_clear() {
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    sleep 1
}

do_check() {
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n${CYAN}回车返回...${NC}"
    read < /dev/tty
}

[[ $EUID -ne 0 ]] && exit 1
if systemctl is-active --quiet systemd-resolved; then systemctl stop systemd-resolved && systemctl disable systemd-resolved; fi

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
