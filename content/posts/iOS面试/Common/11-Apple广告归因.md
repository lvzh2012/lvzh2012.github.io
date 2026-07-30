+++
date = '2026-07-15T20:40:46+08:00'
draft = true
title = '第十一章：Apple 广告归因（大厂高频 · 隐私时代下的必知）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# 第十一章：Apple 广告归因（大厂高频 · 隐私时代下的必知）

> 广告归因是 **用户从点击广告 → 下载 App → 打开 App** 这条链路里，把「激活」对应回「某个广告来源」的技术。  
> 在 ATT（App Tracking Transparency）推出后，传统 IDFA 归因几乎失效，Apple 自己的归因方案成为必考知识点。

---

## 11.1 历史发展

```
2010 ─── iAd 发布 ───────────────── 封闭生态，Apple 自营广告
2016 ─── Apple Search Ads 上线 ──── 只投 App Store 搜索，无三方
2018 ─── SKAdNetwork 1.0 提案 ──── iOS 12.2，首次给三方归因通道
2019 ─── SKAdNetwork 2.0 ───────── iOS 14，支持 conversion value
2020 ─── iOS 14 宣布 ATT ───────── IDFA 默认关闭，行业地震
2021.4 ─ ATT 正式生效 ──────────── iOS 14.5，IDFA 需弹窗授权
2021 ─── SKAdNetwork 3.0 ───────── iOS 15，支持多转化、hierarchical
2021 ─── AdServices 框架 ───────── iOS 14.3+，Search Ads 归因专用
2022 ─── SKAdNetwork 4.0 ───────── iOS 16.1，支持 coarse-grain、crowd anonymity
2023 ─── SKAdNetwork 5.0 ───────── iOS 17.1，Web Ads 支持、source identifier 扩充
2024 ─── SKAdNetwork 6.0 ───────── iOS 17.4，新增 web-to-app、ad network priority
```

### 关键拐点

| 时间 | 事件 | 影响 |
|------|------|------|
| 2016 | Search Ads 上线 | 苹果亲自下场做搜索广告，三方广告平台开始紧张 |
| 2020 WWDC | 宣布 ATT 要求 | IDFA 获取率从 ~70% 骤降至 ~20%，FB 等公开抗议 |
| 2021.4 | ATT 正式生效 | 设备级归因能力被砍，行业被迫转向 SKAdNetwork |
| 2022 | SKAdNetwork 4.0 | 苹果妥协：提供粗粒度回传，降低空值率 |

---

## 11.2 核心知识点

### 11.2.1 IDFA 与 ATT

**IDFA (Identifier for Advertisers)**：每个 iOS 设备唯一的广告标识符，App 间共享。

**ATT 流程**：
```
App 启动
  │
  ├─ 请求 trackingAuthorizationStatus
  │
  ├─ 若未决定 → 弹出系统弹窗
  │   ├─ "允许跟踪" → IDFA 可用
  │   └─ "要求 App 不跟踪" → IDFA = 00000000-0000-0000-0000-000000000000
  │
  └─ 已有授权状态 → 直接使用
```

**关键 API**：`ATTrackingManager.requestTrackingAuthorization(completionHandler:)`

**注意点**：
- 必须在 Info.plist 里声明 `NSUserTrackingUsageDescription`
- 即使授权，用户仍可在 `设置 → 隐私 → 跟踪` 中全局关闭
- IDFA 归因是 **设备级、实时、精确** 的，但 ATT 后几乎不可用

### 11.2.2 SKAdNetwork (SKAN) 归因

Apple 为解决 ATT 后无 IDFA 可用的困境，提供的 **隐私安全的归因方案**。

#### 工作原理

```
广告点击
  │
  ├─ 广告平台 A 调用 SKAdNetwork API 注册点击
  │   └─ 记录 source-app-id / ad-network-id / campaign-id
  │
  ├─ 用户下载并首次打开 App
  │
  └─ App 启动 → 系统检查匹配
      │
      ├─ 匹配成功 → 启动倒计时（随机 24-48h 回传延迟）
      │   └─ 倒计时结束 → 发送 **匿名回传（postback）** 给广告平台
      │
      └─ 匹配失败 → 不产生回传
```

#### 从 1.0 → 4.0 的核心演进

| 版本 | iOS | 新增能力 |
|------|-----|----------|
| 1.0 | 12.2 | 基础归因，单次转化，24h 延迟回传 |
| 2.0 | 14.0 | `conversionValue`（6 bit, 0-63），支持 A/B |
| 3.0 | 15.0 | 多 conversion value，hierarchical source identifier |
| 4.0 | 16.1 | coarse-grained values, crowd anonymity, 多次回传 |
| 5.0 | 17.1 | web ads 支持, source identifier 扩展 |
| 6.0 | 17.4 | web-to-app, ad network priority, 新隐私分桶 |

#### 关键设计 - Crowd Anonymity (SKAN 4.0)

```
用户规模足够大（> threshold）→ 精细回传（含 conversion value）
用户规模中等           → coarse-grained（low/medium/high）
用户规模小（匿名风险高）→ 延迟或空值
```

这是隐私保护的体现：**数据越敏感，粒度越粗**。

#### SKAN 接入要点

```swift
// 广告平台在点击时注册
SKAdNetwork.registerAppForAdNetworkAttribution()

// 设置转化值（开发者自行定义含义）
SKAdNetwork.updateConversionValue(6)

// SKAN 4.0 coarse-grained
// 使用 SKAdNetwork.updatePostbackConversionValue(...)
```

**开发者需要注意**：
- `conversionValue` 只 6 bit（0-63），需自行映射业务事件（例如：0=安装, 1=注册, 2=付费...）
- 回传有 **随机延迟**（24-48h），不能做实时归因
- 一次安装只产生 **一次** 回传（SKAN 4.0 前），不能做事件级归因
- 广告平台需要在 Info.plist 注册 `SKAdNetworkItems`

