#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 自动安装为系统快捷指令 ---
if [[ "$0" != "/usr/local/bin/dns" && "$0" != "dns" ]]; then
    cp "$0" /usr/local/bin/dns
    chmod +x /usr/local/bin/dns
    echo -e "${GREEN}[+] 已自动创建快捷指令：直接输入 'dns' 即可启动${NC}"
fi

# --- 域名列表 ---
GOOGLE_DOMAINS=(google.com google.com.hk google.com.tw google.jp google.co.jp google.com.sg googleapis.com gstatic.com googleusercontent.com drive.google.com mail.google.com android.com play.google.com developer.android.com google-analytics.com googleadservices.com googletagmanager.com googlefonts.com gvt1.com)
AI_DOMAINS=(openai.com chatgpt.com oaistatic.com oaiusercontent.com anthropic.com claude.ai gemini.google.com bard.google.com makeresuite.google.com perplexity.ai mistral.ai x.ai grok.com bing.com edgeservices.microsoft.com)
STREAMING_DOMAINS=(netflix.com nflximg.net nflxvideo.net nflxext.com disneyplus.com disney-plus.net bamgrid.com max.com hbomax.com hbo.com hbonow.com primevideo.com amazonvideo.com hulu.com huluim.com peacocktv.com paramountplus.com gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com abema.tv ds-msn.com tving.com wavve.com spotify.com scdn.co)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

# --- UI 函数 ---
draw_line() { echo -e "${CYAN}==================================================${NC}"; }

show_menu() {
    clear
    draw_line
    echo -e "${PURPLE}          DNS 流媒体一键解锁助手 ${NC}"
    echo -e "${CYAN}    快捷指令: 直接输入 'dns' 即可启动${NC}"
    draw_line
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq 环境"
    echo -e "  ${GREEN}2.${NC} 配置分流解锁规则"
    echo -e "  ${RED}3.${NC} 还原系统配置"
    echo -e "  ${YELLOW}4.${NC} 运行流媒体解锁检测 ${YELLOW}(UnlockTests)${NC}"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    draw_line
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
    read choice < /dev/tty
}

do_install() {
    echo -e "\n${YELLOW}[*] 正在安装 Dnsmasq...${NC}"
    if command -v apt-get >/dev/null; then
        apt-get update && apt-get install -y dnsmasq
    else
        yum install -y dnsmasq
    fi
    systemctl enable dnsmasq && systemctl start dnsmasq
    echo -e "${GREEN}[+] 安装成功!${NC}"
    sleep 2
}

do_config() {
    echo -ne "\n${CYAN}请输入解锁 DNS IP: ${NC}"
    read dns_ip < /dev/tty
    if [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}[!] IP 格式错误!${NC}"
        sleep 2 && return
    fi

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
    echo -e "${GREEN}[+] 配置大功告成!${NC}"
    sleep 2
}

do_clear() {
    echo -e "\n${RED}[*] 正在恢复初始状态...${NC}"
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 还原完成。${NC}"
    sleep 2
}

do_check() {
    echo -e "\n${YELLOW}[*] 正在配置检测环境...${NC}"
    # 确保当前 DNS 正在工作
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    # 1. 下载并安装 (UnlockTests)
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    
    # 2. 关键修复：直接运行安装后的二进制文件
    # oneclickvirt 通常安装在 /usr/bin/ut 或通过别名运行
    if [ -f "/usr/bin/ut" ]; then
        /usr/bin/ut
    else
        # 如果是 alias 方式，尝试直接用 ut 运行
        ut
    fi
    
    echo -e "\n${CYAN}检测完成，按回车键返回菜单...${NC}"
    read < /dev/tty
}

# --- 启动环境检查 ---
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 运行${NC}" && exit 1
if systemctl is-active --quiet systemd-resolved; then
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
fi

# --- 循环主程序 ---
while true; do
    show_menu
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_clear ;;
        4) do_check ;;
        0) echo -e "${BLUE}再见!${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项!${NC}"; sleep 1 ;;
    esac
done
