#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- 快捷指令注册 ---
if [[ "$0" != "/usr/local/bin/dns" && "$0" != "dns" ]]; then
    cp "$0" /usr/local/bin/dns && chmod +x /usr/local/bin/dns
    echo -e "${GREEN}[+] 快捷指令 'dns' 注册成功${NC}"
fi

# --- 全球流媒体 & AI 域名全量包 (支持所有主流平台) ---
ALL_DOMAINS=(
    # AI 服务
    openai.com chatgpt.com oaistatic.com oaiusercontent.com cdn.oaistatic.com
    anthropic.com claude.ai gemini.google.com ai.google.dev aistudio.google.com
    bing.com copilot.microsoft.com perplexity.ai x.ai grok.com mistral.ai
    # 跨国流媒体
    netflix.com nflximg.net nflxvideo.net nflxext.com nflxso.net
    disneyplus.com disney-plus.net bamgrid.com primevideo.com amazonvideo.com pv-cdn.net
    youtube.com ytimg.com ggpht.com googlevideo.com youtubei.googleapis.com
    tiktok.com tiktokv.com byteoversea.com
    hulu.com huluim.com peacocktv.com paramountplus.com max.com hbomax.com hbo.com
    # 地区流媒体
    gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com 
    abema.tv dmm.com tving.com wavve.com scdn.co spotify.com
    # Google 基础
    google.com google.com.hk google.com.tw google.jp google.com.sg 
    googleapis.com gstatic.com googleusercontent.com googlefonts.com
)

CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

get_status() {
    # 修正显示 Bug：直接检查文件内容判断接管状态
    if grep -q "127.0.0.1" "$RESOLV_CONF" 2>/dev/null; then
        DNS_STATUS="${GREEN}已接管 (Dual-Stack)${NC}"
    else
        CURRENT_DNS=$(grep "nameserver" "$RESOLV_CONF" | awk '{print $2}' | head -n 1)
        [ -z "$CURRENT_DNS" ] && CURRENT_DNS="未知"
        DNS_STATUS="${RED}直连 ($CURRENT_DNS)${NC}"
    fi

    # 抓取当前解锁 IP
    if [ -f "$CONF_FILE" ]; then
        UNLOCK_IP=$(grep "address=" "$CONF_FILE" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
    fi
    [ -z "$UNLOCK_IP" ] && UNLOCK_IP="未配置"
}

show_menu() {
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}      DNS 全球流媒体 & AI 解锁 (终极双栈版) ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前解锁 DNS: ${YELLOW}${UNLOCK_IP}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 Dnsmasq 环境 (并清理冲突)"
    echo -e "  ${GREEN}2.${NC} 配置解锁规则 (V4 解锁 + V6 原生)"
    echo -e "  ${RED}3.${NC} 还原系统配置 (强制解锁并恢复直连)"
    echo -e "  ${YELLOW}4.${NC} 运行解锁检测"  
    echo -e "  ${PURPLE}5.${NC} 卸载 Dnsmasq 环境"
    echo -e "  ${BLUE}0.${NC} 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    echo -ne "${CYAN}请输入选项 [0-5]: ${NC}"
    read choice < /dev/tty
}

do_install() {
    echo -e "\n${YELLOW}[*] 正在准备环境并清理 systemd-resolved...${NC}"
    systemctl stop systemd-resolved 2>/dev/null
    systemctl disable systemd-resolved 2>/dev/null
    apt-get update && apt-get install -y dnsmasq e2fsprogs dnsutils || yum install -y dnsmasq e2fsprogs bind-utils
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 环境准备完成${NC}"
    sleep 2
}

do_config() {
    echo -ne "\n${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}[!] IP 格式错误${NC}" && sleep 2 && return

    # 1. 强制系统 IPv4 优先 (解决原生 v6 干扰)
    if [ -f "/etc/gai.conf" ]; then
        sed -i '/precedence ::ffff:0:0\/96/d' /etc/gai.conf
        echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
    fi

    # 2. 构造规则 (只写 A 记录映射，AAAA 记录自动走上游原生)
    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > "$CONF_FILE"
    echo "server=2001:4860:4860::8888" >> "$CONF_FILE"
    for d in "${ALL_DOMAINS[@]}"; do 
        echo "address=/$d/$dns_ip" >> "$CONF_FILE"
    done

    # 3. 强制刷新主配置
    cat > "$MAIN_CONF" <<EOF
listen-address=127.0.0.1,::1
no-resolv
conf-dir=/etc/dnsmasq.d/,*.conf
rebind-localhost-ok
EOF
    
    # 4. 暴力接管 DNS 并锁定
    chattr -i "$RESOLV_CONF" 2>/dev/null
    cat > "$RESOLV_CONF" <<EOF
nameserver 127.0.0.1
nameserver ::1
EOF
    chattr +i "$RESOLV_CONF"

    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置生效：IPv4 已映射，IPv6 保持原生${NC}"
    sleep 2
}

do_clear() {
    echo -e "\n${YELLOW}[*] 正在彻底解除锁定并还原系统设置...${NC}"
    chattr -i "$RESOLV_CONF" 2>/dev/null
    cat > "$RESOLV_CONF" <<EOF
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
EOF
    [ -f "/etc/gai.conf" ] && sed -i '/precedence ::ffff:0:0\/96/d' /etc/gai.conf
    rm -f "$CONF_FILE"
    systemctl restart dnsmasq 2>/dev/null
    echo -e "${GREEN}[+] 还原成功，已恢复直连状态${NC}"
    sleep 2
}

do_check() {
    curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash
    /usr/bin/ut
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
