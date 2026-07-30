+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = 'iOS / Objective-C 面试八股文'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# iOS / Objective-C 面试八股文

> 按 **循序渐进** 顺序编排：从对象模型 → Runtime → Block → 多线程 → 属性/内存 → 触摸事件 → 综合串联 → 复习收尾。

## 学习路径

```
① 对象模型          ② 动态机制          ③ 闭包              ④ 并发
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 01 isa      │ →  │ 02 Runtime  │ →  │ 03 Block    │ →  │ 04 多线程   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                ↓
⑤ 属性            ⑥ 扩展              ⑦ RunLoop 源码        触摸（Common）
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 05 属性     │ →  │ 06 扩展     │ →  │ 07 RunLoop  │ →  │ Common 06/07│ → 08 综合题 → 09 复习
│ copy/weak   │    │ weak/RunLoop│    │ 源码面试题  │    │  Hit-Test   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 章节目录

| 章节 | 文件 | 说明 |
|------|------|------|
| 第一章 | [01-isa与superclass.md](/posts/%E7%AC%AC%E4%B8%80%E7%AB%A0isa-%E4%B8%8E-superclass.html) | isa、superclass、Non-pointer isa |
| 第二章 | [02-OC动态解析Runtime.md](/posts/%E7%AC%AC%E4%BA%8C%E7%AB%A0objective-c-%E5%8A%A8%E6%80%81%E8%A7%A3%E6%9E%90runtime.html) | 消息发送、动态解析、消息转发 |
| 第三章 | [03-Block面试八股.md](/posts/%E7%AC%AC%E4%B8%89%E7%AB%A0block-%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) | Block 类型、循环引用、copy |
| 第四章 | [04-多线程面试八股.md](/posts/%E7%AC%AC%E5%9B%9B%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) | GCD、死锁、线程安全 |
| 第五章 | [05-OC属性关键字.md](/posts/%E7%AC%AC%E4%BA%94%E7%AB%A0oc-%E5%B1%9E%E6%80%A7%E5%85%B3%E9%94%AE%E5%AD%97@property.html) | **copy / strong / weak / assign / atomic** |
| 第六章 | [06-扩展八股.md](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E6%89%A9%E5%B1%95%E5%85%AB%E8%82%A1%E5%86%85%E5%AD%98-runloop-%E5%85%B3%E8%81%94%E7%9F%A5%E8%AF%86%E7%82%B9.html) | weak 原理、RunLoop 概述、AutoreleasePool |
| 第七章 | [07-RunLoop源码面试题.md](/posts/%E7%AC%AC%E4%B8%83%E7%AB%A0runloop-%E6%BA%90%E7%A0%81%E9%9D%A2%E8%AF%95%E9%A2%98%E5%9F%BA%E4%BA%8E-cfrunloop.c.html) | CFRunLoop.c 源码结构、生命周期、16 道源码面试题 |
| — | [Common/06～07](/posts/ios-%E5%85%B1%E7%94%A8%E7%9F%A5%E8%AF%86%E7%82%B9oc-/-swift-%E9%80%9A%E7%94%A8.html) | 事件传递链、响应链（共用） |
| — | [Common/08～10](/posts/ios-%E5%85%B1%E7%94%A8%E7%9F%A5%E8%AF%86%E7%82%B9oc-/-swift-%E9%80%9A%E7%94%A8.html) | 网络、性能、架构（大厂必考） |
| 第八章 | [08-综合串联题.md](/posts/%E7%AC%AC%E5%85%AB%E7%AB%A0%E7%BB%BC%E5%90%88%E4%B8%B2%E8%81%94%E9%A2%98%E9%AB%98%E9%A2%91.html) | 高频综合题 |
| 第九章 | [09-复习建议.md](/posts/%E7%AC%AC%E4%B9%9D%E7%AB%A0%E5%A4%8D%E4%B9%A0%E5%BB%BA%E8%AE%AE.html) | 复习顺序、必背清单 |
| — | [大厂面试题/](/posts/%E5%A4%A7%E5%8E%82-ios-%E9%9D%A2%E8%AF%95%E7%9C%9F%E9%A2%98%E6%B1%87%E6%80%BB.html) | 按公司真题 |

## 使用说明

- 「修改第五章，补充 retain 与 strong 区别」
- 「更新第八章 Q3」
