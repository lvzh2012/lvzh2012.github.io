+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = '第二章：Swift 方法派发与 Runtime'
tags = ["Swift", "面试"]
categories = ['iOS 面试']
+++

# 第二章：Swift 方法派发与 Runtime

> Swift 方法 **默认不是 OC 那套 method_list + objc_msgSend**。本章讲清楚：**存在哪、怎么调、和 OC 何时相同**。

---

## 2.1 方法存在哪？Swift vs OC（必背）

### OC：method_list + SEL

```
实例 ──isa──► 类对象
                ├── cache（SEL → IMP 缓存）
                └── method_list[]
                      ├── method_t { SEL, types, IMP }
                      └── ...

调用 [obj foo]  →  objc_msgSend(obj, @selector(foo))
                  →  cache → method_list → 父类链
```

方法以 **SEL（选择子）+ IMP（函数指针）** 形式挂在 **Runtime 类结构** 上，**运行时** 查找。

### Swift：Metadata + VTable / Witness Table

```
纯 Swift 方法（默认）
  └── 类型 Metadata（编译期生成）
        ├── 直接函数地址（静态派发）
        ├── vtable[]（可 override 的 class 方法）
        └── witness table（protocol 实现）

@objc / @objc dynamic
  └── 额外注册到 OC Runtime 的 method_list（与 OC 互通时才需要）
```

| 对比项 | OC | Swift（纯 Swift） |
|--------|-----|-------------------|
| 存储位置 | 类 / 元类 **method_list** | **Type Metadata** + vtable |
| 查找键 | **SEL** | 编译期 **函数符号 / vtable 索引** |
| 默认调用 | **objc_msgSend**（消息） | **直接 call / vtable / witness table** |
| 动态添加方法 | `class_addMethod` ✅ | 纯 Swift ❌（需 `@objc` 走 OC） |
| Swizzling / KVO | 默认支持 | 需 `@objc dynamic` |

**结论**：**存储和调用机制默认不一样**；只有 `@objc dynamic`（或部分 `@objc` 暴露）才进 OC 的 method_list，走消息派发。

---

## 2.2 四种派发方式（必背）

| 派发方式 | 触发条件 | 存储/查找 | 性能 | 动态性 |
|----------|----------|-----------|------|--------|
| **Direct / Static** | struct/enum、final、private、extension 默认 | 编译期固定地址 | 最快，可内联 | 无 |
| **VTable** | class 中 **可 override** 的实例方法 | metadata → vtable[index] | 较快 | 继承多态 |
| **Witness Table** | 通过 **protocol 类型** 调用 requirement | PWT → 实现 | 中等 | 协议多态 |
| **Message** | `@objc dynamic` | OC method_list + SEL | 最慢 | 与 OC 相同 |

```
编译器决策树
├── struct / enum 方法 ──────────────► 静态派发
├── class 方法
│   ├── final / private ───────────► 静态派发
│   └── 可 override ───────────────► VTable
├── extension 新增实例方法 ────────► 静态派发（陷阱 ⚠️）
├── 经 protocol 类型调用 requirement ► Witness Table
├── 泛型 <T: P> 单态化 ───────────► 常静态派发
└── @objc dynamic ─────────────────► objc_msgSend
```

**与 OC 对比**：OC **所有**实例方法默认消息派发；Swift **默认静态**，性能更好，动态性需显式开启。

---

## 2.3 一次方法调用的完整流程

### 情况 A：静态派发（最常见）

```swift
struct Point { func move() { } }
let p = Point()
p.move()
```

```
编译期：
  1. 确定类型 Point
  2. 确定 move() 的函数地址（无多态）
  3. 生成直接 call 指令（Whole Module Optimization 下可能内联进调用方）

运行时：无 vtable、无 msgSend，CPU 直接跳转到函数
```

### 情况 B：VTable 派发（class 多态）

