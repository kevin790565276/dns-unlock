#!/bin/bash

# --- 域名列表 ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com bard.google.com makeresuite.google.com perplexity.ai mistral.ai x.ai grok.com bing.com edgeservices.microsoft.com)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com spotify.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
RESOLV_CONF="/etc/resolv.conf"

# 检查 Root
[[ $EUID -ne 0 ]] && echo "Error: 请使用 root 用户运行此脚本。" && exit 1

show_menu() {
    echo "=============================="
    echo "    DNS Unlocker for VPS"
    echo "=============================="
    echo "1. 安装 Dnsmasq"
    echo "2. 配置解锁 DNS (接管系统)"
    echo "3. 一键还原配置"
    echo "4. 退出"
    echo "=============================="
    printf "请选择 [1-4]: "
    read choice
}

do_install() {
    echo "正在安装 Dnsmasq..."
    if command -v apt-get >/dev/null; then
        apt-get update && apt-get install -y dnsmasq
    elif command -v yum >/dev/null; then
        yum install -y dnsmasq
    else
        echo "暂不支持此系统发行版。"
        return
    fi
    systemctl enable dnsmasq && systemctl start dnsmasq
    echo "Dnsmasq 已就绪。"
}

do_config() {
    printf "请输入你的解锁 DNS 地址 (如 1.2.3.4): "
    read dns_ip
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "无效的 IP 地址。" && return

    mkdir -p /etc/dnsmasq.d/
    echo "# Streaming & AI Unlock" > $CONF_FILE

    # 循环写入所有规则
    for domain in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$domain/$dns_ip" >> $CONF_FILE
    done

    # 强制修改系统 DNS 指向本地
    [ -f $RESOLV_CONF ] && chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    systemctl restart dnsmasq
    echo "配置已应用！系统 DNS 已设为 127.0.0.1。"
}

do_clear() {
    echo "正在恢复原始配置..."
    rm -f $CONF_FILE
    [ -f $RESOLV_CONF ] && chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo "系统已恢复使用 8.8.8.8。"
}

while true; do
    show_menu
    case $choice in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) exit 0 ;;
        *) echo "无效选项，请重新选择。" ;;
    esac
done
