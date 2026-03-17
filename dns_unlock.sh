#!/bin/bash

# --- 颜色与路径 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

# --- 全量域名包 ---
ALL_DOMAINS=(
    # AI & Google
    openai.com chatgpt.com oaistatic.com oaiusercontent.com cdn.oaistatic.com
    anthropic.com claude.ai gemini.google.com ai.google.dev aistudio.google.com
    bing.com copilot.microsoft.com perplexity.ai x.ai grok.com mistral.ai
    google.com google.com.hk google.com.tw google.jp google.com.sg 
    googleapis.com gstatic.com googleusercontent.com googlefonts.com
    # Streaming & Video
    netflix.com nflximg.net nflxvideo.net nflxext.com nflxso.net
    disneyplus.com disney-plus.net bamgrid.com primevideo.com amazonvideo.com pv-cdn.net
    youtube.com ytimg.com ggpht.com googlevideo.com youtubei.googleapis.com
    tiktok.com tiktokv.com byteoversea.com
    hulu.com huluim.com peacocktv.com paramountplus.com max.com hbomax.com hbo.com
    # Regional
    gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com 
    abema.tv dmm.com tving.com wavve.com scdn.co
)

# --- 快捷指令 ---
if [[ "$0" != "/usr/local/bin/dns" && "$0" != "dns" ]]; then
    cp "$0" /usr/local/bin/dns && chmod +x /usr/local/bin/dns
fi

get_status() {
    if grep -q "127.0.0.1" "$RESOLV_CONF" 2>/dev/null; then
        DNS_STATUS="${GREEN}已接管 (Dual-Stack)${NC}"
    else
        CURRENT_DNS=$(grep "nameserver" "$RESOLV_CONF" | awk '{print $2}' | head -n 1)
        DNS_STATUS="${RED}直连 ($CURRENT_DNS)${NC}"
    fi
    [ -f "$CONF_FILE" ] && UNLOCK_IP=$(grep "address=" "$CONF_FILE" | grep -v "::" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
    [ -z "$UNLOCK_IP" ] && UNLOCK_IP="未配置"
}

do_config() {
    echo -ne "\n${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}[!] 格式错误${NC}" && sleep 2 && return

    # 1. 环境清理：确保不禁用系统 IPv6，且恢复默认优先级
    [ -f "/etc/gai.conf" ] && sed -i '/precedence ::ffff:0:0\/96/d' /etc/gai.conf

    # 2. 构造 Dnsmasq 规则
    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > "$CONF_FILE"
    echo "server=2001:4860:4860::8888" >> "$CONF_FILE"

    for d in "${ALL_DOMAINS[@]}"; do 
        # 写入 IPv4 映射
        echo "address=/$d/$dns_ip" >> "$CONF_FILE"
        # 针对顽固域名，屏蔽其 IPv6 解析，迫使其退回 IPv4 连接
        if [[ "$d" =~ (netflix|nflx|google|youtube|ytimg|ggpht|openai|chatgpt|claude|gemini|tiktok) ]]; then
            echo "address=/$d/::" >> "$CONF_FILE"
        fi
    done

    # 3. 写入主配置
    cat > "$MAIN_CONF" <<EOF
listen-address=127.0.0.1,::1
no-resolv
conf-dir=/etc/dnsmasq.d/,*.conf
rebind-localhost-ok
EOF
    
    # 4. 暴力锁定 DNS
    chattr -i "$RESOLV_CONF" 2>/dev/null
    echo -e "nameserver 127.0.0.1\nnameserver ::1" > "$RESOLV_CONF"
    chattr +i "$RESOLV_CONF"

    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置生效：已针对流媒体屏蔽 IPv6 解析，其余保持原生。${NC}"
    sleep 2
}

do_clear() {
    chattr -i "$RESOLV_CONF" 2>/dev/null
    echo "nameserver 8.8.8.8" > "$RESOLV_CONF"
    rm -f "$CONF_FILE"
    systemctl restart dnsmasq 2>/dev/null
    echo -e "${GREEN}[+] 已还原直连状态${NC}"
    sleep 2
}

# --- 菜单界面 ---
while true; do
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  DNS 状态: $DNS_STATUS"
    echo -e "  解锁 IP: ${YELLOW}$UNLOCK_IP${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装/清理环境"
    echo -e "  ${GREEN}2.${NC} 配置针对性解锁 (保住原生 IPv6)"
    echo -e "  ${RED}3.${NC} 还原系统"
    echo -e "  ${YELLOW}4.${NC} 运行检测"
    echo -e "  ${BLUE}0.${NC} 退出"
    echo -e "${CYAN}==================================================${NC}"
    read -p "选择 [0-4]: " choice < /dev/tty
    case "$choice" in
        1) systemctl stop systemd-resolved; apt-get install -y dnsmasq e2fsprogs ;;
        2) do_config ;;
        3) do_clear ;;
        4) curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash; /usr/bin/ut ;;
        0) exit 0 ;;
    esac
done
