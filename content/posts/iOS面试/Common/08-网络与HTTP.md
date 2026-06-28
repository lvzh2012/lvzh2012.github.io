+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = '第八章：网络与 HTTP（大厂高频 · 原理详解）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# 第八章：网络与 HTTP（大厂高频 · 原理详解）

> **学习位置**：多线程（OC/Swift 第四章）之后阅读。  
> 本章不只列考点，重点讲 **为什么这样设计、底层怎么运作**。

---

## 8.1 从点击到展示的完整链路

```
用户点击
  │
  ├─ 1. DNS 解析：域名 → IP
  ├─ 2. TCP 三次握手：建立可靠连接
  ├─ 3. TLS 握手（HTTPS）：协商密钥、校验证书
  ├─ 4. HTTP 请求/响应：应用层数据
  ├─ 5. 客户端解析 JSON → Model
  └─ 6. 主线程刷新 UI
```

**关键认知**：DNS/TCP/TLS 是 **传输层之下的基础设施**；HTTP 是 **应用层协议**，跑在 TCP 之上；iOS 里 `URLSession` 帮你封装了 1～4，但面试要能把每层拆开讲。

---

## 8.2 DNS 原理

### 为什么需要 DNS？

人记 `www.apple.com`，网络只认 IP（如 `17.253.144.10`）。DNS 就是 **分布式域名 → IP 的映射系统**。

### 查询过程（递归 + 迭代）

```
App 发起请求 api.example.com
    │
    ▼
① 浏览器/App 本地缓存（内存 + 磁盘 hosts 缓存）
    │ 未命中
    ▼
② 操作系统缓存（mDNSResponder）
    │ 未命中
    ▼
③ 本地 DNS 服务器（路由器/ISP 分配，如 192.168.1.1 → 运营商 DNS）
    │ 未命中 → 递归查询
    ▼
④ 根 DNS（.）→ 返回 .com 顶级域服务器地址
    ▼
⑤ .com 顶级域 → 返回 example.com 权威 DNS
    ▼
⑥ 权威 DNS → 返回 api.example.com 的 A 记录（IP）
    ▼
结果沿原路缓存并返回给 App
```

### DNS 故障怎么办？（字节三面）

| 层级 | 现象 | 应对 |
|------|------|------|
| 本地 DNS 污染/劫持 | 解析到错误 IP | **HTTP DNS**（直接问可信 DNS 服务器，绕过 Local DNS） |
| ISP DNS 不可用 | 超时 | 换 114.8.8.8 / 8.8.8.8；App 内置 DNS 解析 |
| 权威 DNS 挂了 | 域名无法解析 | 多域名容灾、CDN 备用域名 |

**HTTP DNS 原理**：不走路由器 Local DNS，App 直接向阿里云/腾讯云 DNS 服务发 HTTPS 请求拿 IP，再 **强制用 IP 访问**（Host 头仍带域名）。

---

## 8.3 TCP 原理（腾讯/字节必深挖）

### TCP vs UDP

| | TCP | UDP |
|--|-----|-----|
| 连接 | 面向连接（三次握手） | 无连接 |
| 可靠性 | 有序、不丢、不重复 | 不保证 |
| 速度 | 较慢（ACK、重传） | 快 |
| 场景 | HTTP、HTTPS、文件 | 视频、语音、DNS、游戏 |

### 三次握手 —— 为什么需要三步？

```
Client                          Server
   │── SYN, seq=x ──────────────►│   「我想连接，我的起始序号是 x」
   │◄─ SYN+ACK, seq=y, ack=x+1 ──│   「收到，我的是 y，也同意连接」
   │── ACK, ack=y+1 ────────────►│   「确认，连接建立」
```

**每一步的目的**：
1. **SYN**：客户端证明「我能发、你能收」
2. **SYN+ACK**：服务端证明「我能收、也能发」；同时确认客户端的 SYN
3. **ACK**：客户端确认服务端的 SYN

**为什么不能两次？** 两次无法确认客户端收到了服务端的应答，服务端可能白等（历史 SYN 浪费资源）。

**握手完成后**：双方都知道了彼此的 **初始序列号 ISN**，后续每个字节带序号，接收方按序重组。

### 四次挥手 —— 为什么需要四步？

```
Client                          Server
   │── FIN, seq=u ──────────────►│   「我发完了，要关闭」
   │◄─ ACK, ack=u+1 ─────────────│   「知道你要关，但我可能还有数据要发」
   │◄─ FIN, seq=v ───────────────│   「我也发完了，要关闭」
   │── ACK, ack=v+1 ────────────►│   「确认，连接关闭」
```

TCP 是 **全双工**，每个方向独立关闭，所以需要两个 FIN+ACK。

**TIME_WAIT**：主动关闭方会等 2MSL，防止最后的 ACK 丢失导致服务端重发 FIN 时无法正确响应。

### TCP 如何保证可靠交付？

