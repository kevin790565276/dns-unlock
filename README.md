🚀 终极 DNS 全球流媒体 & AI 解锁工具箱 (双栈增强版)

本脚本专为拥有原生 IPv6 的 VPS 打造。其核心逻辑在于解决“原生 IPv6 导致解锁失效”的痛点，通过 DNS 层的“降维打击”，实现原生网络与解锁流量的完美平衡。

🌟 核心特性
智能分流 (IPv6 降级攻击)：针对 Netflix、Disney+、ChatGPT、Gemini 等顽固平台，DNS 自动屏蔽其 IPv6 解析（返回 ::），迫使客户端回退至解锁 IPv4 通道。

原生 IPv6 保留：非流媒体流量（如 Google 搜索、系统更新、普通网站）依然保持原生 IPv6 直连，不影响网络性能。

全量域名包：内置最全的 AI 列表（OpenAI, Claude, Gemini, Grok）及流媒体列表（Netflix, Disney+, YouTube, TikTok 全家桶）。

双栈接管：同时监听 127.0.0.1 和 ::1，物理锁定 /etc/resolv.conf 防止服务商篡改。

一键管理：支持环境安装、规则配置、一键还原、彻底卸载及解锁检测。

```bash
curl -sSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/dns_unlock.sh | tr -d '\r' > dns_unlock.sh && bash dns_unlock.sh
```
快捷指令：
安装完成后，直接在终端输入 dns 即可进入管理菜单。
⚠️ 注意事项
权限需求：必须使用 root 用户运行。

编辑/etc/dnsmasq.d/unlock.conf添加需要解锁的流媒体及AI

解锁 IP：请确保你拥有的解锁 IP（DNS 出口）本身具备相应平台的解锁权限。

文件锁定：脚本会使用 chattr +i 锁定 DNS 配置文件，手动修改前请先通过脚本选项 3 或 5 解锁。
