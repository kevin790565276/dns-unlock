#!/bin/bash

# ==================================================
# 项目名称: OmniUnlock (全球流媒体 & AI 终极解锁工具箱)
# 版本号:   V1.1
# 功能:     基于 Dnsmasq 的针对性 IPv6 屏蔽与 IPv4 解锁分流
# ==================================================

# --- 颜色定义 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- 路径与文件 ---
CONF_FILE="/etc/dnsmasq.d/unlock.conf"
MAIN_CONF="/etc/dnsmasq.conf"
RESOLV_CONF="/etc/resolv.conf"
VERSION="V1.1"

# --- 域名包 (不含 TikTok & YouTube，确保其原生直连) ---
ALL_DOMAINS=(
    # AI & Search
    openai.com chatgpt.com oaistatic.com oaiusercontent.com sora.com anthropic.com claude.ai
    gemini.google.com ai.google.dev aistudio.google.com google.com.ai meta.ai
    bing.com copilot.microsoft.com perplexity.ai x.ai grok.com mistral.ai
    google.com google.com.hk google.com.tw google.jp google.com.sg googleapis.com gstatic.com
    # Global Streaming
    netflix.com nflximg.net nflxvideo.net nflxext.com nflxso.net disneyplus.com disney-plus.net bamgrid.com
    primevideo.com amazonvideo.com pv-cdn.net
    hulu.com huluim.com peacocktv.com paramountplus.com max.com hbomax.com hbo.com discovery.com dazn.com
    # Regional (JP/HK/TW/SEA)
    abema.tv dmm.com niconico.jp nicovideo.jp nhk.jp tver.jp u-next.jp dアニメストア.jp
    videomarket.jp fod.fujitv.co.jp radiko.jp lemino.docomo.ne.jp mgs-video.jp telasa.jp wowow.co.jp
    gamer.com.tw bahamut.com.tw viu.com viu.tv mytvsuper.com tvb.com hoy.tv hami.video catchplay.com
    friday.tw 4gtv.tv kktv.me linetv.tw ofiii.com iq.com hotstar.com kfs.io
    # Social & Others
    instagram.com fbcdn.net bilibili.com steam-chat.com
)

# --- 状态获取逻辑 (修复显示残留问题) ---
get_status() {
    if grep -q "127.0.0.1" "$RESOLV_CONF" 2>/dev/null; then
        DNS_STATUS="${GREEN}已接管 (Dual-Stack)${NC}"
        if [ -f "$CONF_FILE" ]; then
            UNLOCK_IP=$(grep "address=" "$CONF_FILE" | grep -v "::" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
        else
            UNLOCK_IP="${YELLOW}配置未就绪${NC}"
        fi
    else
        DNS_STATUS="${RED}直连 ($(grep "nameserver" "$RESOLV_CONF" | awk '{print $2}' | head -n 1))${NC}"
        UNLOCK_IP="${NC}无 (已还原/直连)${NC}"
    fi
    [ -z "$UNLOCK_IP" ] && UNLOCK_IP="N/A"
}

# --- 1. 环境安装 ---
do_install() {
    echo -e "\n${YELLOW}[*] 正在准备环境...${NC}"
    systemctl stop systemd-resolved 2>/dev/null
    systemctl disable systemd-resolved 2>/dev/null
    apt-get update && apt-get install -y dnsmasq e2fsprogs dnsutils || yum install -y dnsmasq e2fsprogs bind-utils
    cp "$0" /usr/local/bin/dns && chmod +x /usr/local/bin/dns
    systemctl enable dnsmasq && systemctl restart dnsmasq
    echo -e "${GREEN}[+] 安装完成，快捷指令 'dns' 已生效${NC}"
    sleep 2
}

# --- 2. 开启解锁 ---
do_config() {
    echo -ne "\n${CYAN}请输入解锁 IP: ${NC}"
    read dns_ip < /dev/tty
    [[ ! $dns_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo -e "${RED}[!] 格式错误${NC}" && sleep 2 && return

    mkdir -p /etc/dnsmasq.d/
    echo "server=8.8.8.8" > "$CONF_FILE"
    echo "server=2001:4860:4860::8888" >> "$CONF_FILE"

    for d in "${ALL_DOMAINS[@]}"; do 
        echo "address=/$d/$dns_ip" >> "$CONF_FILE"
        if [[ "$d" =~ (netflix|nflx|google|openai|chatgpt|claude|gemini|disney|hulu|hbo|dmm|abema|viu|gamer|bahamut) ]]; then
            echo "address=/$d/::" >> "$CONF_FILE"
        fi
    done

    cat > "$MAIN_CONF" <<EOF
listen-address=127.0.0.1,::1
no-resolv
conf-dir=/etc/dnsmasq.d/,*.conf
rebind-localhost-ok
EOF
    
    chattr -i "$RESOLV_CONF" 2>/dev/null
    echo -e "nameserver 127.0.0.1\nnameserver ::1" > "$RESOLV_CONF"
    chattr +i "$RESOLV_CONF"
    systemctl restart dnsmasq
    echo -e "${GREEN}[+] 解锁规则已生效 (TikTok/YouTube 已保持原生直连)${NC}"
    sleep 2
}

# --- 3. 还原系统 ---
do_restore() {
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
    do_restore
    systemctl stop dnsmasq && systemctl disable dnsmasq
    apt-get purge -y dnsmasq || yum remove -y dnsmasq
    rm -rf /etc/dnsmasq.d/ /etc/dnsmasq.conf /usr/local/bin/dns
    echo -e "${GREEN}[+] 卸载完成${NC}"
    sleep 2
}

# --- 主菜单 ---
[[ $EUID -ne 0 ]] && echo "请使用 root 运行" && exit 1
while true; do
    get_status
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${PURPLE}    OmniUnlock $VERSION - 全球流媒体 & AI 工具箱 ${NC}"
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
    esac
done
