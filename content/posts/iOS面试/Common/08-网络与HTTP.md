+++
date = '2026-06-28T19:13:28+08:00'
draft = true
weight = 8
title = '第八章：网络与 HTTP（大厂高频 · 原理详解）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# 第八章：网络与 HTTP（大厂高频 · 原理详解）

> **学习位置**：多线程（OC/Swift 第四章）之后阅读。  
> 本章不只列考点，重点讲 **为什么这样设计、底层怎么运作**。

---

## 8.0 网络分层模型：TCP/IP 四层为主，OSI 七层对照（总纲 · 必背）

> **面试默认按 RFC 1122 的 TCP/IP 四层来讲**（互联网实际部署）；OSI 七层是学习模型，被问「七层分别是什么」时背出来即可，讲原理时就着四层展开。

### TCP/IP 四层（面试主用）

| 层 | 对应 OSI | 职责 | PDU | 协议 / iOS 例子 |
|----|---------|------|-----|----------------|
| **应用层** | 7+6+5 合并 | 数据语义、格式、会话（TLS 归应用） | 消息 | HTTP/HTTPS、DNS、WebSocket、SSE | `URLSession` |
| **传输层** | 4 | 端到端可靠、流量/拥塞控制 | **段 Segment** | TCP / UDP | 三次握手 |
| **网络层** | 3 | 跨网络寻址与路由 | **包 Packet** | IP / ICMP / 路由器 |
| **链路层** | 2+1 合并 | 同一链路传输 + 物理信号 | **帧 Frame** | 以太网 / 网卡 / 交换机 |

```
iOS 视角实际感知三层：
  应用层（URLSession 写的协议）
  → 内核（TCP/IP 栈）
  → 硬件（WiFi 网卡收发包）
```

### OSI 七层一览（背诵用）

| 层 | 名称 | 职责（一句话） | PDU | 典型协议 / 设备 | 面试例子 |
|----|------|---------------|-----|----------------|---------|
| 7 | **应用层** | 面向用户的服务与数据语义 | 数据 | HTTP/HTTPS、DNS、WebSocket、FTP | `URLSession` 在这层之上 |
| 6 | **表示层** | 数据格式、编码、加解密 | 数据 | TLS 部分职责、字符集 | 现代协议已并入应用层 |
| 5 | **会话层** | 建立/维持/断开会话 | 数据 | TLS 会话、登录态 | 实际由传输层+应用层实现 |
| 4 | **传输层** | 端到端可靠、流量/拥塞控制 | **段 Segment** | TCP / UDP | 三次握手在这层 |
| 3 | **网络层** | 跨网络寻址与路由 | **包 Packet** | IP / ICMP / 路由器 | IP 地址 |
| 2 | **数据链路层** | 同一链路帧传输、MAC 寻址、检错 | **帧 Frame** | 以太网 / 交换机 / MAC | 一跳一跳传 |
| 1 | **物理层** | 比特流传输（电压/信号） | **比特 Bit** | 网线 / 光纤 / 集线器 | 信号 |

**记忆口诀**：**应表会传网链物**（All People Seem To Need Data Processing）。

> **题外**：部分教材用「五层教学模型」（数据链路/物理分开，如 Tanenbaum），互联网工程实际按四层——面试答四层，被追问再提五层，不扣分还显功底。

### 封装 / 解封装（数据怎么过每一层）

```
发送：HTTP 报文 ──加 TCP 头──► Segment ──加 IP 头──► Packet ──加帧头尾──► Frame ──► 比特流
接收：比特流 ──剥帧头尾──► Packet ──剥 IP 头──► Segment ──剥 TCP 头──► HTTP 报文

每一层只处理自己的头：加头（封装）是发送方向，剥头（解封装）是接收方向。
```

### 本层各节的落位

| 网络知识 | 属于哪层 |
|---------|---------|
| DNS / HTTP / WebSocket / SSE / WebRTC 信令 | 应用层（7） |
| TLS（证书/对称/非对称） | 表示/会话层（6/5）＋ 本身跑在 TCP 上 |
| TCP / UDP、三次握手、拥塞控制 | 传输层（4） |
| IP 寻址、路由 | 网络层（3） |

### 面试 30 秒版