#### Info.plist 配置示例

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>xxxxx.skadnetwork</string>
    </dict>
</array>
```

每个广告网络需向 Apple 申请 `SKAdNetworkIdentifier`，App 需列出所有合作的广告网络 ID。

### 11.2.3 AdServices 框架（Search Ads 归因）

Apple Search Ads 的专属归因框架，**不需要用户授权 ATT**。

| 特性 | SKAdNetwork | AdServices |
|------|------------|------------|
| 适用范围 | 所有广告平台 | 仅 Apple Search Ads |
| 需 ATT 授权 | 否 | 否 |
| 归因方式 | 概率性、隐私保护 | 确定性（Apple 自己知道你是谁） |
| 回传延迟 | 24-48h 随机 | **近乎实时** |
| 数据粒度 | 有限（6 bit） | 完整（关键词、广告组等） |

#### AdServices 归因流程

```swift
import AdServices

func getSearchAdsAttribution() {
    // 1. 获取归因 token
    let token = AAAttribution.token()
    
    // 2. 调用 Apple 归因 API（需要自己的 Server 去请求）
    // POST https://api-adservices.apple.com/api/v1/
    // Body: { "attributionToken": token }
    //
    // 返回:
    // {
    //   "attribution": true,
    //   "campaignId": 12345,
    //   "conversionType": "Download",
    //   "clickDate": "2024-01-01T00:00:00Z",
    //   "adGroupId": 67890,
    //   "keyword": "健身"
    // }
}
```

**注意**：
- `AAAttribution.token()` 是在 App 启动后延迟生成，建议首次启动后等待 1-2s 再获取
- 默认只会在 **首次安装后 24h 内** 返回有效 token
- 归因结果需要通过你自己的 Server 去请求 Apple 的 API，不要在客户端直接处理

### 11.2.4 iAd（已废弃）

Apple 最早的移动广告平台（2010-2016），后并入 Search Ads。

```
iAd.framework → deprecated in iOS 10
替代 → AdServices + SKAdNetwork
```

含 API `ADClient.addImpressionIdentifier(...)` 等，现已不可用，面试中只需知道 **iAd 是前身** 即可。

---

## 11.3 面试高频题

### Q1: ATT 弹窗什么时候弹出？弹一次还是每次都弹？

系统弹窗 **每个 App 只弹一次**。用户在「设置 → 隐私 → 跟踪」中可以随时更改授权。

### Q2: SKAdNetwork 为什么有延迟回传？

为了防止设备指纹（Device Fingerprinting）：如果点击后就回传，广告平台可以通过时差 + IP 精确定位用户。  
随机延迟让 **点击和回传无法关联到同一个人**，从而保护隐私。

### Q3: conversionValue 只有 6 bit，怎么设计映射？

常见做法（模型 A）：

```
bit 0-2: 事件阶段（0=安装, 1=注册, 2=付费, 3=订阅）
bit 3-5: 金额范围（0=0元, 1=1-6元, 2=6-30元, 3=30-100元, 4=100+）
```

这样可以编码 8 × 8 = 64 种状态，覆盖 `事件类型 × 金额范围`。

SKAN 4.0 支持 coarse-grained（low/medium/high），可以进一步简化。

### Q4: AdServices 和 SKAdNetwork 的区别？

见 11.2.3 的对比表。核心一句话：  
**AdServices 是 Apple 自己广告的精确归因，SKAdNetwork 是第三方广告的隐私安全归因。**

### Q5: ATT 授权率现在大概多少？

行业数据显示 iOS 14.5+ 全球授权率约 **20-30%**，游戏类略高（~35%），工具类偏低（~15%）。  
这是 IDFA 归因基本不可用的原因。

---

## 11.4 实践建议

### 接入策略

```
┌─ 使用 Search Ads？ ── 是 → 接入 AdServices（实时归因）
│
└─ 使用三方广告？ ──── 是 → 接入 SKAdNetwork
    │
    ├─ SKAN 3.x → conversionValue 映射（6bit）
    └─ SKAN 4.x → coarse-grain + 多次回传
```

### 归因对比总结

| 方案 | 精度 | 实时性 | 隐私代价 | 适用范围 |
|------|------|--------|----------|----------|
| IDFA (ATT) | 设备级 | 实时 | 完全可追踪 | 所有广告（需用户授权） |
| SKAdNetwork | 粗粒度 | 延迟 24-48h | 匿名 | 三方广告（无需授权） |
| AdServices | 设备级 | 近乎实时 | Apple 已知 | 仅 Search Ads（无需授权） |

---

## 11.5 附加概念

### Apple 的隐私立场

```
ATT + SKAdNetwork + App Privacy 标签
  │
  ├─ 目的：让用户掌握数据控制权
  ├─ 结果：广告行业收入结构变化（偏向 Apple Search Ads）
  └─ 趋势：越来越多设备级归因 → 聚合型归因（Aggregated Attribution）
```

### 设备指纹（Device Fingerprinting）

Apple **明确禁止** 用 IDFV、Keychain、私有 API 等方式做跨 App 追踪。  
ATT 后的行业灰色手段，Apple 在 iOS 16+ 持续封堵（如私有 API 检测、Keychain 隔离）。

---

## 相关学习路径

- 阅读 `08-网络与HTTP.md` 了解 HTTP 请求机制（AdServices 的归因 API 依赖网络）
- 阅读 `09-性能优化与UIKit.md` 了解启动优化（归因需在启动阶段尽快执行）
- 大厂面试题中查看 Facebook / Google 广告归因相关的真题
