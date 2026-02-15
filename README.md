curl -sSL https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/dns_unlock.sh | tr -d '\r' > dns_unlock.sh && bash dns_unlock.sh

# 🚀 Gost DNS 解锁服务端一键脚本

这是一个用于解锁流媒体的 DNS 服务端脚本。配合中转机的 `dnsmasq` 分流使用。

## 📖 使用方法

在你的**解锁机（落地机）**上运行以下命令：

```bash
wget -qO- https://raw.githubusercontent.com/kevin790565276/dns-unlock/main/gost.sh | bash