> 分层讲原理用 **TCP/IP 四层**（RFC 1122）：应用（HTTP/TLS/DNS/WebSocket/SSE）、传输（TCP/UDP，三次握手/拥塞控制）、网络（IP 路由）、链路（网卡/以太）。OSI 七层是背诵模型：**应表会传网链物**（7 6 5 4 3 2 1），四层就是「7+6+5 合并、4、3、2+1 合并」。iOS 只需要关心**应用层 + 传输层**，下面由内核和网卡处理。数据发送逐层加头、接收逐层剥头（封装/解封装）。

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


| 层级           | 现象       | 应对                                       |
| ------------ | -------- | ---------------------------------------- |
| 本地 DNS 污染/劫持 | 解析到错误 IP | **HTTP DNS**（直接问可信 DNS 服务器，绕过 Local DNS） |
| ISP DNS 不可用  | 超时       | 换 114.8.8.8 / 8.8.8.8；App 内置 DNS 解析      |
| 权威 DNS 挂了    | 域名无法解析   | 多域名容灾、CDN 备用域名                           |


**HTTP DNS 原理**：不走路由器 Local DNS，App 直接向阿里云/腾讯云 DNS 服务发 HTTPS 请求拿 IP，再 **强制用 IP 访问**（Host 头仍带域名）。

---



## 8.3 TCP 原理（腾讯/字节必深挖）



### TCP vs UDP


|     | TCP           | UDP          |
| --- | ------------- | ------------ |
| 连接  | 面向连接（三次握手）    | 无连接          |
| 可靠性 | 有序、不丢、不重复     | 不保证          |
| 速度  | 较慢（ACK、重传）    | 快            |
| 场景  | HTTP、HTTPS、文件 | 视频、语音、DNS、游戏 |




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


| 机制         | 原理                        |
| ---------- | ------------------------- |
| **序号 seq** | 每个字节编号，接收方按序组装            |
| **确认 ACK** | 接收方告诉发送方「期望收到的下一个序号」      |
| **超时重传**   | 没收到 ACK → 重发；RTT 动态估算超时时间 |
| **校验和**    | 检测数据损坏                    |
| **去重**     | 相同序号只收一次                  |




### 顺序 + 确认 + 丢包重传（seq / ACK 规范 · 必背）

**① 顺序如何保证**：TCP 是**字节流**，seq 是「字节号」不是「包号」；接收方**按 seq 重排**后才交应用层：

```
乱序到达：段1(seq=100)、段3(seq=300)、段2(seq=200)
接收方：段1 连续 → 上交；段3 不连续 → 存重排缓冲区等待
      段2 到齐 → seq 100~399 全部连续 → 整块上交
→ 应用层永远拿到有序数据（乱序由接收缓冲吸收）
```

**② 累计 ACK**：`ack = 期望收到的下一个 seq = 已连续收到的最大字节号 + 1`。ACK 数字推进 = 「seq < ack 的字节全收到」。

**③ 丢包重传（两种触发 + SACK）**：

```
发送方                        网络                 接收方
段1 seq=100 ────────────────► ✓ 到达 → 回 ACK=200
段2 seq=200 ────────────────► ✗ 丢失        （不回 ACK）
段3 seq=300 ────────────────► ✓ 到达 → 回 ACK=200 ← 期望还是 200（重复）
段4 seq=400 ────────────────► ✓ 到达 → 回 ACK=200
段5 ...     ────────────────► ✓ 到达 → 回 ACK=200（第 3 个重复 ACK）
                                  │
发送方 3 个重复 ACK →【快速重传】立即补发段2
若 RTO 超时先到（无重复 ACK 场景）→【超时重传】
补发到达 → 缓冲补全 → ack=500 → 恢复
```

| 机制 | 触发 | 要点 |
|------|------|------|
| **超时重传** | RTO 到期未确认 | RTO 动态算（SRTT+方差）；Karn 算法：重传后不采样 RTT，指数退避 |
| **快速重传** | **3 个重复 ACK** | 不等超时立刻补发，降低延迟 |
| **SACK** | TCP 头 options 带缺口区间表 | 只补缺失区间，不整窗重传（多丢包时收益大） |

**④ seq / ack 数字规范（含握手）**：

| 规则 | 内容 |
|------|------|
| **ISN** | 初始 seq = **随机数**（防伪造/序列号预测攻击） |
| **seq 递增** | seq = 上个段 seq + **上个段数据字节数** |
| **ack 递增** | ack = 期望下一 seq（累计确认，永远不放水） |
| **SYN / FIN 各占 1 个序号** | 会让对方 ack +1 —— 最易记错点 |
| **双向独立** | Client→Server 与 Server→Client 各一套 seq/ack，各算各的 |
| **纯 ACK 段** | 不占序号，seq 不变 |
| **回绕** | 32 位序号循环使用（PAWS 防新旧混淆） |

