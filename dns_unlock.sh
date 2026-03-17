#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- 路径与文件 ---
CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"

# --- 域名包 (含 AI、流媒体、TikTok 全家桶) ---
ALL_DOMAINS=(
    # AI
    openai.com chatgpt.com oaistatic.com oaiusercontent.com cdn.oaistatic.com
    anthropic.com claude.ai gemini.google.com ai.google.dev aistudio.google.com
    bing.com copilot.microsoft.com perplexity.ai x.ai grok.com mistral.ai
    # Google & YouTube
    google.com google.com.hk google.com.tw google.jp google.com.sg 
    googleapis.com gstatic.com googleusercontent.com googlefonts.com
    youtube.com ytimg.com ggpht.com googlevideo.com youtubei.googleapis.com
    # Netflix & Disney
    netflix.com nflximg.net nflxvideo.net nflxext.com nflxso.net
    disneyplus.com disney-plus.net bamgrid.com primevideo.com amazonvideo.com pv-cdn.net
    # TikTok
    # tiktok.com tiktokv.com byteoversea.com ibytedtos.com ipstatp.com muscdn.com tiktokcdn.com
    # Others
    hulu.com huluim.com peacocktv.com paramountplus.com max.com hbomax.com hbo.com
    gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com 
    abema.tv dmm.com tving.com wavve.com scdn.co
)

# --- 1. 环境安装与清理 ---
do_install() {
    echo -e "\n${YELLOW}[*] 正在准备环境...${NC}"
    # 彻底关掉并卸载可能冲突的服务
    systemctl stop systemd-resolved 2>/dev/null
    systemctl disable systemd-resolved 2>/dev/null
    
    # 安装必要组件
    if command -v apt-get >/dev/null; then
        apt-get update && apt-get install -y dnsmasq e2fsprogs dnsutils
    else
        yum install -y dnsmasq e2fsprogs bind-utils
    fi
    
    # 注册快捷指令
    cp "$0" /usr/local/bin/dns && chmod +x /usr/local/bin/dns
    
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 环境准备完成，快捷指令 'dns' 已生效${NC}"
    sleep 2
}

# --- 2. 核心配置 (降维打击版) ---
do_config() {
    echo -ne "\n${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}[!] IP 格式错误${NC}" && sleep 2 && return

    # 还原 IPv6 优先级，确保系统连接是原生的
    [ -f "/etc/gai.conf" ] && sed -i '/precedence ::ffff:0:0\/96/d' /etc/gai.conf

    # 构造 Dnsmasq 规则
    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > "$CONF_FILE"
    echo "server=2001:4860:4860::8888" >> "$CONF_FILE"

    for d in "${ALL_DOMAINS[@]}"; do 
        echo "address=/$d/$dns_ip" >> "$CONF_FILE"
        # 强制屏蔽流媒体 IPv6 解析，迫使其走 V4 解锁
        if [[ "$d" =~ (netflix|nflx|google|youtube|ytimg|ggpht|openai|chatgpt|claude|gemini|tiktok|byteoversea) ]]; then
            echo "address=/$d/::" >> "$CONF_FILE"
        fi
    done

    # 写入主配置
    cat > "$MAIN_CONF" <<EOF
listen-address=127.0.0.1,::1
no-resolv
conf-dir=/etc/dnsmasq.d/,*.conf
rebind-localhost-ok
EOF
    
    # 接管并锁定 DNS
    chattr -i "$RESOLV_CONF" 2>/dev/null
    echo -e "nameserver 127.0.0.1\nnameserver ::1" > "$RESOLV_CONF"
    chattr +i "$RESOLV_CONF"

    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 配置生效：针对性屏蔽已开启，流媒体强制走 V4 解锁${NC}"
    sleep 2
}

# --- 3. 还原系统 (保留 Dnsmasq 但清空规则) ---
do_restore() {
    echo -e "\n${YELLOW}[*] 正在还原直连设置...${NC}"
    chattr -i "$RESOLV_CONF" 2>/dev/null
    echo "nameserver 8.8.8.8" > "$RESOLV_CONF"
    echo "nameserver 2001:4860:4860::8888" >> "$RESOLV_CONF"
    rm -f "$CONF_FILE"
    systemctl restart dnsmasq 2>/dev/null
    echo -e "${GREEN}[+] 已还原直连状态${NC}"
    sleep 2
}

# --- 4. 彻底卸载 ---
do_uninstall() {
    echo -e "\n${RED}[!] 正在彻底卸载 Dnsmasq 并清理所有配置...${NC}"
    do_restore
    systemctl stop dnsmasq && systemctl disable dnsmasq
    if command -v apt-get >/dev/null; then
        apt-get purge -y dnsmasq
    else
        yum remove -y dnsmasq
    fi
    rm -rf /etc/dnsmasq.d/ /etc/dnsmasq.conf /usr/local/bin/dns
    echo -e "${GREEN}[+] 卸载完成，系统已恢复纯净状态${NC}"
    sleep 2
}

# --- 状态获取 ---
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

# --- 菜单循环 ---
[[ $EUID -ne 0 ]] && echo "请使用 root 运行" && exit 1
while true; do
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}      DNS 全球流媒体 & AI 终极解锁工具箱 ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  系统 DNS 状态: $DNS_STATUS"
    echo -e "  当前解锁 DNS: ${YELLOW}$UNLOCK_IP${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "  ${GREEN}1.${NC} 安装/初始化环境"
    echo -e "  ${GREEN}2.${NC} 开启解锁 ${YELLOW}(针对性屏蔽 v6 模式)${NC}"
    echo -e "  ${BLUE}3.${NC} 还原直连配置 ${PURPLE}(不卸载)${NC}"
    echo -e "  ${CYAN}4.${NC} 运行解锁检测"
    echo -e "  ${RED}5.${NC} 彻底卸载 Dnsmasq 环境"
    echo -e "  ${NC}0. 退出脚本"
    echo -e "${CYAN}==================================================${NC}"
    read -p "请输入选项: " choice < /dev/tty
    case "$choice" in
        1) do_install ;;
        2) do_config ;;
        3) do_restore ;;
        4) curl -sL https://raw.githubusercontent.com/oneclickvirt/UnlockTests/main/ut_install.sh -sSf | bash; /usr/bin/ut; read -p "回车继续..." < /dev/tty ;;
        5) do_uninstall ;;
        0) exit 0 ;;
        *) echo "无效选项" && sleep 1 ;;
    esac
done
