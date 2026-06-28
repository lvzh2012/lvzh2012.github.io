+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = 'iOS / Objective-C 面试八股文'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# iOS / Objective-C 面试八股文

> 按 **循序渐进** 顺序编排：从对象模型 → Runtime → Block → 多线程 → 内存/RunLoop → 触摸事件 → 综合串联 → 复习收尾。

## 学习路径

```
① 对象模型          ② 动态机制          ③ 闭包              ④ 并发
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 01 isa      │ →  │ 02 Runtime  │ →  │ 03 Block    │ →  │ 04 多线程   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                ↓
⑤ 桥梁知识                                              ⑥⑦ 触摸事件（Common）
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 05 扩展     │ →  │ 06 Hit-Test │ →  │ 07 响应链   │ →  │ 08 综合题   │ → 09 复习
│ 内存/RunLoop│    │  Common/    │    │  Common/    │    │  串联高频   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 章节目录

| 章节 | 文件 | 说明 |
|------|------|------|
| 第一章 | [01-isa与superclass.md](./01-isa与superclass.md) | isa 指针、superclass 继承链、Non-pointer isa、类结构 |
| 第二章 | [02-OC动态解析Runtime.md](./02-OC动态解析Runtime.md) | 消息发送、动态方法解析、消息转发、Runtime API |
| 第三章 | [03-Block面试八股.md](./03-Block面试八股.md) | Block 类型、捕获、循环引用、copy、面试 Q&A |
| 第四章 | [04-多线程面试八股.md](./04-多线程面试八股.md) | GCD、NSOperation、线程安全、死锁、面试 Q&A |
| 第五章 | [05-扩展八股.md](./05-扩展八股.md) | 内存管理、weak、RunLoop、AutoreleasePool 等关联知识点 |
| 第六章 | [Common/06 事件传递链](../Common/06-事件传递链HitTesting.md) | hitTest、pointInside（**共用**） |
| 第七章 | [Common/07 响应链](../Common/07-事件响应链ResponderChain.md) | UIResponder、手势（**共用**） |
| — | [Common/08 网络](../Common/08-网络与HTTP.md) | HTTP/HTTPS/TCP（**大厂必考**） |
| — | [Common/09 性能](../Common/09-性能优化与UIKit.md) | UITableView、图片、启动（**大厂必考**） |
| — | [Common/10 架构](../Common/10-架构与项目实战.md) | MVVM、设计模式（**大厂必考**） |
| 第八章 | [08-综合串联题.md](./08-综合串联题.md) | 高频综合面试题（串联前述知识点） |
| 第九章 | [09-复习建议.md](./09-复习建议.md) | 复习顺序、必背清单与项目结合建议 |
| — | [大厂面试题/](../大厂面试题/README.md) | 阿里/字节/腾讯/美团等真题 |

## 共用章节

第六、七章在 [Common/](../Common/README.md) 目录，UIKit 原理与语言无关，仅语法不同。

## 使用说明

后续可按章节编号告诉我需要修改的内容，例如：

- 「修改第一章，补充 Tagged Pointer 细节」
- 「更新第八章 Q3 的答案」
