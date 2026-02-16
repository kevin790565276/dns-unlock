# 🛠️ VPS 全能工具箱

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Debian%20|%20Ubuntu%20|%20CentOS-orange.svg)](#)

本仓库集成了网络深度优化与 DNS 流媒体解锁脚本，旨在提升高延迟线路的使用体验。

---

## 🚀 1. 全球网络深度优化脚本

针对 **高延迟、绕路长** 的线路（如德国、美国、台湾广播 IP）进行内核调优。特别优化了 **Hysteria 2 (Hy2)** 的 UDP 吞吐性能。

### ✨ 功能特性
* **拥塞算法**: 强制开启 `TCP BBR` + `FQ` 调度。
* **UDP 强化**: 深度优化接收缓冲区，专为 Hysteria 2 打造。
* **高并发**: 提升 `somaxconn`，解决跨国长链路握手卡顿。
* **长肥网络优化**: 扩充 TCP 窗口至 `64MB`，榨干带宽。

### 🛠️ 一键安装
```bash
curl -sL [https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize.sh](https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/optimize.sh) | sudo bash

📺 2. DNS 解锁流媒体脚本
这是一个用于解锁流媒体的 DNS 服务端脚本。已经配好流媒体、AI 分流（不包含 YouTube）。

📖 使用方法
在你的 （中转机/解锁机） 上运行以下命令：

curl -sSL [https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/dns_unlock.sh](https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/dns_unlock.sh) | tr -d '\r' > dns_unlock.sh && bash dns_unlock.sh
