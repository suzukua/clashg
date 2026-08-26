# ClashG

基于 mihomo 的透明代理解决方案，适用于华硕路由器固件。

## 📋 项目简介

ClashG 是一个专为 ASUS AX86U 官改固件设计的网络代理工具，理论上支持所有 HND 平台路由器。采用基于 GFW 域名列表的智能分流策略，通过 dnsmasq 配合部分国外 IP 规则实现精准代理，确保国内流量完全不受影响。

**核心优势：** 高稳定性、高可靠性、高容错性

## 🚀 快速开始

**[立即下载最新版本](https://github.com/zhudan/clashg/releases)**

## ✨ 主要特性

### 核心功能
- 基于 [mihomo (Clash.Meta)](https://github.com/MetaCubeX/mihomo) 内核实现
- 支持局域网内 TCP/UDP 透明代理 (TPROXY)
- 支持自动更新 GeoIP 数据库和 GFW 规则集
- 支持手动编辑 Clash 配置文件

### 入站协议支持
- Shadowsocks 协议入站
  - 支持 UDP + TCP 双协议
  - 支持 IPv6 + IPv4 双栈
  - 配置后自动开通公网入站端口
- 支持 TCP Fast Open (TFO) 加速

### 规则管理
- 支持自定义规则地址
- 智能 DNS 分流
- 基于 GFW 域名列表的精准匹配

## 📸 界面预览

### 主控制面板
<img width="753" alt="主控制面板" src="https://github.com/zhudan/clashg/assets/1744697/53351aba-f8ce-421f-b815-f5069e39e86c">

### 节点配置
<img width="812" alt="节点配置界面" src="https://github.com/zhudan/clashg/assets/1744697/d429f185-a93f-4389-aed3-9907329fbbb4">

### 规则设置
<img width="757" alt="规则设置界面" src="https://github.com/zhudan/clashg/assets/1744697/18482a26-5b31-4730-9de5-92d6add270e9">

### 代理配置
<img width="741" alt="代理配置界面" src="https://github.com/zhudan/clashg/assets/1744697/8a9fa861-b640-4ae6-aa3b-c010d121b39c">

### 高级选项
<img width="740" alt="高级选项界面" src="https://github.com/zhudan/clashg/assets/1744697/bfdaf823-37ab-4606-9d62-76af2d110b34">

## 🙏 致谢

本项目部分实现参考了以下优秀项目：
- MC
- vClash

## 📄 许可证

详见 [LICENSE](LICENSE) 文件。

---

如有问题或建议，欢迎提交 [Issue](https://github.com/zhudan/clashg/issues)。