| 机制 | 原理 |
|------|------|
| **序号 seq** | 每个字节编号，接收方按序组装 |
| **确认 ACK** | 接收方告诉发送方「期望收到的下一个序号」 |
| **超时重传** | 没收到 ACK → 重发；RTT 动态估算超时时间 |
| **校验和** | 检测数据损坏 |
| **去重** | 相同序号只收一次 |

### 流量控制（Flow Control）—— 接收方说了算

**问题**：发送方太快，接收方 buffer 溢出。

**解法**：**滑动窗口（Sliding Window）**

```
发送方维护「可发送窗口」= min(接收窗口 rwnd, 拥塞窗口 cwnd)

接收方在 TCP 头里通告 rwnd（还能收多少字节）
    │
    ▼
发送方未确认的数据不能超过 rwnd
    │
    ▼
接收方处理完数据 → 扩大 rwnd → 发送方加速
```

**零窗口探测**：接收方 rwnd=0 时，发送方定期发探测包，防止死锁。

### 拥塞控制（Congestion Control）—— 网络说了算

**问题**：不只一端慢，中间路由器队列满了会 **丢包**，全体都要降速。

**核心变量**：
- **cwnd**（congestion window）：发送方估计的网络承载能力
- **ssthresh**：慢启动阈值

**四个阶段**：

```
1. 慢启动（Slow Start）
   cwnd 从 1 开始，每收到一个 ACK → cwnd += 1（指数增长 1→2→4→8…）
   直到 cwnd >= ssthresh

2. 拥塞避免（Congestion Avoidance）
   每 RTT cwnd += 1（线性增长），谨慎探测上限

3. 快重传（Fast Retransmit）
   收到 3 个重复 ACK（没丢包但后面的包到了）→ 立即重传丢失段，不等超时

4. 快恢复（Fast Recovery）
   快重传后 cwnd 减半（而非降回 1），避免网络利用率骤降
```

**丢包时**：超时 → cwnd 重置为 1，ssthresh = cwnd/2，重新慢启动。

**面试画这张图**：慢启动指数 → 阈值线性 → 丢包骤降 → 再慢启动。

### 粘包 / 拆包

TCP 是 **字节流**，没有「消息边界」。HTTP 靠 **Content-Length** 或 **Chunked** 在应用层定界。

---

## 8.4 HTTP 基础

### 报文结构

**请求**：
```
GET /api/user?id=1 HTTP/1.1      ← 请求行（方法 路径 版本）
Host: api.example.com            ← 请求头
Accept: application/json
Authorization: Bearer xxx

                                 ← 空行
(body，GET 通常无)                 ← 请求体
```

**响应**：
```
HTTP/1.1 200 OK                  ← 状态行
Content-Type: application/json
Content-Length: 128
Cache-Control: max-age=3600

{"name":"Tom"}                   ← 响应体
```

### 304 协商缓存原理

**目标**：资源未变时不重复下载 body，省流量、提速。

```
第一次请求
  Client ──GET /logo.png──► Server
  Client ◄──200 + body + ETag:"abc123"── Server
  Client 缓存 body + ETag

第二次请求
  Client ──GET /logo.png + If-None-Match:"abc123"──► Server
  Server 比较 ETag 未变
  Client ◄──304 Not Modified（无 body）── Server
  Client 用本地缓存展示
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `Cache-Control: max-age` | 强缓存 | 未过期直接用，不发请求 |
| `ETag` / `If-None-Match` | 协商缓存 | 过期后问服务器是否变了 |
| `Last-Modified` / `If-Modified-Since` | 协商缓存 | 按时间戳判断（秒级精度） |

**优先级**：强缓存未过期 → 不发请求；过期 → 协商缓存 → 304 或 200。

---

## 8.5 HTTP/2 原理（字节一面）

### HTTP/1.1 的痛点

1. **队头阻塞**：同一 TCP 连接上请求必须排队响应（Pipeline 几乎没人用）
2. **头部冗余**：每个请求重复带 Cookie、User-Agent 等大头
3. **多连接**：浏览器对同域开 6～8 条 TCP 连接 workaround

### HTTP/2 怎么解决？

**① 二进制分帧（Binary Framing）**

所有数据切成 **Frame**，多种类型：

| Frame 类型 | 作用 |
|------------|------|
| HEADERS | 头部 |
| DATA |  body |
| SETTINGS | 连接参数协商 |
| GOAWAY | 关闭连接 |

**② 多路复用（Multiplexing）**

```
一条 TCP 连接
  ├── Stream 1（请求 HTML）  ── Frame 交错发送 ──►
  ├── Stream 3（请求 CSS）   ── Frame 交错发送 ──►
  └── Stream 5（请求 JS）    ── Frame 交错发送 ──►
