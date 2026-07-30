+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = 'iOS / Swift 面试八股文'
tags = ["Swift", "面试"]
categories = ['iOS 面试']
+++

# iOS / Swift 面试八股文

> 按 **循序渐进** 顺序编排：从类型系统 → 方法派发 → 闭包 → 并发 → 语言特性 → 触摸事件 → 综合串联 → 复习收尾。  
> 与 [OC 目录](/posts/ios-/-objective-c-%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1%E6%96%87.html) 平级，UIKit / GCD 等共用部分会交叉引用。

## 学习路径

```
① 类型系统          ② 派发机制          ③ 闭包              ④ 并发
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 01 值/引用  │ →  │ 02 派发     │ →  │ 03 闭包     │ →  │ 04 并发     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                ↓
⑤ 语言特性                                              ⑥⑦ 触摸事件（Common）
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 05 扩展     │ →  │ 06 Hit-Test │ →  │ 07 响应链   │ →  │ 08 综合题   │ → 09 复习
│ Optional等  │    │  Common/    │    │  Common/    │    │  串联高频   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 章节目录

| 章节 | 文件 | 说明 |
|------|------|------|
| 第一章 | [01-值类型与引用类型.md](/posts/%E7%AC%AC%E4%B8%80%E7%AB%A0%E5%80%BC%E7%B1%BB%E5%9E%8B%E4%B8%8E%E5%BC%95%E7%94%A8%E7%B1%BB%E5%9E%8B.html) | struct/enum/class、栈堆、CoW、Equatable/Hashable |
| 第二章 | [02-Swift方法派发与Runtime.md](/posts/%E7%AC%AC%E4%BA%8C%E7%AB%A0swift-%E6%96%B9%E6%B3%95%E6%B4%BE%E5%8F%91%E4%B8%8E-runtime.html) | 静态/虚表/见证表/消息派发、@objc dynamic、Swizzling |
| 第三章 | [03-闭包面试八股.md](/posts/%E7%AC%AC%E4%B8%89%E7%AB%A0%E9%97%AD%E5%8C%85%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) | 逃逸/非逃逸、捕获列表、循环引用、@autoclosure |
| 第四章 | [04-并发面试八股.md](/posts/%E7%AC%AC%E5%9B%9B%E7%AB%A0%E5%B9%B6%E5%8F%91%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) | async/await、Actor、Task、Sendable、与 GCD 对比 |
| 第五章 | [05-扩展八股.md](/posts/%E7%AC%AC%E4%BA%94%E7%AB%A0%E6%89%A9%E5%B1%95%E5%85%AB%E8%82%A1optional-%E5%8D%8F%E8%AE%AE-%E6%B3%9B%E5%9E%8B-%E5%86%85%E5%AD%98.html) | Optional、协议、泛型、属性包装器、Error、内存管理 |
| 第六章 | [Common/06 事件传递链](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E4%BA%8B%E4%BB%B6%E4%BC%A0%E9%80%92%E9%93%BEhit-testing.html) | hitTest（**共用**） |
| 第七章 | [Common/07 响应链](/posts/%E7%AC%AC%E4%B8%83%E7%AB%A0%E4%BA%8B%E4%BB%B6%E5%93%8D%E5%BA%94%E9%93%BEresponder-chain.html) | 响应链（**共用**） |
| — | [Common/08 网络](/posts/%E7%AC%AC%E5%85%AB%E7%AB%A0%E7%BD%91%E7%BB%9C%E4%B8%8E-http%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) | HTTP/HTTPS/TCP（**大厂必考**） |
| — | [Common/09 性能](/posts/%E7%AC%AC%E4%B9%9D%E7%AB%A0%E6%80%A7%E8%83%BD%E4%BC%98%E5%8C%96%E4%B8%8E-uikit%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) | UITableView、图片、启动（**大厂必考**） |
| — | [Common/10 架构](/posts/%E7%AC%AC%E5%8D%81%E7%AB%A0%E6%9E%B6%E6%9E%84%E4%B8%8E%E9%A1%B9%E7%9B%AE%E5%AE%9E%E6%88%98%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) | MVVM、设计模式（**大厂必考**） |
| 第八章 | [08-综合串联题.md](/posts/%E7%AC%AC%E5%85%AB%E7%AB%A0%E7%BB%BC%E5%90%88%E4%B8%B2%E8%81%94%E9%A2%98%E9%AB%98%E9%A2%91.html) | Swift 高频综合面试题 |
| 第九章 | [09-复习建议.md](/posts/%E7%AC%AC%E4%B9%9D%E7%AB%A0%E5%A4%8D%E4%B9%A0%E5%BB%BA%E8%AE%AE.html) | 复习顺序、必背清单、Swift/OC 对照 |
| — | [大厂面试题/](/posts/%E5%A4%A7%E5%8E%82-ios-%E9%9D%A2%E8%AF%95%E7%9C%9F%E9%A2%98%E6%B1%87%E6%80%BB.html) | 阿里/字节/腾讯/美团等真题 |

## 与 OC 目录的关系

| 主题 | OC 章节 | Swift 章节 | 说明 |
|------|---------|------------|------|
| 对象模型 | 01 isa | 01 值/引用 | Swift 侧重值语义，OC 侧重 isa 链 |
| 动态机制 | 02 Runtime | 02 派发 | Swift 默认静态派发，@objc 才走消息 |
| 闭包 | 03 Block | 03 闭包 | 概念相通，语法与捕获列表不同 |
| 多线程 | 04 GCD | 04 并发 | GCD 通用 + Swift Concurrency 新增 |
| 触摸事件 | Common 06/07 | Common 06/07 | 见 [Common/](/posts/ios-%E5%85%B1%E7%94%A8%E7%9F%A5%E8%AF%86%E7%82%B9oc-/-swift-%E9%80%9A%E7%94%A8.html)，原理共用、语法对照 |

## 共用章节

第六、七章在 [Common/](/posts/ios-%E5%85%B1%E7%94%A8%E7%9F%A5%E8%AF%86%E7%82%B9oc-/-swift-%E9%80%9A%E7%94%A8.html) 目录，不重复维护两份。

## 使用说明

后续可按章节编号告诉我需要修改的内容，例如：

- 「修改第二章，补充 witness table 查找流程」
- 「更新第八章 Q2 关于 Actor 的答案」
