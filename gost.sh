#!/bin/bash

# 1. 基础环境清理
echo "正在清理环境..."
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null
systemctl stop dnsmasq 2>/dev/null
systemctl disable dnsmasq 2>/dev/null

# 2. 下载并安装 Gost
echo "正在安装 Gost..."
ARCH=$(uname -m)
GOST_VER="2.11.5"
if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-amd64-$GOST_VER.gz"
else
    URL="https://github.com/ginuerzh/gost/releases/download/v$GOST_VER/gost-linux-armv8-$GOST_VER.gz"
fi

wget -qO- $URL | gzip -d > /usr/local/bin/gost
chmod +x /usr/local/bin/gost

# 3. 写入 Systemd 服务 (核心逻辑：使用 DoT 彻底解决回环和劫持)
echo "正在配置服务..."
cat << EOF > /etc/systemd/system/gost-dns.service
[Unit]
Description=Gost DNS Unlock Service
After=network.target

[Service]
Type=simple
# 使用加密 DoT 请求 Google DNS，强制获取真实 IP
ExecStart=/usr/local/bin/gost -L udp://:53?dns=dot://8.8.8.8:853
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 4. 启动服务
systemctl daemon-reload
systemctl enable gost-dns
systemctl restart gost-dns

# 5. 输出状态与结果
IP=$(curl -s ifconfig.me)
echo "------------------------------------------------"
echo "部署成功！"
echo "你的落地机解析服务已上线。"
echo "落地机 IP: $IP"
echo "请在中转机测试: nslookup netflix.com $IP"
echo "------------------------------------------------"
systemctl status gost-dns --no-pager
