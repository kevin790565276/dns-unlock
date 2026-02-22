#!/bin/bash

# --- 颜色与路径定义 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

# --- 域名列表 (保持不变) ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(copilot.microsoft.com bing.com bing.com.hk edgeservices.microsoft.com githubcopilot.com api.githubcopilot.com copilot-proxy.githubusercontent.com github.com githubapp.com api.github.com openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com perplexity.ai x.ai grok.com mistral.ai)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com scdn.co)

[[ $EUID -ne 0 ]] && exit 1

do_install() {
    echo -e "${YELLOW}[*] 安装 Dnsmasq...${NC}"
    apt-get update && apt-get install -y dnsmasq || yum install -y dnsmasq
    systemctl enable dnsmasq
    echo -e "${GREEN}[+] 安装成功${NC}"
}

do_config() {
    echo -ne "${CYAN}请输入解锁 DNS IP: ${NC}"
    read dns_ip
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}[!] IP 格式错误${NC}" && return

    # 1. 核心修复：基础解析兜底
    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > $CONF_FILE
    echo "server=1.1.1.1" >> $CONF_FILE
    
    # 2. 写入解锁规则
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$d/$dns_ip" >> $CONF_FILE
    done

    # 3. 核心修复：防止 DNS 回环
    sed -i 's/^#conf-dir/conf-dir/' $MAIN_CONF
    grep -q "no-resolv" $MAIN_CONF || echo "no-resolv" >> $MAIN_CONF

    # 4. 核心修复：双解析备份，防止断网
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    echo "nameserver 8.8.8.8" >> $RESOLV_CONF
    chattr +i $RESOLV_CONF

    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置完成，中转与解锁已兼容${NC}"
}

do_uninstall() {
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl stop dnsmasq && apt-get purge -y dnsmasq || yum remove -y dnsmasq
    rm -f $CONF_FILE
    echo -e "${GREEN}[+] 卸载成功，系统 DNS 已还原${NC}"
}

# 简易菜单
echo -e "${CYAN}1.安装 2.配置解锁 3.卸载${NC}"
read -p "选择: " opt
case $opt in
    1) do_install ;;
    2) do_config ;;
    3) do_uninstall ;;
esac