```
三次握手数字规范（必背）：
Client → Server:  SYN,    seq=x
Server → Client:  SYN+ACK, seq=y, ack=x+1    ← SYN 占 1 位所以 +1
Client → Server:  ACK,    seq=x+1, ack=y+1

之后数据（各算各的）：
Client → Server:  seq=x+1, 200 字节 → Server 回 ack=x+201
Server → Client:  seq=y+1, 150 字节 → Client 回 ack=y+151
```

> **面试 30 秒版**：顺序靠 seq（字节号）+ 接收方**重排缓冲**；「到齐没」靠**累计 ACK**（ack=期望下一 seq）；丢包恢复 = **超时重传**（RTO 动态算）或 **快速重传**（3 个重复 ACK），重口补缺用 SACK。seq/ack 规范：ISN 随机、seq 累计字节数、ack 期望值、**SYN/FIN 各占 1 个序号**、双向独立编号。

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
(body，GET 通常无)                ← 请求体
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


| 字段                                    | 类型   | 说明           |
| ------------------------------------- | ---- | ------------ |
| `Cache-Control: max-age`              | 强缓存  | 未过期直接用，不发请求  |
| `ETag` / `If-None-Match`              | 协商缓存 | 过期后问服务器是否变了  |
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


| Frame 类型 | 作用     |
| -------- | ------ |
| HEADERS  | 头部     |
| DATA     | body   |
| SETTINGS | 连接参数协商 |
| GOAWAY   | 关闭连接   |


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

**④ HTTP/3 / QUIC（了解加分）**

| HTTP/2 残留痛点 | HTTP/3 解法 |
|------|------|
| **TCP 队头阻塞**：丢一个包，整条连接所有 Stream 一起等 | 换 **QUIC（基于 UDP）**，丢包只重传受影响的 Stream |
| TCP 握手 + TLS 握手各一次（1.5~2 RTT） | QUIC 自带加密握手合并：**0~1 RTT**（内含 TLS 1.3） |
| 连接迁移：切 WiFi/4G 就断连重连 | **Connection ID** 不随 IP 变，连接无缝迁移 |

**注意**：HTTP/3 = HTTP/2 的分帧多路复用 + QPACK（HPACK 升级）+ QUIC（UDP + TLS 1.3）。弱网 App（音视频、IM）切 HTTP/3 收益明显。

---



## 8.6 HTTPS / TLS 原理（腾讯/字节必考）



### HTTPS = HTTP + TLS

HTTP 明文 → TLS 加密层 → TCP。端口 443。

### 为什么握手用非对称，传输用对称？


| 方式             | 速度  | 密钥分发        |
| -------------- | --- | ----------- |
| 非对称（RSA/ECDHE） | 慢   | 公钥加密，只有私钥能解 |
| 对称（AES）        | 快   | 双方要有同一密钥    |


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


| 方式        | 原理                 | 缺点     |
| --------- | ------------------ | ------ |
| 短轮询       | 定时 HTTP GET        | 浪费、延迟高 |
| 长轮询       | 服务端 hold 住直到有数据    | 连接数多   |
| WebSocket | **一条 TCP 长连接，全双工** | 需心跳保活  |




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

## 8.8 WebRTC 原理

### 是什么

**实时音视频**的开源方案（采集 → 编码 → P2P 传输 → 播放），iOS 集成用 GoogleWebRTC / WKWebView。

### 与 WebSocket 对比（必背）

| 维度 | WebSocket | WebRTC |
|------|-----------|--------|
| 传输层 | TCP（可靠有序，但丢包重传延迟兜底） | **UDP（SRTP）**，丢包可接受，延迟优先 |
| 架构 | 单通道双向消息（经服务端） | **P2P 端到端直连**，媒体流不经过服务端 |
| 典型场景 | IM、弹幕、推送 | 视频通话、直播连麦、屏幕共享 |

### 核心流程（信令 + SDP + ICE 三件套）

```
① 信令（Signaling）：交换 SDP + ICE 候选
   —— WebRTC 不管信令通道，复用现有 WebSocket / HTTP
② SDP：描述媒体能力（编解码器、分辨率、方向）
   —— Offer → Answer 交换，双方对齐能力
③ ICE 打洞：寻找 P2P 可达路径
   —— STUN：查自己的公网 IP:端口
   —— TURN：打洞失败时中继转发（最稳但最贵）
```

