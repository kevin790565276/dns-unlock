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

# --- 彻底修复：状态获取逻辑 ---
get_status() {
    # 1. 获取系统 DNS (resolv.conf)
    CURRENT_DNS=$(grep "nameserver" $RESOLV_CONF | awk '{print $2}' | head -n 1)
    
    # 2. 获取解锁 DNS (直接从配置文件抓取最后一部分)
    if [ -f "$CONF_FILE" ]; then
        # 这里的逻辑是：找最后一行以 server= 开头的，把最后一个 / 之后的内容全部拿出来
        # 例如 server=/google.com/1.1.1.1#53 -> 1.1.1.1#53
        UNLOCK_IP=$(grep "server=" "$CONF_FILE" | tail -n 1 | sed 's|.*/||')
    else
        UNLOCK_IP=""
    fi

    # 3. 状态显示
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

# --- 功能部分 (do_install, do_config, do_clear, do_check 保持之前逻辑) ---

do_install() {
    echo -e "\n${YELLOW}[*] 正在安装 Dnsmasq...${NC}"
    if command -v apt-get >/dev/null; then apt-get update && apt-get install -y dnsmasq; else yum install -y dnsmasq; fi
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 安装完成${NC}"
    sleep 2
}

do_config() {
    echo -e "\n${YELLOW}提示: NAT 端口使用 '#' 分隔 (例: 1.1.1.1#5353)${NC}"
    echo -ne "${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty

    if [[ -z "$dns_ip" ]]; then
        echo -e "${RED}[!] 不能为空${NC}"
        sleep 2 && return
    fi

    echo -e "${YELLOW}[*] 正在写入配置...${NC}"
    sed -i 's/^#conf-dir/conf-dir/' $MAIN_CONF
    grep -q "conf-dir=/etc/dnsmasq.d/,*.conf" $MAIN_CONF || echo "conf-dir=/etc/dnsmasq.d/,*.conf" >> $MAIN_CONF
    
    mkdir -p /etc/dnsmasq.d/
    echo "# Unlock Rules" > $CONF_FILE
    for d in "${GOOGLE_DOMAINS[@]}" "${AI_DOMAINS[@]}" "${STREAMING_DOMAINS[@]}"; do
        echo "server=/$d/$dns_ip" >> $CONF_FILE
    done

    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    
    if systemctl restart dnsmasq; then
        echo -e "${GREEN}[+] 配置成功！${NC}"
        echo -ne "${CYAN}按回车键返回菜单...${NC}"
        read < /dev/tty
    else
        echo -e "${RED}[!] Dnsmasq 重启失败${NC}"
        sleep 2
    fi
}

do_clear() {
    echo -e "\n${RED}[*] 正在清空配置...${NC}"
    rm -f $CONF_FILE
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 8.8.8.8" > $RESOLV_CONF
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 系统已恢复直连状态${NC}"
    sleep 2
}

do_check() {
    echo -e "\n${YELLOW}[*] 正在启动 oneclickvirt 检测...${NC}"
    chattr -i $RESOLV_CONF 2>/dev/null
    echo "nameserver 127.0.0.1" > $RESOLV_CONF
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    [ -f "/usr/bin/ut" ] && /usr/bin/ut || ut
    echo -ne "\n${CYAN}按回车键返回菜单...${NC}"
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
