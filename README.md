

# 🚀  DNS 解锁流媒体一键脚本

这是一个用于解锁流媒体的 DNS 服务端脚本。已经配好流媒体AI分流，除了Youtube。

## 📖 使用方法

在你的**（中转机）**上运行以下命令：

```bash
curl -sSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/dns_unlock.sh | tr -d '\r' > dns_unlock.sh && bash dns_unlock.sh

# 🚀 全球 VPS 网络深度优化脚本

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Debian%20|%20Ubuntu%20|%20CentOS-orange.svg)](#)

这是一个专门为 **高延迟、长距离绕路线路**（如德国、美国、台湾广播 IP）设计的内核优化脚本。特别针对 **Hysteria 2 (Hy2)** 和 **高并发 TCP** 进行了缓冲区与队列调优。

## ✨ 功能特性
* **拥塞算法**: 强制开启 `TCP BBR` + `FQ` 调度。
* **UDP 强化**: 深度优化 UDP 接收/发送缓冲区，专为 Hysteria 2 打造。
* **高并发**: 提升 `somaxconn` 和 `syn_backlog`，解决握手卡顿。
* **长肥网络优化**: 扩充 TCP 窗口缓冲区至 `64MB`，榨干高延迟线路带宽。
* **熵池补全**: 自动安装 `haveged`，加速 SSH 登录与 TLS 握手。

## 🛠️ 一键安装

在终端执行以下命令：

```bash
curl -sL [https://raw.githubusercontent.com/kevin790565276/dns-unlock/refs/heads/main/optimize.sh](https://raw.githubusercontent.com/kevin790565276/dns-unlock/refs/heads/main/optimize.sh) | sudo bash