```

每个 Stream 有 ID，Frame 带 Stream ID，接收方 **按 Stream 重组**，互不阻塞。

**注意**：HTTP/2 解决了 **应用层** 队头阻塞，但 TCP 层丢包仍会让整条连接上所有 Stream 等待（TCP 队头阻塞）。HTTP/3 用 QUIC(UDP) 解决。

**③ HPACK 头部压缩**

静态表 + 动态表，重复头部只传索引，Cookie 只传一次。

---

## 8.6 HTTPS / TLS 原理（腾讯/字节必考）

### HTTPS = HTTP + TLS

HTTP 明文 → TLS 加密层 → TCP。端口 443。

### 为什么握手用非对称，传输用对称？

| 方式 | 速度 | 密钥分发 |
|------|------|----------|
| 非对称（RSA/ECDHE） | 慢 | 公钥加密，只有私钥能解 |
| 对称（AES） | 快 | 双方要有同一密钥 |

**TLS 1.2 握手思路**：用非对称 **安全地交换对称密钥**，之后全用 AES 加密 HTTP 数据。

### TLS 1.2 完整握手（简化版）

```
Client                                    Server
  │── ClientHello ────────────────────────►│  支持的 TLS 版本、Cipher 套件、随机数 C
  │◄─ ServerHello ────────────────────────│  选定套件、随机数 S
  │◄─ Certificate ────────────────────────│  服务端证书（含公钥 + 域名）
  │◄─ ServerHelloDone ────────────────────│
  │                                        │
  │  客户端验证证书链：                       │
  │  证书 → 中间 CA → 根 CA（系统信任库）    │
  │  域名匹配、未过期                        │
  │                                        │
  │── ClientKeyExchange ──────────────────►│  用证书公钥加密「预主密钥 PMS」
  │── ChangeCipherSpec ───────────────────►│  「后面用协商密钥了」
  │── Finished（加密）──────────────────────►│
  │◄─ ChangeCipherSpec ─────────────────────│
  │◄─ Finished（加密）──────────────────────│
  │                                        │
  │  双方用 C + S + PMS 推导出 session key   │
  │  后续 HTTP 数据 AES 对称加密             │
```

### 如何防中间人？

1. 证书由 **CA 私钥签名**，客户端用 CA **公钥** 验证签名
2. 中间人没有合法证书 → 校验失败 → 连接中断
3. Charles 抓包：安装 **Charles 根证书**到系统信任库 → Charles 动态签发假证书 → 相当于你主动信任中间人

### SSL Pinning

App 内置服务端证书/公钥哈希，**只信任特定证书**，即使系统信任 Charles 根证书也拒绝 → 抓包看到乱码。

**绕过 Pinning**：越狱 + Frida hook、或 debug 包关闭 Pinning。

---

## 8.7 WebSocket 原理（字节一面）

### 与 HTTP 轮询对比

| 方式 | 原理 | 缺点 |
|------|------|------|
| 短轮询 | 定时 HTTP GET | 浪费、延迟高 |
| 长轮询 | 服务端 hold 住直到有数据 | 连接数多 |
| WebSocket | **一条 TCP 长连接，全双工** | 需心跳保活 |

### 握手：HTTP Upgrade

```
Client → Server:
GET /chat HTTP/1.1
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13

Server → Client:
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

`Sec-WebSocket-Accept` = Base64(SHA1(Key + 固定 GUID))，证明服务端理解 WebSocket。

**之后**：不再走 HTTP，帧格式传输文本/二进制，IM、弹幕、直播互动。

---

## 8.8 iOS 网络实践（结合原理）

### URLSession 在哪一层？

```
你的代码 URLSession.dataTask
    → CFNetwork / libcurl 封装
    → TLS（Security.framework）
    → TCP/IP（内核）
```

### 网络层设计

```
API Protocol 定义
    → Request Builder（参数、Header、签名）
    → Interceptor 链（Token 刷新、重试、日志）
    → URLSession（配置 timeout、cachePolicy）
    → Response Parser（Codable / 错误码映射）
    → 回调主线程 / async continuation
```

### 优化手段（知道原理才好优化）

| 方向 | 手段 | 原理依据 |
|------|------|----------|
| 连接 | HTTP/2、连接池 | 少握手、多路复用 |
| 数据 | Gzip、Protobuf | 减传输字节 |
| 缓存 | 强缓存 + 304 | 减重复下载 |
| DNS | HTTP DNS | 减解析失败/劫持 |
| 弱网 | 超时递增重试、降级 | TCP 重传 RTT 变大 |

---

## 8.9 大厂真题 ↔ 本章对照

| 题目 | 见本章 |
|------|--------|
| TCP 三次握手/四次挥手 | §8.3 |
| 流量控制 vs 拥塞控制 | §8.3 |
| HTTPS 对称/非对称 | §8.6 |
| HTTP/2 多路复用 | §8.5 |
| 304 / ETag | §8.4 |
| DNS 故障 | §8.2 |
| WebSocket | §8.7 |
| 请求全流程 | §8.1 |
