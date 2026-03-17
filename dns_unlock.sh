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

    # 1. 恢复系统 IPv6 优先级 (确保原生连接是第一优先级)
    [ -f "/etc/gai.conf" ] && sed -i '/precedence ::ffff:0:0\/96/d' /etc/gai.conf

    # 2. 构造 Dnsmasq 规则
    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > "$CONF_FILE"
    echo "server=2001:4860:4860::8888" >> "$CONF_FILE"

    for d in "${ALL_DOMAINS[@]}"; do 
        # 所有域名映射到解锁 IPv4
        echo "address=/$d/$dns_ip" >> "$CONF_FILE"
        
        # 【核心逻辑】：只对顽固流媒体域名屏蔽 IPv6 解析，强制其退回到 IPv4 解锁通道
        if [[ "$d" =~ (netflix|nflx|google|youtube|ytimg|ggpht|openai|chatgpt|claude|gemini) ]]; then
            echo "address=/$d/::" >> "$CONF_FILE"
        fi
    done

    # 3. 强制锁定 DNS 并锁定
    chattr -i "$RESOLV_CONF" 2>/dev/null
    cat > "$RESOLV_CONF" <<EOF
nameserver 127.0.0.1
nameserver ::1
EOF
    chattr +i "$RESOLV_CONF"
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 针对性屏蔽已生效：流媒体强制走 V4 解锁，其余保持原生 V6${NC}"
    sleep 2
}

do_clear() {
    chattr -i "$RESOLV_CONF" 2>/dev/null
    echo "nameserver 8.8.8.8" > "$RESOLV_CONF"
    rm -f "$CONF_FILE"
    systemctl restart dnsmasq 2>/dev/null
    echo -e "${GREEN}[+] 已还原直连${NC}"
    sleep 2
}

# --- 简单菜单 ---
while true; do
    get_status
    clear
    echo -e "${CYAN}DNS 状态: $DNS_STATUS  解锁 IP: $UNLOCK_IP${NC}"
    echo -e "1. 安装环境\n2. 配置针对性解锁 (推荐)\n3. 还原系统\n4. 运行检测\n0. 退出"
    read -p "选择: " choice < /dev/tty
    case "$choice" in
        1) systemctl stop systemd-resolved; apt-get install -y dnsmasq e2fsprogs ;;
        2) do_config ;;
        3) do_clear ;;
        4) curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash; /usr/bin/ut ;;
        0) exit 0 ;;
    esac
done
