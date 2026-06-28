+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = '第二章：Swift 方法派发与 Runtime'
tags = ["Swift", "面试"]
categories = ['iOS 面试']
+++

# 第二章：Swift 方法派发与 Runtime

## 2.1 四种派发方式（必背）

| 派发方式 | 触发条件 | 性能 | 动态性 |
|----------|----------|------|--------|
| **Direct / Static** | `final class`、`static`、`private`、`struct/enum` 方法 | 最快，编译期确定 | 无 |
| **VTable（虚表）** | `class` 中可 override 的实例方法 | 较快 | 支持继承多态 |
| **Witness Table** | 协议方法（`protocol` conformance） | 中等 | 协议多态 |
| **Message（消息）** | `@objc dynamic` | 最慢 | 与 OC Runtime 互通 |

```
编译器默认策略
├── struct/enum ──► 静态派发
├── class 方法
│   ├── final / private ──► 静态派发（可内联）
│   └── 可 override ──► VTable
├── protocol 方法 ──► Witness Table
└── @objc dynamic ──► objc_msgSend（消息派发）
```

**与 OC 对比**：OC **所有**实例方法默认消息派发；Swift **默认静态派发**，性能更好，但动态性需显式开启。

---

## 2.2 VTable 查找流程

```
实例 ──► 类型 metadata ──► vtable ──► 按方法索引取 IMP ──► 调用
         找不到 ──► 沿 superclass vtable 查找
```

- 每个 class 有一张虚表，存可 override 方法的函数指针
- `final` 方法不进 vtable，直接静态派发

---

## 2.3 Witness Table（协议见证表）

协议类型（existential）调用方法时：

```
any Drawable ──► Protocol Witness Table (PWT)
                 ├── 指向具体类型的 conform 实现
                 └── 按 protocol requirement 索引查找
```

**面试点**：
- **泛型 `<T: Protocol>`** 编译期单态化，常 **静态派发**（更快）
- **`any Protocol`（existential）** 运行时走 Witness Table
- Swift 5.7+ `any` 关键字显式标记 existential

```swift
protocol Drawable { func draw() }

func render(_ item: any Drawable) {  // existential，witness table
    item.draw()
}

func renderGeneric<T: Drawable>(_ item: T) {  // 单态化，可能静态派发
    item.draw()
}
```

---

## 2.4 @objc、dynamic、nonobjc

| 修饰符 | 作用 |
|--------|------|
| `@objc` | 暴露给 OC Runtime，可被 selector 调用 |
| `@objc dynamic` | 走消息派发，支持 Swizzling、KVO |
| `@nonobjc` | 禁止 OC 可见 |
| `final` | 禁止 override，促静态派发 |

```swift
class ViewModel: NSObject {
    @objc dynamic func track() { }  // 可被 Method Swizzling
}
```

**KVO in Swift**：必须 `@objc dynamic` + 继承 `NSObject`，否则不生效。

---

## 2.5 Swift Runtime 与 OC Runtime

| | OC Runtime | Swift Runtime |
|--|------------|---------------|
| 核心 | `objc_msgSend`、isa、方法列表 | Metadata、VTable、Witness Table |
| 反射 | 强大（class_getInstanceMethod 等） | 有限（Mirror，性能差） |
| 动态添加方法 | `class_addMethod` | 不行（除非 `@objc` 走 OC Runtime） |
| 类型信息 | 运行时完整 | 大部分编译期，Metadata 存 mangled name |

---

## 2.6 方法修饰对派发的影响

```swift
class Animal {
    func speak() { }              // vtable
    final func breathe() { }      // static
    static func species() { }     // static
}

extension Animal {
    func trick() { }               // 静态派发！（extension 中默认）
    @objc func legacy() { }       // 消息派发
}
```

**陷阱**：extension 里新增的 **实例方法** 不能 override，且默认 **静态派发**（存在同名 class 方法时可能隐藏而非 override）。

---

## 2.7 高频面试 Q&A

### Q1：Swift 为什么比 OC 快？

- 默认静态派发 + 内联优化
- 值类型减少堆分配
- 泛型单态化，编译期特化

### Q2：什么情况必须用 @objc dynamic？

- KVO
- Method Swizzling
- 需要 `perform(_:with:)` 等 OC Runtime API

### Q3：protocol extension 里的方法怎么派发？

- 带 `protocol requirement` 的 → witness table（通过 protocol 类型调用时）
- 仅在 extension 里实现的「默认实现」→ 通过 protocol 类型调用走 witness table；直接通过具体类型调用可能 **静态派发**（**静态派发陷阱** 常考）

```swift
protocol P { func foo() }
extension P { func foo() { print("default") } }
struct S: P { func foo() { print("S") } }

let s: P = S()
s.foo()  // "S" — witness table

let concrete = S()
concrete.foo()  // "S" — 可能静态派发直接调 S.foo()
```

### Q4：Swift 能做 Method Swizzling 吗？

可以，但仅限 `@objc dynamic` 方法 + NSObject 子类，本质仍走 OC Runtime。详见 [OC 第二章](../OC/02-OC动态解析Runtime.md)。
