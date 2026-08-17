+++
date = '2026-08-17T22:24:05+08:00'
draft = true
weight = 3
title = '第三章：KVO 原理（动态子类 + isa-swizzling）'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# 第三章：KVO 原理（动态子类 + isa-swizzling）

> **学习位置**：学完 [第二章 Runtime](/posts/%E7%AC%AC%E4%BA%8C%E7%AB%A0objective-c-%E5%8A%A8%E6%80%81%E8%A7%A3%E6%9E%90runtime.html) 后阅读。KVO 是 Runtime 动态性的典型应用；属性 setter 相关见 [第六章 属性关键字](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0oc-%E5%B1%9E%E6%80%A7%E5%85%B3%E9%94%AE%E5%AD%97@property.html)。

| 主题 | 章节 |
|------|------|
| **KVO 完整流程** | §3.1 |
| **动态子类重写了什么** | §3.2 |
| **高频追问（必背）** | §3.3 |
| **手动 KVO / 常见坑** | §3.4 |

---

## 3.1 KVO 原理（完整流程）

**核心**：动态子类 + isa-swizzling + 重写 setter（依赖 Runtime 消息机制）。

```
① addObserver:forKeyPath:options:context:
   ├─ 运行时动态创建子类 NSKVONotifying_Person（仅存在于内存，源码里找不到）
   ├─ object_setClass：把被观察对象的 isa 指向这个子类
   └─ 子类重写 setter / class / dealloc / _isKVOA

② 给属性赋值 [person setAge:20]（isa 已是子类，走子类 setter）
   ├─ willChangeValueForKey:@"age"     （记录旧值）
   ├─ super 的 setter，真正赋值
   └─ didChangeValueForKey:@"age"
        └─ 内部遍历观察者列表 → observeValueForKeyPath:ofObject:change:context:

③ removeObserver:forKeyPath:
   ├─ 从观察者列表移除
   └─ 无其他观察者时，isa 改回原类
```

**为什么叫 isa-swizzling？** `object_setClass` 把实例的 isa 从原类偷换成子类，所有消息（含 setter）都改走子类实现——**换 isa 即换实现**，和 Method Swizzling 换 IMP 思路一致。

---

## 3.2 动态子类重写了哪些方法

| 方法 | 作用 |
|------|------|
| `setAge:` | 调 `will/didChangeValueForKey:` 包裹真实赋值，触发回调 |
| `class` | 返回**原类**，`isKindOfClass:` 仍返回 YES，避免暴露子类 |
| `_isKVOA` | 返回 YES，标记被 KVO 过 |
| `dealloc` | 清理相关数据 |

> 子类只在内存中：`NSClassFromString(@"NSKVONotifying_Person")` 能拿到，但源码里没有。

---

## 3.3 高频追问点（必背）

| 追问 | 答法 |
|------|------|
| **isKindOfClass vs isMemberOfClass** | 前者沿继承链查 → YES；后者看 isa → NO（isa 已被改成子类） |
| **KVC 会触发 KVO 吗** | 会，`setValue:forKey:` 最终走同一 setter；数组用 `mutableArrayValueForKey:` 才能观察到插入/删除 |
| **如果属性没人观察呢？** | isa 不改、子类不创建，`setter` 走原实现，**零开销** |
| **为什么 mustBeKVOCompliant？** | 只有 KVC compliant（有 setter / ivar）的属性才能被 KVO，否则观察无效 |
| **一个对象被多次观察？** | 同一 key 注册多次 → 回调多次（应避免重复注册） |
| **Swift 里怎么办？** | 必须 `NSObject` 子类 + `@objc dynamic` 才能走这套机制（见 [Swift/02](/posts/%E7%AC%AC%E4%BA%8C%E7%AB%A0swift-%E6%96%B9%E6%B3%95%E6%B4%BE%E5%8F%91%E4%B8%8E-runtime.html)） |

---

## 3.4 手动 KVO / 常见坑

### 手动 KVO

```
重写 +automaticallyNotifiesObserversForKey: 对某 key 返回 NO
  → 系统不再自动触发，由你手动调：
     [self willChangeValueForKey:@"age"];
     _age = newAge;   // 直接改 ivar
     [self didChangeValueForKey:@"age"];
```

> 手动 KVO 用途：合并多次变更只回调一次、在赋值前后插入特殊逻辑。

### 常见坑 / 崩溃

| 场景 | 后果 / 解法 |
|------|-------------|
| 观察者未移除对象就释放 | 崩溃：`An instance of XXX was deallocated while key value observers were still registered with it` |
| 重复 add 同一 key | 回调触发多次 |
| remove 一个未注册的观察者 | 崩溃 |
| 手机端 iOS 9+ | 系统自动移除（dealloc 时无需手动 remove），但**兼容老版本仍建议成对** |

---

## 3.5 KVO vs KVC vs Notification（三兄弟区别）

| | KVO | KVC | NSNotification |
|---|---|---|---|
| 作用 | 观察**属性变化** | 赋值/取值通道 | 全局广播 |
| 机制 | 动态子类 + isa-swizzling | 找 setter/ivar | 通知中心转发 |
| 耦合 | 一对一（注册观察者） | 无 | 完全解耦（一对多） |
| 触发 | 值变化时自动 | 手动调用 | 手动 post |

**面试一句话**：KVO 是「属性变化时自动通知注册者」的实现，底层靠动态子类替换 isa 和重写 setter，值变化由 `willChangeValueForKey:` / `didChangeValueForKey:` 包裹触发。