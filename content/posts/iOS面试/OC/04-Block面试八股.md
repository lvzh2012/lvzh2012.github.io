+++
date = '2026-08-17T22:24:05+08:00'
draft = true
weight = 4
title = '第四章：Block 面试八股'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# 第四章：Block 面试八股

## 4.1 Block 是什么？

Block 是 **C 语言层面的闭包**，可以 **捕获外部变量**，在 OC/Swift 里广泛用于：

- 网络回调、动画 completion
- GCD 异步任务
- KVO / 通知回调

```objc
int a = 10;
void (^block)(void) = ^{
    NSLog(@"%d", a);  // 捕获外部变量
};
block();
```

**本质**：Block 是指向 **结构体** 的指针，结构体里包含 **isa、flags、invoke 函数指针、descriptor、捕获变量** 等。

> 栈 / 堆 / 全局区 / 常量区总览见 [第一章 §1.0 进程内存布局](/posts/%E7%AC%AC%E4%B8%80%E7%AB%A0isa-%E4%B8%8E-superclass.html#10-进程内存布局栈--堆--代码区--常量区基础)。

---

## 4.2 Block 的三种类型（必背）


| 类型                | 存储位置  | 创建方式                          | 是否需要 copy 到堆 |
| ----------------- | ----- | ----------------------------- | ------------ |
| **NSStackBlock**  | 栈     | 局部定义、未 copy                   | 函数返回后可能失效 ⚠️ |
| **NSMallocBlock** | 堆     | 对栈 Block `copy`               | 需手动 / ARC 管理 |
| **NSGlobalBlock** | 全局数据区 | 不捕获 auto 变量；或捕获 static/global | 永不释放         |


```objc
// 1. 全局 Block：不捕获局部 auto 变量
void (^globalBlock)(void) = ^{
    NSLog(@"hello");
};

// 2. 栈 Block → copy 后变堆 Block
void (^heapBlock)(void) = [^{
    NSLog(@"%d", a);
} copy];

// 3. ARC 下赋值给 __strong 变量，编译器自动 copy 到堆
void (^autoCopyBlock)(void) = ^{
    NSLog(@"%d", a);
};
```

**面试口诀**：

> 不捕获 auto → Global；捕获 auto → 先在栈；copy / 赋值 strong → 到堆。



### ARC 下栈 Block 少见吗？

**对，业务代码里「长期停留在栈上的 Block」很少见**，但 **底层仍会先产生栈 Block**，多数场景编译器会 **立刻 copy 到堆**。

**核心分界线：是否「逃逸」**

```
逃逸   = 可能活到函数返回之后（赋值给外部变量、传参被存储、return）
不逃逸 = 一定在函数返回前执行完（立即调用、同步参数、NS_NOESCAPE）
```

- **逃逸 → 编译器自动 copy**（栈帧销毁后还要用，必须到堆）
- **不逃逸 → 可留在栈上**（省一次堆分配 + 释放，编译器优化）


| 场景                   | ARC 行为                        |
| -------------------- | ----------------------------- |
| 赋给 `__strong` 变量     | **自动 copy** → 堆 Block         |
| 作为参数传给方法             | 通常 **自动 copy**（防逃逸后栈失效）       |
| 从方法 **return** block | **自动 copy** 到堆                |
| 放进 `NSArray` 等       | **自动 copy**                   |
| `@property (copy)`   | setter 里 copy（语义 + 兼容栈 Block） |
| **同一作用域内立刻调用、不逃逸**   | 可能 **短暂** 是栈 Block，调完即失效      |


**ARC 下仍会出现栈 Block 的场景（面试加分）**：


| 场景               | 例子                                  | 为什么留在栈上                  |
| ---------------- | ----------------------------------- | ------------------------ |
| 立即调用、不逃逸         | `^{ ... }()`                        | 同一表达式内执行完就销毁，无需堆         |
| `NS_NOESCAPE` 参数 | `enumerateObjectsUsingBlock:`（内部实现） | 函数内同步调用、不存储 block        |
| `__weak` 变量持有    | `__weak typeof(b) wb = b;`          | weak 不 copy，指向的还是原 block |
| 同步作用域内使用         | 小范围内同步执行                            | 优化器可全程不 copy             |


```objc
- (void)demo {
    int a = 10;
    // ① 创建时：__NSStackBlock__（捕获 auto）
    // ② 赋给 strong 变量：编译器插入 copy → __NSMallocBlock__
    void (^b)(void) = ^{
        NSLog(@"%d", a);
    };

    // ③ 若完全不赋值、不传递，仅同步调用：
    ^(void){ NSLog(@"%d", a); }();  // 可能全程栈上，函数返回前执行完 → 仍安全
}
```

**面试怎么答**：

> ARC 下 **很少手动** `[block copy]`，也 **很少在调试里长期看到 Stack Block**，因为编译器自动 copy。但 **三种类型原理没变**：捕获 auto 的 Block **创建在栈**，逃逸时 **必须到堆**；MRC 需手写 copy，ARC 由编译器代劳。Global Block（不捕获 auto）依然 **不在堆**。
>
> 补充：**栈 Block「短暂、快速过渡」——创建在栈，逃逸即 copy，不逃逸就留在栈上用完即焚**。不逃逸的立即调用、`noescape` 参数、`__weak` 持有等场景，栈 Block 依然存在——这是编译器的**优化**（省堆分配），不是 bug。

`@property copy` **在 ARC 下还要吗？** 要——语义是「我要独立副本」；Block 仍可能从外部传入；且 copy 对 Global Block 是 no-op，对堆 Block 可能 retain，**无害且正确**。

## 4.3 Block 内存布局（简化）

```
┌─────────────────────────────────────┐
│  isa                                  │
│  flags                                │
│  reserved                             │
│  invoke func（实际执行的函数指针）      │
│  descriptor（描述捕获变量布局）         │
├─────────────────────────────────────┤
│  捕获变量 1（如 self、a 的副本…）       │
│  捕获变量 2                           │
└─────────────────────────────────────┘
```

- **invoke**：调用 Block 时执行的函数
- **descriptor**：记录 Block 大小、copy/dispose helper（管理捕获变量的 retain/release）

---



## 4.4 变量捕获规则（高频）


| 变量类型               | 捕获方式              | Block 内能否修改 |
| ------------------ | ----------------- | ----------- |
| **局部 auto 变量**     | **值拷贝**（const 副本） | ❌ 不能直接改     |
| `__block` **局部变量** | 引用捕获（指针）          | ✅ 可以改       |
| **static 局部变量**    | 指针捕获              | ✅ 可以改       |
| **全局变量**           | 不捕获，直接访问          | ✅           |
| **对象（self）**       | retain 捕获         | 看是否循环引用     |


```objc
__block int count = 0;
void (^block)(void) = ^{
    count++;  // OK，__block 修饰后可改
};

int num = 0;
void (^block2)(void) = ^{
    // num++;  // 编译错误，普通 auto 是 const 副本
};
```

**底层结构：普通 auto 捕获 vs** `__block`**（必背）**

#### ① 普通 auto：值拷贝（const 副本），结构体里没有 forwarding

编译后（Clang 产物简化）：

```c
// int a = 10; 捕获后：
struct __main_block_impl_0 {
    struct __block_impl impl;    // isa / flags / FuncPtr(invoke)
    struct __main_block_desc_0* Desc;
    int a;                        // ← 捕获变量：值的「副本」
};
// 构造时把 10 拷进结构体，之后与外部 a 再无关系
```

**为什么不能改**：

```
普通 int a：
  外部 ──► a（栈上，地址 &a）
  block ──► a' = 10（block 结构体里的副本，新地址）

block 内写 a = 3 → 只能改 a'（私有副本）
外部再看 a → 还是 10，修改「不生效」→ 编译器直接禁止
```

- 副本是 **const 语义**：block 内写 `a = 20` 是**编译错误**（不是运行时异常）
- **值快照**：外部再改 `a`，block 里的副本不变（见 Q5 输出 1）
- 纯值拷贝，**不需要 copy/dispose helper**



#### ② `__block`：变量提升为 byref 结构体，block 内外统一「指针找真身」

```c
// 原始：__block int a = 10;   block 里写 a = 3;
// 编译后（Clang 产物简化）：
struct __Block_byref_a_0 {          // ① 变量被"提升"为结构体
    void *__isa;
    struct __Block_byref_a_0 *__forwarding;  // 真身指针（← 高频考点）
    int __flags;
    int __size;
    int a;                            // 真正的变量
};

__Block_byref_a_0 a = {0, &a, 0, sizeof(...), 10};   // ② 外部 a 变成结构体
//   __forwarding 初始指向自己（&a = 自己的地址）

struct __main_block_impl_0 {
    ...
    __Block_byref_a_0 *a;           // ③ block 里存的是「指针」，不是值
};

// ④ block 内外所有对 a 的访问都被改写：
(a.__forwarding->a) = 3;           // block 内（原 a = 3）
(a.__forwarding->a) = 2;           // block 外（原 a = 2）
NSLog(@"%d", a.__forwarding->a);   // block 外读取
```

**注意 ④**：不只 block 内部绕一层 `forwarding`——**外部代码对** `a` **的读写也被编译器改写**成 `a.__forwarding->a`。两边指向同一个结构体 → 修改天然共享。

#### ③ forwarding 指向哪里？（必背）

**规则：堆上指向自己；栈上指向堆上的那个（未 copy 时暂时指向自己）。**

```
copy 之前（block 还在栈上）：
┌─ 栈 ─────────────────────────────┐
│ __Block_byref_a_0                │
│ __forwarding ──► 自己              │
│ a = 10  ← 真身！所有读写命中这里    │
└──────────────────────────────────┘

copy 之后：
┌─ 栈（壳，仍在原栈帧）────────────┐   ┌─ 堆（真身）────────────┐
│ __Block_byref_a_0               │   │ __Block_byref_a_0    │
│ __forwarding ───────────────────┼──►│ __forwarding ──► 自己 │
│ a = 10（遗留，不再被访问）        │   │ a = 10  ← 唯一真身     │
└─────────────────────────────────┘   └───────────────────────┘
```

**为什么这么设计（悬垂指针问题）**：

```
a 是栈上局部变量，如果直接存 &a：
  函数返回 → 栈帧销毁 → &a 悬垂 → block 里读到垃圾数据

__block 的解法：
  变量装进结构体 → block 被 copy 时，结构体跟随迁移到堆
  → 栈上旧结构体的 __forwarding 指向堆上真身
  → 无论 block 在栈还是在堆，永远能找到「活着的」真身
```

**「真身 → 壳」两阶段**：


| 阶段                    | 栈上结构体的 `a`                                     |
| --------------------- | ---------------------------------------------- |
| copy 之前               | **是真身**，所有 `a` 的读写都走它                          |
| copy 之后               | **变成壳**：代码统一走 `__forwarding->a` 跳转到堆，栈上这份不再被访问 |
| block 从未 copy（全程栈上执行） | `a` **始终是真身**，壳阶段根本不存在                         |


壳里的 `a` 为什么不清零：copy 是**整块结构体拷贝**（类似 memcpy），栈壳留在原栈帧，**函数返回时自动销毁**；程序里所有访问都先经 `__forwarding` 重定向，壳里的值永远不会被读到，留着无害。

#### ④ 普通 auto vs `__block` 总结


|               | 普通 auto     | `__block`                     |
| ------------- | ----------- | ----------------------------- |
| block 里存什么    | 值副本         | `__Block_byref_*` 结构体**指针**   |
| 读写路径          | 直接读副本       | 绕 `__forwarding->a` 找真身       |
| 外部是否改写        | 不改          | **外部也改成** `a.__forwarding->a` |
| 内存是否共享        | 不共享         | **共享同一结构体**                   |
| block 内改      | 编译报错（改了无意义） | 允许（改到真身）                      |
| 逃逸安全性         | 值拷贝天然安全     | 靠 copy 迁移 + forwarding 保持有效   |
| 有 forwarding？ | ❌           | ✅                             |


**与 ARC 的关系**：ARC 下 block 逃逸即 copy → `__block` 结构体快速迁到堆、「壳」阶段很快出现；但**不逃逸**场景（渲染立即调用）里，栈上结构体**全程是真身**。详见 §4.2 逃逸分界线。

**一句话面试版**：`__block` 的本质是「**变量提升为堆可迁移的结构体，block 内外统一走指针访问真身，forwarding 解决栈→堆迁移后的寻址**」。

**其他补充**：

- MRC 下 `__block` 变量 retain 捕获的对象；ARC 下用 `__weak` 更安全
- `__block` **不能** 完全避免循环引用（Block retain 了 `__block` 结构体，结构体又 retain self）

---



## 4.5 循环引用（必考）



### 典型场景

```objc
// ❌ 循环引用：self → block → self
self.block = ^{
     [self dosomething];
};

// ✅ 方案 1：__weak + strong 校验（推荐）
__weak typeof(self) weakSelf = self;
self.block = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf doSomething];
};

// ✅ 方案 2：__block（需手动置 nil 打断环）
__block typeof(self) blockSelf = self;
self.block = ^{
    [blockSelf doSomething];
    blockSelf = nil;
};
```



### 循环引用链

```
self ──strong──► block（堆）
  ▲                │
  └──strong/retain─┘  （Block 捕获 self）
```



### 哪些 Block 容易环？


| 场景                                 | 原因                                       |
| ---------------------------------- | ---------------------------------------- |
| `self.block = ^{ [self ...] }`     | 属性 strong 持 block，block 捕获 self          |
| `NSTimer scheduledTimer... block:` | Timer → block → self，Timer 被 RunLoop 强引用 |
| AFNetworking 回调                    | self 持有 session，回调捕获 self                |
| 动画 `animations:^{}`                | 一般无环（系统不 long-term 持有）；但若赋给 self 属性则有    |


---

## 4.6 Block 与 copy


| 情况               | 行为                                             |
| ---------------- | ---------------------------------------------- |
| **MRC**          | 栈 Block 必须 `copy` 才能安全跨作用域                     |
| **ARC**          | 赋值给 `__strong` / 入 NSArray 等，**编译器自动 copy** 到堆 |
| `@property copy` | 防止外部传入栈 Block 被误用；copy 得到堆 Block               |
| **Global Block** | copy 无效果，仍是 Global                             |


```objc
@property (nonatomic, copy) void (^completionBlock)(void);
// 用 copy 而非 strong：语义正确 + 栈 Block 安全
```



### copy 前后引用计数（高频追问）

**栈 block 根本没有引用计数**：

```c
// 栈 block 的 flags 里没有 BLOCK_NEEDS_FREE 标志
// Block_retain(栈block) → 原样返回，什么都不做
// 它不参与 retain/release，寿命 = 栈帧寿命（见 4.2 / 4.6 栈失效）
```

**copy 后：堆 block 引用计数 = 1**。`Block_copy(栈block)` 的语义是**创建一个全新的堆 block**，refcount **从 1 开始**——不是把栈上的"状态"迁移过去（栈上也没有计数可迁）：

```
栈上：                          copy 后：
┌────────────────┐             ┌────────────────┐
│ 栈 block 结构体  │             │ 堆 block        │
│ flags: 无 NEEDS_FREE │       │ flags: NEEDS_FREE│
│ (无计数)          │  ──copy──► │ refcount = 1    │
└────────────────┘             └────────────────┘
栈原结构体留在栈上原样不动（后续随栈帧销毁）
```

**ARC 场景的完整记账**：

```objc
void (^b)(void) = ^{ ... };   // ① 栈 block 创建
                              // ② 编译器插 _Block_copy → 堆 block，计数=1
                              // ③ b 强持有该堆 block —— 计数就是这 1
```

**计数的存储位置与增减操作**：堆 block 的引用计数存在 **flags 字段里**（原子递增）：


| 操作                              | 计数变化                |
| ------------------------------- | ------------------- |
| `Block_copy(栈block)`            | 新堆 block **计数 = 1** |
| `Block_retain(堆block)` / 再 copy | **+1**              |
| 强变量赋值（ARC）                      | 按持有即 +1 记账          |
| `Block_release` / 变量出作用域        | **-1**，归零 → 释放      |
| `Block_retain(栈block)`          | **不变**（它没计数，原样返回）   |


**注意**：`Block_copy` 对**已是堆的 block** 调用 = `_Block_retain`（+1）；对栈 block 调用 = **新建**（=1）——两者不同，面试常挖。

> **一句话**：栈 block **没有引用计数**；`Block_copy` 是「新建堆 block」，refcount **从 1 开始**，ARC 强变量持有的就是这 1 次；再 copy/retain 才 +1。

---



## 4.7 Block 与 GCD / 多线程

> GCD 细节见 [第五章 多线程面试八股](/posts/%E7%AC%AC%E4%BA%94%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html)。

```objc
// Block 是 GCD 的任务载体
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    // 子线程
    dispatch_async(dispatch_get_main_queue(), ^{
        // 回主线程更新 UI
    });
});
```

- GCD 执行完 **不 retain Block  forever**，任务执行后释放
- 注意 Block 内 **UI 必须在主线程**

---



## 4.8 面试 Q&A



### Q1：Block 栈转堆的时机？

1. 调用 `copy`
2. ARC 下赋值给 `__strong` 变量
3. 作为函数返回值（编译器插入 copy）
4. 传入 API 明确要求 copy 的参数（如添加到 NSArray）



### Q2：`__block` 和 `__weak` 区别？


|      | `__block`          | `__weak`                    |
| ---- | ------------------ | --------------------------- |
| 目的   | 让 Block **修改**外部变量 | **打破** Block 与对象的循环引用       |
| 捕获   | 结构体包装，可改值          | weak 引用，不增加 strong 计数       |
| 循环引用 | 本身可能参与环            | 用于避免 self 被 Block strong 捕获 |




### Q3：Block 捕获 self 是 retain 吗？

ARC 下 **是的**（strong 捕获）。所以 `[self xxx]` 在 Block 里会让 Block retain self。

### Q4：`^` 和函数指针区别？

- Block 能 **捕获上下文**；函数指针只是地址
- Block 有 isa、copy/dispose 等；函数指针没有
- Block 可 inline 优化，也可在堆上



### Q5：下面输出什么？

```objc
int a = 1;
void (^block)(void) = ^{
    NSLog(@"%d", a);
};
a = 2;
block();  // 输出 1（值捕获，捕获时是副本）
```

```objc
__block int a = 1;
void (^block)(void) = ^{
    a = 3;
};
a = 2;
block();
NSLog(@"%d", a);  // 输出 3
```



### Q6：`__block` 变量的 `__forwarding` 指向哪里？普通 auto 捕获为什么没有？

- `__block`：指向「真身」——未 copy 时指向自己（栈上）；被 copy 后，**栈上结构体的 forwarding 指向堆上的新结构体**，堆上结构体指向自己
- **普通 auto**：**没有 forwarding 字段**——值拷贝，副本直接躺在 block 结构体里，不需要寻址
- **一句话**：`__block` = 「变量提升为堆可迁移的结构体 + 统一 `__forwarding->` 访问 + copy 时迁移真身」；详见 §4.4 底层结构

---



## 4.9 复习要点

1. 三种 Block 类型 + 存储位置
2. auto 值捕获 vs `__block` 引用捕获
3. 循环引用三种解法：`__weak`、`__block`+置 nil、delegate weak
4. `@property (copy)` 修饰 Block 的原因
5. 结合项目：Timer / 网络回调如何避免环
6. `__block` 底层：byref 结构体 + forwarding「真身/壳」两阶段；ARC 逃逸分界线（逃逸即 copy，不逃逸留栈）

---



## 4.10 Swift 闭包 vs OC Block（对照）



### 底层结构不同


|      | OC Block                                 | Swift 闭包                                |
| ---- | ---------------------------------------- | --------------------------------------- |
| 本质   | **结构体指针**：`isa/invoke/descriptor + 捕获副本` | **函数 + 捕获环境（context）**，引用类型             |
| 捕获介质 | 变量拷进结构体 / `__Block_byref` 结构体            | SIL 层 `closure context` / **box（堆上的盒）** |
| 调用方式 | `invoke(block, ...)` 函数指针                | `partial_apply`：函数 + 环境打包后调用            |
| 三种类型 | Stack / Malloc / Global                  | 无此概念（默认堆上引用类型，编译器可优化）                   |




### 捕获语义——核心差异（必背）

```
OC：
  普通 auto  → 值快照（捕获瞬间定格，Q5 输出 1）
  __block    → byref 结构体 + forwarding，内外都能改

Swift：
  let 常量(值类型) → 拷贝进环境
  var 局部变量     → 逃逸闭包捕获 = 装箱（box 到堆）
                     外部改 x → 闭包内读到【新值】（不是快照！近似 __block 读取）
                     闭包内改 x → 【编译错误】（Swift 刻意移除这个能力）
  类实例(self)     → 捕获引用
```

```swift
var x = 1
let c: () -> Int = { x }   // 逃逸闭包，捕获 var → 装箱
x = 2
c()   // 输出 2 —— 不是快照！（OC 普通捕获这里输出 1，见 Q5）
```

**关键点：Swift 没有** `__block`——因为「在闭包内修改外部局部变量」这个能力被 Swift **设计上移除了**：


| 想改外部变量            | 做法                            |
| ----------------- | ----------------------------- |
| 值类型               | 用类实例的属性 / `inout`（仅非逃逸）/ 全局变量 |
| 引用类型              | 直接改（引用共享）                     |
| 旧 OC `__block` 场景 | 换成**装箱 + 外部改**（闭包内只读）         |




### 逃逸（对应 §4.2 的 ARC copy 话题）


|     | OC                      | Swift                                     |
| --- | ----------------------- | ----------------------------------------- |
| 默认  | ARC 逃逸自动 copy（无标记语法）    | **默认非逃逸**（`NS_NOESCAPE` 是 OC 借 Swift 的概念） |
| 标记  | 编译器隐式判断                 | `@escaping` 显式声明                          |
| 共性  | 逃逸必须确保捕获环境存活（copy / 装箱） | 逃逸闭包捕获的 var 必须装箱                          |




### 循环引用：capture list 对应 OC 三件套

```swift
[weak self]                          // 对应 OC: __weak typeof(self) weakSelf = self;
[unowned self]                       // 对应 OC: __unsafe_unretained
[weak self] + guard let self else { return }   // 对应 OC: __strong 校验
```



### 面试 30 秒版

> Swift 闭包底层是函数 + 捕获环境，逃逸闭包捕获 var 会装箱（box），所以**外部修改闭包内可见**（区别于 OC 的 auto 快照）；但 Swift **没有** `__block`——闭包内不能直接修改捕获的局部变量，这是设计上刻意移除的能力。防循环引用用 `[weak self]`，逃逸用 `@escaping` 标记。OC 互操作时用 `@convention(block)` 桥接。

