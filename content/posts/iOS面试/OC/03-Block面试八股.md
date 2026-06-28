+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = '第三章：Block 面试八股'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# 第三章：Block 面试八股

## 3.1 Block 是什么？

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

---

## 3.2 Block 的三种类型（必背）

| 类型 | 存储位置 | 创建方式 | 是否需要 copy 到堆 |
|------|----------|----------|-------------------|
| **__NSStackBlock__** | 栈 | 局部定义、未 copy | 函数返回后可能失效 ⚠️ |
| **__NSMallocBlock__** | 堆 | 对栈 Block `copy` | 需手动 / ARC 管理 |
| **__NSGlobalBlock__** | 全局数据区 | 不捕获 auto 变量；或捕获 static/global | 永不释放 |

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

---

## 3.3 Block 内存布局（简化）

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

## 3.4 变量捕获规则（高频）

| 变量类型 | 捕获方式 | Block 内能否修改 |
|----------|----------|------------------|
| **局部 auto 变量** | **值拷贝**（const 副本） | ❌ 不能直接改 |
| **`__block` 局部变量** | 引用捕获（指针） | ✅ 可以改 |
| **static 局部变量** | 指针捕获 | ✅ 可以改 |
| **全局变量** | 不捕获，直接访问 | ✅ |
| **对象（self）** | retain 捕获 | 看是否循环引用 |

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

**`__block` 原理简述**：

- 把变量包装成 **结构体**，Block 持有结构体指针
- MRC 下 `__block` 变量 retain 捕获的对象；ARC 下用 `__weak` 更安全
- `__block` **不能** 完全避免循环引用（Block retain 了 `__block` 结构体，结构体又 retain self）

---

## 3.5 循环引用（必考）

### 典型场景

```objc
// ❌ 循环引用：self → block → self
self.block = ^{
    [self doSomething];
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

| 场景 | 原因 |
|------|------|
| `self.block = ^{ [self ...] }` | 属性 strong 持 block，block 捕获 self |
| `NSTimer scheduledTimer... block:` | Timer → block → self，Timer 被 RunLoop 强引用 |
| AFNetworking 回调 | self 持有 session，回调捕获 self |
| 动画 `animations:^{}` | 一般无环（系统不 long-term 持有）；但若赋给 self 属性则有 |

---

## 3.6 Block 与 copy

| 情况 | 行为 |
|------|------|
| **MRC** | 栈 Block 必须 `copy` 才能安全跨作用域 |
| **ARC** | 赋值给 `__strong` / 入 NSArray 等，**编译器自动 copy** 到堆 |
| **`@property copy`** | 防止外部传入栈 Block 被误用；copy 得到堆 Block |
| **Global Block** | copy 无效果，仍是 Global |

```objc
@property (nonatomic, copy) void (^completionBlock)(void);
// 用 copy 而非 strong：语义正确 + 栈 Block 安全
```

---

## 3.7 Block 与 GCD / 多线程

> GCD 细节见 [第四章 多线程面试八股](./04-多线程面试八股.md)。

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

## 3.8 面试 Q&A

### Q1：Block 栈转堆的时机？

1. 调用 `copy`
2. ARC 下赋值给 `__strong` 变量
3. 作为函数返回值（编译器插入 copy）
4. 传入 API 明确要求 copy 的参数（如添加到 NSArray）

### Q2：`__block` 和 `__weak` 区别？

| | `__block` | `__weak` |
|--|-----------|----------|
| 目的 | 让 Block **修改**外部变量 | **打破** Block 与对象的循环引用 |
| 捕获 | 结构体包装，可改值 | weak 引用，不增加 strong 计数 |
| 循环引用 | 本身可能参与环 | 用于避免 self 被 Block strong 捕获 |

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

---

## 3.9 复习要点

1. 三种 Block 类型 + 存储位置
2. auto 值捕获 vs `__block` 引用捕获
3. 循环引用三种解法：`__weak`、`__block`+置 nil、delegate weak
4. `@property (copy)` 修饰 Block 的原因
5. 结合项目：Timer / 网络回调如何避免环
