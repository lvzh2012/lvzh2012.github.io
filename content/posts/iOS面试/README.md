+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = 'iOS 面试八股文'
tags = ["面试", "索引"]
categories = ['iOS 面试']
+++

# iOS 面试八股文

> OC、Swift、UIKit 共用知识分目录维护；大厂真题单独汇总。

## 目录结构

```
iOS/
├── OC/           Objective-C 特有：isa、Runtime、Block …
├── Swift/        Swift 特有：值类型、派发、闭包、async/await …
├── Common/       平台共用：触摸事件、网络、性能、架构
└── 大厂面试题/   阿里/字节/腾讯/美团/百度等真题汇总
```

## 学习入口

| 目录 | 说明 |
|------|------|
| [OC/README.md](./OC/README.md) | Objective-C 路径（1～5、8～9 章；6～7、8～10 在 Common） |
| [Swift/README.md](./Swift/README.md) | Swift 路径（1～5、8～9 章；6～10 在 Common） |
| [Common/README.md](./Common/README.md) | 共用章节 06～10 |
| [大厂面试题/README.md](./大厂面试题/README.md) | **按公司整理的真题 + TOP50 高频** |

## 推荐学习顺序

```
OC/Swift 01～05（语言底层）
    → Common 06～07（触摸事件）
    → Common 08～10（网络、性能、架构）  ← 大厂必考
    → OC/Swift 08（综合串联）
    → 大厂面试题（按目标公司刷题）
```

## 共用章节

| 章节 | 文件 |
|------|------|
| 第六章 事件传递链 | [Common/06](./Common/06-事件传递链HitTesting.md) |
| 第七章 事件响应链 | [Common/07](./Common/07-事件响应链ResponderChain.md) |
| 第八章 网络与 HTTP | [Common/08](./Common/08-网络与HTTP.md) | TCP/HTTPS/DNS/缓存 **原理详解** |
| 第九章 性能优化 | [Common/09](./Common/09-性能优化与UIKit.md) | 渲染/图片/TableView/启动 **原理详解** |
| 第十章 架构实战 | [Common/10](./Common/10-架构与项目实战.md) | MVVM/组件化 **原理详解** |
