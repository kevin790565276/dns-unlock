🚀 DNS 解锁流媒体一键脚本
📖 使用方法
在你的 （中转机） 上运行以下命令：

```bash
curl -sSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/dns_unlock.sh | tr -d '\r' > dns_unlock.sh && bash dns_unlock.sh
```
🚀 VPS 网络优化脚本 - 支持 TCP 和 UDP

针对 TCP (xhttp, v2ray) 和 UDP (Hysteria 2) 优化的 VPS 网络优化脚本，一键部署，显著提升网络性能。

## 功能特性

- ✅ **BBR 拥塞控制** - TCP 专用优化
- ✅ **TCP 参数优化** - 针对 xhttp, v2ray, vmess
- ✅ **UDP 参数优化** - 针对 Hysteria 2, QUIC
- ✅ **文件描述符优化** - 提升并发连接数
- ✅ **防火墙优化** - UDP 不跟踪，降低延迟
- ✅ **系统日志优化** - 减少磁盘 I/O
- ✅ **中断平衡优化** - 多核 CPU 负载均衡
- ✅ **三种优化模式** - TCP+UDP, 仅TCP, 仅UDP
- ✅ **自动备份** - 修改配置前自动备份
- ✅ **配置还原** - 一键还原到优化前状态
- ✅ **交互式菜单** - 友好的用户界面

## 支持的协议

| 协议类型 | 支持的协议 |
|---------|-----------|
| **TCP** | xhttp, vless, vmess, trojan, shadowsocks |
| **UDP** | Hysteria 2, QUIC |

## 快速开始

### 交互式菜单模式

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize-vps.sh)
```

### 命令行模式

**TCP+UDP 双模式（推荐，适合所有协议）：**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize-vps.sh) --optimize both
```

**仅 TCP 模式（适合 xhttp, v2ray）：**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize-vps.sh) --optimize tcp
```

**仅 UDP 模式（适合 Hysteria 2）：**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize-vps.sh) --optimize udp
```

**还原配置：**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize-vps.sh) --restore
```

