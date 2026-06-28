+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = 'iOS 共用知识点（OC / Swift 通用）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# iOS 共用知识点（OC / Swift 通用）

> UIKit、网络、性能等平台机制与语言无关，**原理只写一遍**。OC 与 Swift 的差异仅在语法，各章代码块并列给出两种写法。

## 适用目录

| 共用章节 | 文件 | OC 学习路径 | Swift 学习路径 |
|----------|------|-------------|----------------|
| 第六章 | [06-事件传递链HitTesting.md](./06-事件传递链HitTesting.md) | [OC 目录](../OC/README.md) ⑤→⑥ | [Swift 目录](../Swift/README.md) ⑤→⑥ |
| 第七章 | [07-事件响应链ResponderChain.md](./07-事件响应链ResponderChain.md) | ⑥→⑦ | ⑥→⑦ |
| 第八章 | [08-网络与HTTP.md](./08-网络与HTTP.md) | ④→⑧ | ④→⑧ |
| 第九章 | [09-性能优化与UIKit.md](./09-性能优化与UIKit.md) | ⑧→⑨ | ⑧→⑨ |
| 第十章 | [10-架构与项目实战.md](./10-架构与项目实战.md) | ⑨→⑩ | ⑨→⑩ |

## 目录结构

```
iOS/
├── OC/           ← 语言特有：isa、Runtime、Block …
├── Swift/        ← 语言特有：值类型、派发、闭包 …
├── Common/       ← 平台共用：UIKit、网络、性能、架构
└── 大厂面试题/   ← 按公司整理的真题 + TOP50
```

## 后续可迁入 Common 的主题

- GCD 基础详解（若 OC/Swift 重复过多）
- RunLoop 专题
- 证书与签名

告诉我「把 XX 迁入 Common」即可。