### NAT 打洞（ICE 流程）

```
候选收集：本地 ──► STUN 反射地址 ──► TURN 中继地址
两两配对 → 按优先级做连通性检查
    成功 → P2P 直达（最优）
    失败 → 回退 TURN 中继
```

### 面试 30 秒版

> WebRTC 是实时音视频 P2P 方案：**信令**（SDP/ICE 交换）走现有的 WebSocket/HTTP 通道，媒体流用 **SRTP over UDP** 端到端直传绕开服务端；NAT 打洞靠 **STUN** 发现公网地址，打不通则 **TURN 中继**。与 WebSocket 的本质区别：WebSocket 是 TCP 上的消息通道，WebRTC 是 UDP 上的 P2P 音视频传输。

---

## 8.9 SSE 原理（大模型流式输出）

### 是什么

**HTTP 长连接单向事件流**：服务端不关连接、持续写数据块，客户端逐块读——ChatGPT 打字机效果的底层。

```
客户端：普通 HTTP GET  +  Accept: text/event-stream
服务端：200 OK
        Content-Type: text/event-stream   ← 连接保持打开
        data: {"delta":"你"}\n\n
        data: {"delta":"好"}\n\n          ← 逐块推送
客户端：URLSession 流式读，逐段解析 data: 行 → UI 增量渲染
```

**协议细节**：
- 事件格式：`data: 内容\n\n`（空行分隔）；可选 `event:` 类型、`id:`（断线续传用）、`retry:`
- 走 HTTP chunked，**单向**（服务端 → 客户端）；客户端要回传得另发请求
- 原生支持**断线自动重连**（携带 Last-Event-ID 续传）

### 与 WebSocket 对比（必背）

| | SSE | WebSocket |
|--|-----|-----------|
| 方向 | 服务端 → 客户端**单向** | 全双工 |
| 传输 | 普通 HTTP（**自动重连**，省心） | TCP 长连接（心跳、重连都要自己写） |
| 格式 | 文本事件流 | 文本/二进制帧 |
| 典型场景 | **LLM 流式输出**、行情、通知 | IM、互动直播 |
| 选型 | 只推送 → SSE 更简单 | 双向高频 → WebSocket |

### iOS 实现（URLSession 流式读）

```swift
var request = URLRequest(url: url)
request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await line in bytes.lines {
    if line.hasPrefix("data: ") {
        let raw = line.dropFirst(6)
        // 解析 delta → 主线程增量渲染
    }
}
```

**边界提醒**：代理/网关可能缓冲或超时断连 → 靠心跳注释行保持活跃；重试用 Last-Event-ID；App 退后台流会断。

### 面试 30 秒版

> SSE 是「HTTP 上的单向事件流」：客户端发普通 GET（`Accept: text/event-stream`），服务端不关连接逐块写 `data:` 行；iOS 用 `URLSession.bytes` 流式读，且自带断线重连（Last-Event-ID）。**要服务端单向推送（LLM 打字机/行情）选 SSE，双向交互选 WebSocket**。

---


## 8.10 iOS 网络实践（结合原理）



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


| 方向  | 手段            | 原理依据          |
| --- | ------------- | ------------- |
| 连接  | HTTP/2、连接池    | 少握手、多路复用      |
| 数据  | Gzip、Protobuf | 减传输字节         |
| 缓存  | 强缓存 + 304     | 减重复下载         |
| DNS | HTTP DNS      | 减解析失败/劫持      |
| 弱网  | 超时递增重试、降级     | TCP 重传 RTT 变大 |


---



## 8.11 大厂真题 ↔ 本章对照


| 题目            | 见本章  |
| ------------- | ---- |
| OSI 七层 / TCP/IP 对照 | §8.0 |
| TCP 三次握手/四次挥手 | §8.3 |
| 流量控制 vs 拥塞控制  | §8.3 |
| HTTPS 对称/非对称  | §8.6 |
| HTTP/2 多路复用   | §8.5 |
| HTTP/3 / QUIC   | §8.5 |
| 304 / ETag    | §8.4 |
| DNS 故障        | §8.2 |
| WebSocket     | §8.7 |
| WebRTC        | §8.8 |
| SSE / LLM 流式输出 | §8.9 |
| 请求全流程         | §8.1 |


