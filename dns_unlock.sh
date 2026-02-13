#!/bin/bash

# --- 1. 域名列表 ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com bard.google.com makeresuite.google.com perplexity.ai mistral.ai x.ai grok.com bing.com edgeservices.microsoft.com)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com spotify.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

# --- 2. 基础修复函数 ---
fix_env() {
    echo "正在修复环境..."
    # 强制恢复上网能力，防止脚本下载失败
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    
    # 解决 Ubuntu 端口占用 (systemd-resolved)
    if systemctl is-active --quiet systemd-resolved; then
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
    fi
}

do_install() {
    echo "正在安装 Dnsmasq..."
    if command -v apt-get >/dev/null; then
        apt-get update && apt-get install -y dnsmasq
    else
        yum install -y dnsmasq
    fi
    systemctl enable dnsmasq && systemctl start dnsmasq
}

do_config() {
    read -p "请输入解锁 DNS IP: " dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "IP 格式错误" && return

    # 修复主配置文件 dnsmasq.conf (去掉注释，添加保底DNS)
    sed -i 's/^#conf-dir/conf-dir/' $MAIN_CONF
    if ! grep -q "conf-dir=/etc/dnsmasq.d/,*.conf" $MAIN_CONF; then
        echo "conf-dir=/etc/dnsmasq.d/,*.conf" >> $MAIN_CONF
    fi
    if ! grep -q "server=8.8.8.8" $MAIN_CONF; then
        echo "server=8.8.8.8" >> $MAIN_CONF
        echo "server=1.1.1.1" >> $MAIN_CONF
    fi

    # 写入分流规则
    mkdir -p /etc/dnsmasq.d/
    echo "# Unlock" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$d/$dns_ip" >> $CONF_FILE
    done

    # 接管系统 DNS
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    systemctl restart dnsmasq
    echo "配置成功！"
}

# --- 3. 菜单 ---
fix_env
while true; do
    echo "1. 安装 | 2. 配置解锁 | 3. 还原 | 4. 退出"
    read -p "选择: " choice < /dev/tty
    case $choice in
        1) do_install ;;
        2) do_config ;;
        3) rm -f $CONF_FILE && echo "nameserver 8.8.8.8" > $RESOLV_CONF && systemctl restart dnsmasq ;;
        4) exit 0 ;;
    esac
done
