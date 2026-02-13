#!/bin/bash

# 强制转换换行符：如果脚本被 Windows 污染，这行会尝试清理当前进程环境
# 这种“防御性”写法可以规避大部分由于 \r 导致的语法错误
export LANG=en_US.UTF-8

# 域名列表
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com bard.google.com makeresuite.google.com perplexity.ai mistral.ai x.ai grok.com bing.com edgeservices.microsoft.com)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com spotify.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
RESOLV_CONF="/etc/resolv.conf"

# 检查 Root 权限
if [[ $EUID -ne 0 ]]; then
   echo "错误：必须使用 root 权限运行！"
   exit 1
fi

show_menu() {
    echo "=================================="
    echo "    DNS Unlocker (Fixed Edition)"
    echo "=================================="
    echo "1. 安装 Dnsmasq"
    echo "2. 配置解锁 DNS"
    echo "3. 一键还原配置"
    echo "4. 退出"
    echo "=================================="
    printf "请选择 [1-4]: "
    read choice
}

do_install() {
    echo "正在安装 Dnsmasq..."
    if command -v apt-get >/dev/null; then
        apt-get update && apt-get install -y dnsmasq
    elif command -v yum >/dev/null; then
        yum install -y dnsmasq
    fi
    systemctl enable dnsmasq && systemctl start dnsmasq
    echo "安装完成。"
}

do_config() {
    printf "请输入解锁 DNS IP: "
    read dns_ip
    if [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP 格式无效！"
        return
    fi

    mkdir -p /etc/dnsmasq.d/
    echo "# Unlock Rules" > $CONF_FILE
    
    # 写入规则
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$d/$dns_ip" >> $CONF_FILE
    done

    # 设置系统 DNS
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    systemctl restart dnsmasq
    echo "配置已生效！系统 DNS 已指向 127.0.0.1"
}

do_clear() {
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo "配置已还原。"
}

while true; do
    show_menu
    case $choice in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done
