#!/bin/bash

# ====================================================
# Dnsmasq Streaming/AI/Google Unlock Script
# ====================================================

# 域名列表
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com bard.google.com makeresuite.google.com perplexity.ai mistral.ai x.ai grok.com bing.com edgeservices.microsoft.com)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com spotify.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
RESOLV_CONF="/etc/resolv.conf"

color_echo() {
    echo -e "\033[1;32m$1\033[0m"
}

show_menu() {
    echo "----------------------------------"
    echo "    VPS DNS 解锁一键脚本"
    echo "----------------------------------"
    echo "1. 安装 Dnsmasq"
    echo "2. 配置解锁 DNS (自动接管系统)"
    echo "3. 一键还原 (恢复默认 DNS)"
    echo "4. 退出"
    echo "----------------------------------"
    read -p "选择 [1-4]: " choice
}

install_dnsmasq() {
    color_echo "正在安装 Dnsmasq..."
    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y dnsmasq
    elif [ -f /etc/redhat-release ]; then
        yum install -y dnsmasq
    fi
    systemctl enable dnsmasq && systemctl start dnsmasq
    color_echo "安装成功！"
}

setup_rules() {
    read -p "请输入解锁 DNS 地址: " unlock_dns
    if [[ ! $unlock_dns =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "错误: IP 格式无效"; return
    fi

    mkdir -p /etc/dnsmasq.d/
    echo "# Unlock Rules" > $CONF_FILE

    write_to_conf() {
        for domain in "$@"; do
            echo "server=/$domain/$unlock_dns" >> $CONF_FILE
        done
    }

    write_to_conf "${GOOGLE_DOMAINS[@]}"
    write_to_conf "${AI_DOMAINS[@]}"
    write_to_conf "${STREAMING_DOMAINS[@]}"

    # 修改系统解析地址
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    # 锁定防止系统自动重置 (可选)
    # chattr +i $RESOLV_CONF 

    systemctl restart dnsmasq
    color_echo "解锁配置已生效！"
}

clear_config() {
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    color_echo "已清理配置并还原为 8.8.8.8"
}

while true; do
    show_menu
    case $choice in
        1) install_dnsmasq ;;
        2) setup_rules ;;
        3) clear_config ;;
        4) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done