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
| 第六章 | [06-事件传递链HitTesting.md](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E4%BA%8B%E4%BB%B6%E4%BC%A0%E9%80%92%E9%93%BEhit-testing.html) | [OC 目录](/posts/ios-/-objective-c-%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1%E6%96%87.html) ⑤→⑥ | [Swift 目录](/posts/ios-/-swift-%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1%E6%96%87.html) ⑤→⑥ |
| 第七章 | [07-事件响应链ResponderChain.md](/posts/%E7%AC%AC%E4%B8%83%E7%AB%A0%E4%BA%8B%E4%BB%B6%E5%93%8D%E5%BA%94%E9%93%BEresponder-chain.html) | ⑥→⑦ | ⑥→⑦ |
| 第八章 | [08-网络与HTTP.md](/posts/%E7%AC%AC%E5%85%AB%E7%AB%A0%E7%BD%91%E7%BB%9C%E4%B8%8E-http%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) | ④→⑧ | ④→⑧ |
| 第九章 | [09-性能优化与UIKit.md](/posts/%E7%AC%AC%E4%B9%9D%E7%AB%A0%E6%80%A7%E8%83%BD%E4%BC%98%E5%8C%96%E4%B8%8E-uikit%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) | ⑧→⑨ | ⑧→⑨ |
| 第十章 | [10-架构与项目实战.md](/posts/%E7%AC%AC%E5%8D%81%E7%AB%A0%E6%9E%B6%E6%9E%84%E4%B8%8E%E9%A1%B9%E7%9B%AE%E5%AE%9E%E6%88%98%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) | ⑨→⑩ | ⑨→⑩ |
| 第十一章 | [11-Apple广告归因.md](/posts/%E7%AC%AC%E5%8D%81%E4%B8%80%E7%AB%A0apple-%E5%B9%BF%E5%91%8A%E5%BD%92%E5%9B%A0%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E9%9A%90%E7%A7%81%E6%97%B6%E4%BB%A3%E4%B8%8B%E7%9A%84%E5%BF%85%E7%9F%A5.html) | ⑩→⑪ | ⑩→⑪ |

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