```swift
class Animal {
    func speak() { print("?") }      // 进 vtable
    final func breathe() { }         // 不进 vtable，静态
}
class Dog: Animal {
    override func speak() { print("wang") }
}

let a: Animal = Dog()
a.speak()
```

```
运行时：
  1. 读实例的类型 metadata（HeapObject 头 + 类型指针）
  2. 查该类型的 vtable，按 speak 的固定槽位取函数指针
  3. 调用 IMP；子类 Dog 的 vtable 该槽指向 Dog.speak
  4. 若未 override，沿用父类 vtable 条目
```

```
实例 ──► 类型 Metadata ──► vtable[speak 索引] ──► 函数指针 ──► call
```

- 每个 class 一张 **虚表**，只收录 **可 override** 的实例方法
- `final` / `static` / `class func`（部分）不进 vtable 或走静态

### 情况 C：Witness Table（协议多态）

```swift
protocol Drawable { func draw() }
struct Circle: Drawable { func draw() { } }

func render(_ item: any Drawable) {
    item.draw()    // existential → witness table
}
```

```
运行时：
  1. any Drawable 是 existential 容器（小/大容器）
  2. 容器内持有：具体值 + Protocol Witness Table 指针
  3. draw() 在 PWT 中有固定索引 → 调到 Circle.draw
```

**泛型对比**（常走静态派发）：

```swift
func render<T: Drawable>(_ item: T) {
    item.draw()    // 编译期为每个 T 特化，常直接 call Circle.draw
}
```

### 情况 D：消息派发（@objc dynamic）

```swift
class VM: NSObject {
    @objc dynamic func track() { }
}
vm.track()
```

```
与 OC 完全相同：
  objc_msgSend(vm, @selector(track))
    → isa → cache → method_list → IMP
```

用于 KVO、Method Swizzling、`perform(_:with:)` 等。

---

## 2.4 方法「存储」细节

### class 实例在堆上的布局（简化）

```
┌─────────────────────────┐
│ 引用计数 + 标志位        │
│ 类型 Metadata 指针  ────┼──► TypeDescriptor
│ 字段 ivars…              │         ├── vtable
└─────────────────────────┘         ├── field offsets
                                    └── ...
```

Swift **原生方法**描述在 **Metadata / SIL 生成的 vtable** 里，**不是** OC 的 `method_t` 链表（除非 `@objc` 导出）。

### @objc 与 @objc dynamic 的区别

| 修饰 | 暴露给 OC | 派发方式 | 典型用途 |
|------|-----------|----------|----------|
| 无 | ❌ | Swift 静态/VTable | 纯 Swift 代码 |
| `@objc` | ✅ selector 可见 | 仍多为 **Swift 派发**；OC 侧可调但不一定 msgSend |
| `@objc dynamic` | ✅ | **强制 objc_msgSend** | KVO、Swizzling |

```swift
class Person: NSObject {
    func swiftOnly() { }           // 仅 Swift Metadata
    @objc func forOC() { }        // 进 OC 命名空间，派发未必是 msgSend
    @objc dynamic var age: Int = 0  // KVO 必须这样
}
```

**KVO**：必须 `@objc dynamic` + `NSObject` 子类，底层仍是 isa-swizzling + 子类 setter（见 [OC/08 Q2](/posts/%E7%AC%AC%E5%85%AB%E7%AB%A0%E7%BB%BC%E5%90%88%E4%B8%B2%E8%81%94%E9%A2%98%E9%AB%98%E9%A2%91.html)）。

---

## 2.5 extension 的静态派发陷阱（高频）

```swift
class Animal {
    func speak() { print("animal") }
}

extension Animal {
    func trick() { print("trick") }   // extension 新增 → 默认静态派发
    @objc func legacy() { }          // 走 OC 消息
}
```

| 特性 | class 内定义 | extension 内新增 |
|------|-------------|------------------|
| override | ✅ 可 override | ❌ 不能 override |
| 派发 | 可 override → vtable | **默认静态** |
| 与父类同名 | override | **隐藏（shadow）**，非 override |

