+++
date = '2025-12-09T17:58:55+08:00'
draft = false
title = 'LLDB'
tags = ['Debug']

categories = ['Debug']

+++

# LLDB 调试工具

LLDB 是 LLVM 项目的一部分，是一个强大的调试器，用于调试 C、C++、Objective-C 和 Swift 程序。

## 基本使用

LLDB 提供了丰富的调试功能，可以帮助开发者快速定位和修复程序中的问题。

## 常用命令

- `breakpoint set` - 设置断点
- `continue` - 继续执行
- `step` - 单步执行
- `print` - 打印变量值
- `frame variable` - 显示当前帧的变量

## 高级命令

- 在循环中如何使用

  <img src="/images/lldb-breakpoint.png" alt="LLDB 断点配置" style="zoom:33%;" />

  > condition: 直接使用表达式 表达式连接用 与或非 && || !
  > ignore: 可以填写下忽略次数
  >
  > Action: 有很多种常用的就两种: 
  >
  > - Log Message: 以字符串形式输出 变量用两个@包裹
  > - Debugger Command: 跟在Console中打用法一样 p | po等的命令

## 更多信息

更多关于 LLDB 的使用方法，请参考官方文档。

[Apple lldb](https://developer.apple.com/library/archive/documentation/General/Conceptual/lldb-guide/chapters/Introduction.html)