```swift
class Dog: Animal {
    // 无法 override extension 里的 trick()
    func trick() { print("dog") }  // 与 Animal.trick 无关，静态绑定
}
```

---

## 2.6 protocol extension 派发陷阱

```swift
protocol P { func foo() }           // requirement → witness table
extension P { func foo() { print("default") } }

protocol Q { }
extension Q { func bar() { print("default") } }  // 非 requirement

struct S: P { func foo() { print("S") } }
struct T: Q { func bar() { print("T") } }

let p: P = S()
p.foo()           // "S" — witness table

let t: Q = T()
t.bar()           // "default" — bar 非 requirement，静态绑 extension 默认实现

let concrete = T()
concrete.bar()    // "T" — 具体类型静态派发 T.bar
```

**记忆**：写在 **protocol 里的方法签名** = requirement = 多态；**只在 extension 里补的实现** = 可能没有多态。

---

## 2.7 优化：WMO 与内联

- **Whole Module Optimization（-O）**：跨文件分析，**devirtualization**——编译器证明类型固定则 **把 vtable 调用改成直接 call**
- **final class / final method**：无子类 → 全部静态派发
- **`private fileprivate`**：模块内可见性限制 → 促静态派发

---

## 2.8 Swift Runtime 与 OC Runtime 对照

| | OC Runtime | Swift Runtime |
|--|------------|---------------|
| 核心 | `objc_msgSend`、isa、method_list | Metadata、VTable、Witness Table |
| 反射 | `class_getInstanceMethod` 等 | Mirror（有限、慢） |
| 动态加方法 | ✅ | 纯 Swift ❌ |
| 消息转发 | 三步转发 | 无（除非 `@objc dynamic` 走 OC） |
| 类型信息 | 运行时 SEL + 编码 | 编译期 mangled name + Metadata |

---

## 2.9 高频面试 Q&A

### Q1：Swift 和 OC 方法存储一样吗？

**不一样**。OC 用 **method_list + SEL**；Swift 用 **Metadata + vtable/witness table**。只有 `@objc dynamic` 才与 OC 共用 method_list 和 `objc_msgSend`。

### Q2：Swift 为什么比 OC 快？

默认 **静态派发 + 内联**；值类型少堆分配；泛型单态化。OC 几乎每次实例调用都 `objc_msgSend`。

### Q3：什么情况必须用 @objc dynamic？

KVO、Method Swizzling、`perform(_:with:)`、依赖 OC 消息转发的场景。

### Q4：Swift 能做 Method Swizzling 吗？

可以，但仅限 `@objc dynamic` + `NSObject` 子类。见 [OC 第二章](/posts/%E7%AC%AC%E4%BA%8C%E7%AB%A0objective-c-%E5%8A%A8%E6%80%81%E8%A7%A3%E6%9E%90runtime.html)。

### Q5：调用 `obj.method()` 怎么判断走哪条路径？

```
struct/enum/final/private     → 静态
class 可 override              → vtable
any Protocol + requirement   → witness table
@objc dynamic                → objc_msgSend
extension 新增               → 静态（除非 @objc）
```

---

## 2.10 与 OC 章节联读

| Swift | OC |
|-------|-----|
| 本章 派发 | [OC/02 消息发送与转发](/posts/%E7%AC%AC%E4%BA%8C%E7%AB%A0objective-c-%E5%8A%A8%E6%80%81%E8%A7%A3%E6%9E%90runtime.html) |
| @objc dynamic | [OC/01 isa 与类结构](/posts/%E7%AC%AC%E4%B8%80%E7%AB%A0isa-%E4%B8%8E-superclass.html) |
| 综合题 | [Swift/08 Q1](/posts/%E7%AC%AC%E5%85%AB%E7%AB%A0%E7%BB%BC%E5%90%88%E4%B8%B2%E8%81%94%E9%A2%98%E9%AB%98%E9%A2%91.html) |
