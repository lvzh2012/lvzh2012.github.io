+++
date = '2026-08-17T22:24:05+08:00'
draft = true
weight = 8
title = '第八章：RunLoop 源码面试题（基于 CFRunLoop.c）'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# 第八章：RunLoop 源码面试题（基于 CFRunLoop.c）

> **学习位置**：学完 [第五章 多线程](/posts/%E7%AC%AC%E4%BA%94%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) 后阅读。RunLoop 连接多线程与 [Common 触摸事件](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E4%BA%8B%E4%BB%B6%E4%BC%A0%E9%80%92%E9%93%BEhit-testing.html)。

---

## 8.0 高频考点速查（面试前先过一遍）


| 考点                     | 一句话答案                                                                | 章节      |
| ---------------------- | -------------------------------------------------------------------- | ------- |
| **RunLoop 是什么**        | 线程的事件循环：取事件 → 调回调 → 休眠等待 → 被唤醒 → 循环                                  | §8.1    |
| **与线程关系**              | **一一对应**；主线程自动 run，子线程默认不 run                                        | Q9      |
| **为何不忙等**              | 休眠前 `mach_msg` **进内核态**，零 CPU                                        | Q3      |
| **Source0 vs Source1** | Source0 **手动 WakeUp**；Source1 **mach_port 自动唤醒**                     | §8.4、Q6 |
| **Mode 隔离**            | 只处理**当前 Mode** 下的 Source/Timer；滑动切 **UITracking**                    | Q4、Q21  |
| **CommonModes**        | 不是真 Mode，是 `_commonModes` **标记集**，item 同步到多个 Mode                    | Q13     |
| **AutoreleasePool**    | **Entry push**；**BeforeWaiting pop+push**；**Exit pop**               | Q1      |
| **主队列 GCD**            | `dispatch_async(main)` → **dispatch source** → `__CFRunLoopDoBlocks` | Q7、Q22  |
| **afterDelay**         | 底层是 **Timer**，不是 Source                                              | Q7      |
| **scheduledTimer 陷阱**  | 只加到 **Default Mode**，滑动时 Timer 停                                     | Q19     |
| **子线程保活**              | 先 **addPort/addTimer**，再 `[runLoop run]`                             | Q9      |
| **卡顿监控**               | Observer 测 **BeforeSources → AfterWaiting** 耗时                       | Q8、Q12  |


---

## 8.1 RunLoop 概述


| 主题                  | 要点                                                                     |
| ------------------- | ---------------------------------------------------------------------- |
| **RunLoop**         | 触摸、Timer、Source 由 RunLoop 驱动；**主线程默认开启**；子线程需 `run`                    |
| **AutoreleasePool** | `AutoreleasePoolPage` 双向链表；RunLoop **休眠/唤醒** 时 drain                   |
| **与线程**             | 每条线程最多一个 RunLoop（**存在线程 → RunLoop 一一对应**）；主线程 RunLoop 在 `main` 里自动 run |


```
主线程 RunLoop（UIApplicationMain 内 CFRunLoopRun）
  ├── Source0（触摸包装、performSelector 等应用层事件）
  ├── Source1（mach_port 内核事件：触摸原始消息、Port 通信）
  ├── Timer（NSTimer、performSelector:afterDelay:）
  ├── Observer（AutoreleasePool、卡顿监控）
  └── 休眠前 / 唤醒后 → drain AutoreleasePool
```

**生活化理解**：RunLoop 像「前台接待员」——没客人时在 `mach_msg` **里打盹**（不占 CPU）；有触摸、Timer、GCD 主队列任务等「客人」敲门时被唤醒，按固定流程接待一轮，然后再睡。

---

## 8.2 RunLoop 源码核心结构（CFRunLoop.c）

RunLoop 本质是 `CFRunLoopRef` 结构体，核心字段（Apple 开源 CFRunLoop.c）：

```c
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;            // 保护内部数据结构
    pthread_t _pthread;               // 绑定的线程（一一对应）
    CFMutableSetRef _commonModes;     // CommonModes 集合（存 Mode 名称）
    CFMutableSetRef _commonModeItems; // 挂到 CommonModes 的 Source/Timer/Observer
    CFRunLoopModeRef _currentMode;    // 当前运行的 Mode
    CFMutableSetRef _modes;           // 所有注册的 Mode
    struct _block_item *_blocks_head; // dispatch 到该 RunLoop 的 block 链表
    struct _block_item *_blocks_tail;
    CFOptionFlags _sleepFlags;        // 休眠标志位
    SInt32 _sleepTime;                // 休眠时间
};
```

每个 Mode 的结构：

```c
struct __CFRunLoopMode {
    CFStringRef _name;               // Mode 名称
    CFMutableSetRef _sources0;       // Source0 集合
    CFMutableSetRef _sources1;       // Source1 集合
    CFMutableArrayRef _observers;    // Observer 数组
    CFMutableArrayRef _timers;       // Timer 数组
    CFMutableSetRef _timerPort;      // timer port
    _CFPortSet _portSet;             // 所有 port 集合（CFMessagePort / dispatch port）
    dispatch_source_t _timerSource;  // GCD timer 源
    dispatch_source_t _portSource;   // port 事件源
    Boolean _timerFired;             // 标记 timer 是否触发
    Boolean _stopped;                // 标记是否被停止
};
```

Source 结构（面试常问 **order** 字段）：

```c
struct __CFRunLoopSource {
    CFRuntimeBase _base;
    CFIndex _order;                  // 处理顺序，越小越先执行
    CFMutableBagRef _runLoops;       // 注册到哪些 RunLoop
    CFTypeRef _context;              // 回调 context
    // context 里含 perform / cancel 函数指针
};
// __CFRunLoopSourceCreate(..., order, ...)
// order == 0  → Source0
// order == -1 → Source1
```

> **重点**：同一个 RunLoop 的多个 Mode 之间 **Source/Timer/Observer 隔离**，切换 Mode 后只处理该 Mode 下的项。  
> **重点**：`CFRunLoopGetMain()` 返回全局唯一主 RunLoop；`CFRunLoopGetCurrent()` 通过 **TLS** 按线程取/建，子线程首次调用才创建。

---

## 8.3 RunLoop 生命周期：一次完整循环（源码级）

入口：`CFRunLoopRun` → `CFRunLoopRunSpecific` → 内部 `__CFRunLoopRun`。

```
① 通知 Observer：kCFRunLoopEntry                 // 进入 RunLoop，push 自动释放池
② 通知 Observer：kCFRunLoopBeforeTimers          // 即将处理 Timer
③ 通知 Observer：kCFRunLoopBeforeSources         // 即将处理 Source
④ 执行 Source0（非端口事件，触摸/performSelector）
    └── 只处理「已 signal 且 order 排序」的 Source0
⑤ 执行 blocks 队列（__CFRunLoopDoBlocks）
    └── 含 dispatch_async(main_queue) 提交的 block
⑥ 通知 Observer：kCFRunLoopBeforeWaiting        // 即将休眠，pop+push 自动释放池
⑦ __CFRunLoopDoObservers 检查是否要退出 → 否
    ├── 计算最近 Timer 超时 → 设置 sleepTime
    ├── mach_msg 等待唤醒（合并当前 Mode 所有 port）
    ├── 唤醒方式：
    │   ├─ mach_msg 收到端口消息（Source1）
    │   ├─ Timer 超时
    │   ├─ dispatch 到该 RunLoop 的 block（主队列）
    │   └─ 其他线程主动 CFRunLoopWakeUp
    └── 收到信号 → 继续
⑧ 通知 Observer：kCFRunLoopAfterWaiting         // 已唤醒
⑨ 处理唤醒事件：
    ├── mach_msg 端口消息 → Source1 回调
    ├── Timer 触发 → Timer 回调
    └── RunLoop 被 CFRunLoopStop → 检查 stopped 标志 → 退出
⑩ 回到步骤②，直到被停止
⑪ 通知 Observer：kCFRunLoopExit              // 退出 RunLoop，最终 pop 池
```

**一轮循环里「主线程更新 UI」的典型路径**：

```
用户滑动 TableView
  → RunLoop 切到 UITrackingRunLoopMode
  → 处理 Source1（触摸 mach_msg）→ Source0（UIEvent）
  → UIApplication sendEvent → hitTest
  → 某处 dispatch_async(main, ^{ reload cell })
  → 下一轮 __CFRunLoopDoBlocks 执行 block → setNeedsLayout/display
  → BeforeWaiting → mach_msg 休眠
```

---

## 8.4 Source0 vs Source1 源码区别


|      | Source0                                           | Source1                                    |
| ---- | ------------------------------------------------- | ------------------------------------------ |
| 底层   | 应用层事件，**不依赖 mach_port**                           | 基于 **mach_port** 的内核事件                     |
| 触发   | 手动 `CFRunLoopSourceSignal` + `CFRunLoopWakeUp` 唤醒 | **mach_msg 自动唤醒** RunLoop                  |
| 典型场景 | 触摸事件（IOKit 回调后包装为 Source0）、`performSelector`      | CFMessagePort、mach port 通信、**原始 HID 触摸消息** |
| 源码生成 | `__CFRunLoopSourceCreate` 时 `order=0`             | `order=-1`                                 |
| 处理时机 | ④ 步 `__CFRunLoopDoSources0`                       | ⑨ 步收到 port 消息后回调                           |


**Source0 完整三步（必背）**：

```
① 事件产生（如 IOKit 把 HID 事件转成待处理项）
② CFRunLoopSourceSignal(source)     // 仅标记 source 为「待处理」，RunLoop 可能还在 mach_msg 睡
③ CFRunLoopWakeUp(runLoop)          // 向 RunLoop 的 wake port 发消息，mach_msg 返回
④ 下一轮循环 __CFRunLoopDoSources0  // 真正执行 source 的 perform 回调
```

**Source1 为何不用 WakeUp**：RunLoop 在 ⑦ 步 `mach_msg` 阻塞时，内核直接把消息投递到 **Source1 绑定的 port**，`mach_msg` 立即返回，进入 ⑨ 步处理。

---

## 8.5 RunLoop 与 AutoreleasePool 的源码联动

在 CFRunLoop.c 中，Observer 回调 `_wrapRunLoopWithAutoreleasePoolHandler`：

```
kCFRunLoopEntry           → objc_autoreleasePoolPush()        // 创建外层池
kCFRunLoopBeforeWaiting   → objc_autoreleasePoolPop()         // drain 本轮临时对象
                          → objc_autoreleasePoolPush()        // 立刻建新池，供休眠期间 autorelease
kCFRunLoopExit            → objc_autoreleasePoolPop()        // RunLoop 退出，最终 drain
```

即：**每轮循环开始 push，休眠前（BeforeWaiting）pop 旧池 + push 新池，退出时最终 pop**。AutoreleasePool 在 RunLoop 每轮迭代中 **至少 drain 一次**（休眠前）。

**具体例子**（主线程）：

```objc
// 假设本轮 RunLoop 处理了触摸、网络回调包装、临时 NSString 等
NSString *tmp = [NSString stringWithFormat:@"%d", arc4random()]; // autorelease
// ... 业务代码产生大量临时对象 ...

// ⑥ BeforeWaiting：
//   pop → tmp 等临时对象 release
//   push → 新空池，线程休眠期间若有人 autorelease 不会无限堆积
```

> **面试结论**：主线程没有 `@autoreleasepool {}` 也不会无限泄漏，因为 **RunLoop 每轮 BeforeWaiting 会 drain**；子线程无 RunLoop 时，临时对象要靠 **手动 @autoreleasepool** 或线程结束才释放。

---

## 8.6 RunLoop 与 GCD 的源码交互

主队列 `dispatch_get_main_queue()` 的 block **不是**直接在新线程跑，而是挂到主 RunLoop：

```
子线程/网络回调：
  dispatch_async(dispatch_get_main_queue(), ^{
      self.label.text = @"ok";
  });

源码路径（简化）：
  _dispatch_main_queue_push
    → 把 block 挂到主 RunLoop 的 _blocks 链表
    → CFRunLoopWakeUp(mainRunLoop)
  主 RunLoop 被唤醒
    → ⑤ __CFRunLoopDoBlocks
    → 执行 block，更新 UI
```

```c
// libdispatch 与 CF 的桥（概念）
// _dispatch_main_queue_drain 最终会走到
CFRunLoopPerformBlock(mainRunLoop, kCFRunLoopDefaultMode, block);
// 或注册 dispatch_source 监听主 RunLoop 的 port
```

**重点**：`dispatch_async(main)` 与 `performSelectorOnMainThread` 最终都依赖 **主线程 RunLoop**；若主线程 RunLoop 被 **长时间 Source0 阻塞**，两者都会 **延迟执行**。

---

## 8.7 RunLoop 休眠原理

RunLoop **不会忙等**。休眠前调 `mach_msg`：

```c
// 核心：mach_msg 是系统调用，让线程进入内核态等待
// RunLoop 设置一个超时时间（最近 Timer 或 distantFuture）
mach_msg(msg, MACH_RCV_MSG, 0, sizeof(msg), port, timeout, MACH_MSG_TIMEOUT_NONE);
```


| 对比  | `while(1) {}` 忙等 | RunLoop + `mach_msg`     |
| --- | ---------------- | ------------------------ |
| CPU | **占满时间片**        | **0 占用**（内核挂起线程）         |
| 唤醒  | 无法被事件唤醒          | port 消息 / Timer / WakeUp |
| 适用  | ❌ 错误做法           | ✅ 事件驱动线程                 |


- 线程在 **内核态休眠**，不消耗 CPU
- 收到端口消息（Source1）、Timer 超时、`CFRunLoopWakeUp` → `mach_msg` 返回
- `CFRunLoopWakeUp` 本质是向 RunLoop 私有 wake port 发一条 **空 mach 消息**，让正在 ⑦ 步睡眠的线程立刻返回

---

## 8.8 RunLoop Mode 详解

### iOS 系统定义的 Mode


| Mode                                             | 用途                                |
| ------------------------------------------------ | --------------------------------- |
| `NSDefaultRunLoopMode` / `kCFRunLoopDefaultMode` | 默认状态（**同一 CFString**）             |
| `UITrackingRunLoopMode`                          | **ScrollView 滑动时**系统切换到此 Mode     |
| `NSRunLoopCommonModes`                           | **不是真 Mode**，是 `_commonModes` 标记集 |
| `GSEventReceiveRunLoopMode`                      | 系统内部，处理图形事件                       |
| `kCFRunLoopCommonModes`                          | CF 层 CommonModes 常量               |


### CommonModes 实现原理（源码）

`NSRunLoopCommonModes` 不是一个真正的 Mode，而是 `__CFRunLoop` 中 `_commonModes` 集合的标记：

```c
// 系统初始化时大致：
_commonModes = { kCFRunLoopDefaultMode, UITrackingRunLoopMode }

// 你写：
[timer addToRunLoop:runLoop forMode:NSRunLoopCommonModes];
// 源码会把 timer 加入 _commonModeItems，
// 并同步到 _commonModes 里已有的每一个 Mode
```

**滑动 TableView 时 GIF 不动（字节经典题）——完整因果链**：

```
① [NSTimer scheduledTimerWithTimeInterval:0.1 ...]
   → 内部 addTimer:forMode:NSDefaultRunLoopMode  // 只注册在 Default

② 用户开始滑动 ScrollView
   → 主 RunLoop._currentMode = UITrackingRunLoopMode

③ RunLoop 只处理 UITracking 下的 Timer/Source
   → Default Mode 里的 GIF 解码 Timer **不会被触发**

④ 解法：
[timer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
   → Timer 同时存在于 Default + UITracking，滑动时也继续 fire
```

---

## 8.9 基于源码的高频面试 Q&A

### Q1：AutoreleasePool 什么时候释放？

**三个时机（重点）**：

1. **RunLoop BeforeWaiting**：每轮循环休眠前 **pop + push**（主线程最常用）
2. **RunLoop Exit**：RunLoop 退出时 **最终 pop**
3. **手动** `@autoreleasepool {}`：作用域结束 pop；**子线程无 RunLoop 时必须靠这个**

RunLoop 每轮循环**休眠前** pop + push 一次；退出时最终 pop。线程退出时也 drain。

---

### Q2：RunLoop 和触摸事件？

主线程 RunLoop 接收触摸 → 触发 hitTest。完整路径见 **Q15**。  
简述：**Source1（mach_msg 原始 HID）→ 包装 Source0（UIEvent）→ UIApplication sendEvent**。

---

### Q3：RunLoop 为什么不会导致 CPU 忙等？（源码原理）

RunLoop **休眠前调用** `mach_msg` 系统调用，让线程进入**内核态等待**，此时线程 **不占用 CPU 时间片**。被 port/Timer/WakeUp 唤醒后才回到用户态继续执行。

所以即使主线程 RunLoop 一直在 `CFRunLoopRun`，空闲时 **CPU 占用率接近 0**——因为它在 `mach_msg` **里睡觉**，不是 `while(1)` 空转。

---

### Q4：RunLoop 内部数据结构中 Mode 之间如何隔离？

每个 `CFRunLoopMode` 维护独立的 `_sources0`、`_sources1`、`_timers`、`_observers`、`_portSet`。

RunLoop **只处理** `_currentMode` **下这五类事件**，其他 Mode 里的 Timer/Source **本轮完全忽略**。

**例子**：Timer 注册在 `NSDefaultRunLoopMode`，滑动时 `_currentMode == UITrackingRunLoopMode` → **Timer 不 fire**（不是销毁，是 **Mode 不匹配**）。

---

### Q5：CFRunLoopRunSpecific 核心流程分为几个步骤？

**10 步（建议画图口述）**：

Entry → BeforeTimers → BeforeSources → **Source0** → **DoBlocks** → BeforeWaiting → **mach_msg 休眠** → AfterWaiting → 处理 **Source1/Timer** → 循环（Stop 则 Exit）。

**记忆口诀**：**进 → 定时 → 源0 → 块 → 睡 → 醒 → 源1/Timer → 再来**。

---

### Q6：RunLoop Source0 为什么需要手动唤醒？Source1 为什么不需要？

- **Source0**：应用层事件，**不绑定 mach_port**。`CFRunLoopSourceSignal` 只是把 source 标为 pending；若 RunLoop 正在 ⑦ 步 `mach_msg` 睡眠，**必须** `CFRunLoopWakeUp` 才能让它醒来进入 ④ 步处理。
- **Source1**：基于 **mach_port**。内核 `mach_msg` 投递到 port → 正在等待的 RunLoop **自动被唤醒**，无需应用层 WakeUp。

**反例（面试追问）**：只 Signal 不 WakeUp → RunLoop 可能 **睡到下一个 Timer/port 事件** 才处理 Source0，**延迟明显**。

---

### Q7：RunLoop 中 `performSelector:withObject:afterDelay:`、`dispatch_async(main_queue)`、`mach_msg` 属于哪种 Source 或机制？


| API                           | 底层机制                                        | 在循环哪一步执行                  |
| ----------------------------- | ------------------------------------------- | ------------------------- |
| `performSelector:afterDelay:` | 创建 **CFRunLoopTimer**（**不是 Source**）        | ② Timer 阶段 / ⑨ Timer 回调   |
| `dispatch_async(main_queue)`  | **dispatch source + block 链表**              | ⑤ **__CFRunLoopDoBlocks** |
| `mach_msg` 收到的端口消息            | **Source1**                                 | ⑨ 唤醒后处理 port              |
| `performSelectorOnMainThread` | 向主 RunLoop 注册 **Source0** + Signal + WakeUp | ④ Source0                 |


---

### Q8：RunLoop Observer 可以监听哪些状态？卡顿监控用哪个？

```c
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry         = (1UL << 0),  // 进入
    kCFRunLoopBeforeTimers  = (1UL << 1),  // Timer 前
    kCFRunLoopBeforeSources = (1UL << 2),  // Source 前
    kCFRunLoopBeforeWaiting = (1UL << 5),  // 休眠前
    kCFRunLoopAfterWaiting  = (1UL << 6),  // 唤醒后
    kCFRunLoopExit          = (1UL << 7),  // 退出
};
```

**卡顿监控（重点）**：

- 方案 A：Observer 记录 `BeforeSources` **→** `AfterWaiting` 时间差 → 表示 **一轮事件处理（含 Source0/Blocks/Source1/Timer）耗时**
- 方案 B：子线程定时 **Ping 主线程**（`dispatch_semaphore` / CFRunLoopPerformBlock），超时未回应 → 主线程卡死

阈值常见 **50ms**（3 帧 @60fps）。注意 Observer 回调里 **不要做重活**，否则误报。

---

### Q9：为什么子线程默认没有 RunLoop？手动调 `[runLoop run]` 后发生了什么？

**澄清两个常见误区**：

1. 子线程 **不是「没有 RunLoop 对象」**——`CFRunLoopGetCurrent()` 首次调用会通过 **TLS** 创建并绑定。
2. 子线程是 **默认没有开启 RunLoop 循环**——没人调 `run`，且通常 **没有任何 Source/Timer**。

```c
CFRunLoopRef CFRunLoopGetCurrent(void) {
    return _CFRunLoopGet0(pthread_self());  // TLS：按 pthread 取/建
}
```

`[runLoop run]` 内部检查 `__CFRunLoopModeIsEmpty`：若当前 Mode 下 **无 Source1/Timer/Port** → **立即 return**，看起来像「run 了一下就退出了」。

**常驻线程标准写法**：

```objc
- (void)threadEntry {
    @autoreleasepool {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        // 必须添加「保活」事件源，否则 run 立刻返回，线程结束
        [runLoop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];  // Source1
        while (!self.stopped) {
            [runLoop runMode:NSDefaultRunLoopMode
                  beforeDate:[NSDate distantFuture]];
        }
        [runLoop removePort:...];
    }
}
```

---

### Q10：`CFRunLoopStop` 是如何停止 RunLoop 的？

`CFRunLoopStop(runLoop)`：

1. 设置 `runLoop->_stopped = true`
2. 调用 `CFRunLoopWakeUp(runLoop)`（wake port 发消息）
3. RunLoop 在 ⑦/⑨ 后检查 `_stopped` → 跳出循环 → `kCFRunLoopExit` → `[runLoop run]` 返回

**注意（重点）**：`CFRunLoopStop` **必须在目标线程** 的 RunLoop 上调用（`performSelector:onThread:` 派过去），否则 **竞态/无效**。

---

### Q11：CADisplayLink 和 NSTimer 底层区别？


|      | NSTimer                                    | CADisplayLink                               |
| ---- | ------------------------------------------ | ------------------------------------------- |
| 底层   | **CFRunLoopTimerRef**，`mach_absolute_time` | **CVDisplayLink**（CoreVideo），与 **VSync** 同步 |
| 触发时机 | 设定 fireDate 到达                             | **每次屏幕刷新**（约 60/120Hz）                      |
| 精度   | 受 RunLoop Mode、主线程阻塞影响，**不精确**             | 与 VSync 对齐，**适合动画**                         |
| Mode | 滑动 UITracking 下 Default 的 Timer 停          | 同样受 Mode 影响，需 **CommonModes**               |
| 循环引用 | Timer → target（常见泄漏）                       | displayLink → target                        |


---

### Q12：手写卡顿监控的核心代码（RunLoop 观察者方案）

```objc
static CFRunLoopObserverRef s_observer;

void startRunLoopMonitor(void) {
    s_observer = CFRunLoopObserverCreateWithHandler(
        kCFAllocatorDefault,
        kCFRunLoopAllActivities,
        YES,   // repeats：每轮都回调
        0,
        ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            static int64_t beginMs = 0;
            if (activity == kCFRunLoopBeforeSources) {
                beginMs = (int64_t)(CACurrentMediaTime() * 1000);
            } else if (activity == kCFRunLoopAfterWaiting && beginMs > 0) {
                int64_t cost = (int64_t)(CACurrentMediaTime() * 1000) - beginMs;
                if (cost > 50) {
                    // 卡顿：采集主线程堆栈上报（BSBacktraceLogger 等）
                }
                beginMs = 0;
            }
        });

    // 必须 CommonModes，否则滑动时 Observer 也不触发
    CFRunLoopAddObserver(CFRunLoopGetMain(), s_observer, kCFRunLoopCommonModes);
}
```

---

### Q13：RunLoop 的 `_commonModes` 和 `_commonModeItems` 是什么关系？

- `_commonModes`：`CFMutableSetRef`，存 **Mode 名称**（默认含 Default + UITracking）
- `_commonModeItems`：挂到 CommonModes 下的 **Source/Timer/Observer 集合**
- 新 item 以 CommonModes 注册 → 加入 `_commonModeItems`，并 **同步到** `_commonModes` **里已有每个 Mode**
- 之后若系统往 `_commonModes` **新增 Mode 名**，`_commonModeItems` 里的 item **自动同步过去**

---

### Q14：RunLoop 循环中 BeforeWaiting 之前为什么要设置 `_sleepTime`？

源码 `__CFRunLoopSetSleepTime` 记录 **进入 mach_msg 的时刻**，用途：

1. `AfterWaiting` 时用 `now - _sleepTime` 算 **实际休眠时长**
2. 卡顿/ watchdog 分析：区分 **「真在处理事件」** vs **「睡太久没醒」**
3. 调试 RunLoop 阻塞

---

### Q15：一次触摸事件在 RunLoop 层面的完整传递路径是怎样的？

```
① 硬件触摸 → IOKit 驱动
② SpringBoard / 系统通过 mach port 把 HID 事件发给 App 进程
③ 主线程 RunLoop ⑦ mach_msg 收到消息 → 唤醒（Source1）
④ Source1 回调（如 __IOHIDEventSystemClientQueueCallback）
⑤ 包装成 UIEvent，CFRunLoopSourceSignal(Source0) + CFRunLoopWakeUp
⑥ 下一轮 ④ __CFRunLoopDoSources0 → UIApplication sendEvent:
⑦ hitTest → touchesBegan/Moved/Ended 沿响应链分发
⑧ BeforeWaiting → drain 临时 autorelease 对象 → mach_msg 再睡
```

**要点**：同一次触摸会经历 **Source1 唤醒 → Source0 处理** 两阶段，不是一次完成。

---

### Q16：`CFRunLoopTimerRef` 的时间精度如何保证？为什么有时不准确？

CFRunLoopTimer 基于 `mach_absolute_time` + `mach_timebase_info` 转纳秒；fireDate 与 **当前 Mode 的 Timer 数组** 比较。

**不准的三大原因（重点）**：

1. **Mode 隔离**：Timer 不在 `_currentMode` → **到了时间也不 fire**
2. **主线程阻塞**：Source0/Blocks 执行过久 → Timer **推迟到下一轮**
3. **tolerance（iOS 7+）**：系统可 **合并 Timer** 省电，`fireDate` 会漂移

```c
// 简化：只有进入 Timer 处理阶段且 mode 匹配才真正回调
if (timer->fireDate <= now && mode->_timers contains timer) {
    __CFRunLoopDoTimer(runLoop, timer, mode);
}
```

---

### Q17：`[runLoop run]`、`runMode:beforeDate:`、`CFRunLoopRunInMode` 有什么区别？


| API                                                           | 行为                                                              |
| ------------------------------------------------------------- | --------------------------------------------------------------- |
| `[runLoop run]`                                               | 等价 `CFRunLoopRunInMode(Default, distantFuture, false)`，**永不超时** |
| `runMode:beforeDate:`                                         | 跑 **指定 Mode**，到 **date 或事件** 返回；可 `while + runMode` **实现可控退出**  |
| `CFRunLoopRunInMode(mode, seconds, returnAfterSourceHandled)` | C 层；第三参 `true` 时 **处理完一个 Source 就 return**（少见）                  |


**线程保活常用**：`while (!stopped) { [runLoop runMode:NSDefaultRunLoopMode beforeDate:distantFuture]; }`  
配合 `CFRunLoopStop` 在目标线程退出循环。详见 [第五章 §5.8](/posts/%E7%AC%AC%E4%BA%94%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html)。

---

### Q18：`NSTimer scheduledTimer...` 和 `timerWithTimeInterval` + `addTimer:forMode:` 有何陷阱？

```objc
// 陷阱：scheduled 系列内部等价于：
NSTimer *t = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
[[NSRunLoop currentRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];  // 仅 Default！

// 滑动 ScrollView 时 Timer 暂停 → 用 CommonModes：
[[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
```

**面试结论**：`scheduledTimer` **方便但默认 Mode 不对**；生产环境动画/轮询 Timer **几乎都要 CommonModes**。

---

### Q19：NSTimer 为什么容易造成循环引用？怎么破？

**引用链**：

```
RunLoop → Mode._timers → NSTimer（强引用）
NSTimer → target（强引用，非 block 版本）
target → 可能持有 Timer 或 RunLoop 相关对象
```

**解法**：

```objc
// 1. block 版 Timer（iOS 10+），用 weakSelf
[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) { [timer invalidate]; return; }
    [self tick];
}];

// 2. 中间代理 NSProxy / 弱引用 target 包装
// 3. 必须在 dealloc 或 viewWillDisappear 里 [timer invalidate]
```

**重点**：`invalidate` 后 Timer 从 RunLoop **移除**，循环才断。

---

### Q20：`CFRunLoopPerformBlock` 和 `performSelectorOnMainThread` 源码上怎么走？

```objc
CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
    // 更新 UI
});
```

**路径**：block 挂到 RunLoop `_blocks` **链表** → `CFRunLoopWakeUp` → ⑤ `__CFRunLoopDoBlocks` 执行。

`performSelectorOnMainThread`：创建 **Source0** → `Signal` + `WakeUp` → ④ **Source0** 阶段执行 selector。


|      | performSelectorOnMainThread | dispatch_async(main)     | CFRunLoopPerformBlock |
| ---- | --------------------------- | ------------------------ | --------------------- |
| 机制   | Source0                     | dispatch source + blocks | blocks 链表             |
| 执行阶段 | ④ Source0                   | ⑤ DoBlocks               | ⑤ DoBlocks            |
| 典型场景 | 老 API                       | **GCD 首选**               | CF 层 / 底层库            |


三者都 **依赖主 RunLoop**；主线程卡顿时 **全部排队**。

---

### Q21：`UIApplicationMain` 如何启动主线程 RunLoop？

```objc
// main.m
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

`UIApplicationMain` 内部（简化）：

```
创建 UIApplication、AppDelegate
注册 Source1（系统事件 port）
CFRunLoopAddSource(mainRunLoop, source, kCFRunLoopCommonModes)
注册 AutoreleasePool Observer
CFRunLoopRun()   // 永不返回，直到 App 退出
```

**面试结论**：**主线程 RunLoop 在 UIApplicationMain 里自动 CFRunLoopRun**，开发者不需要手动 `[runLoop run]`。

---

### Q22：Source 的 `order` 字段有什么作用？

`__CFRunLoopSourceCreate(..., order, ...)` 的 **order 越小越先执行**。

- **Source0 / Source1 分组**后，各自按 order **排序回调**
- 系统内部用 order 保证 **触摸、GCD、自定义 Source** 的优先级
- **order=0 → Source0；order=-1 → Source1** 是创建时的类型区分，不是优先级比较

---

### Q23：Observer 的 `repeats` 参数是什么意思？

```c
CFRunLoopObserverCreate(allocator, activities, repeats, order, callout, context);
```

- `repeats = true`：每个 Activity 每次出现都回调（卡顿监控必须 true）
- `repeats = false`：对应 Activity **只回调一次**，常用于 **单次** Entry/Exit 钩子

---

### Q24：`runUntilDate:` 适合什么场景？有什么坑？

```objc
// 在子线程「临时跑一会儿 RunLoop」等异步回调（老 API 常见）
[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
```

- **适合**：子线程里 **短暂** 等 Network 回调（NSURLConnection 时代）、同步等待 Port 消息
- **坑 1**：超时返回后 **RunLoop 停了**，后续 Timer 可能不 fire
- **坑 2**：在主线程调用会 **阻塞 UI**（处理事件直到 date）
- **现代替代**：GCD semaphore / dispatch_group / async-await，少用手动 runUntilDate

---

### Q25：如何用 NSPort 做线程间通信？（与 RunLoop 关系）

```objc
// 线程 A（有 RunLoop）
NSPort *port = [NSPort port];
[[NSRunLoop currentRunLoop] addPort:port forMode:NSDefaultRunLoopMode];
[port setDelegate:self];
[runLoop run];

// 线程 B 发消息
[port sendBeforeDate:[NSDate date] components:... from:otherPort reserved:0];

// 线程 A delegate 回调在 RunLoop Source1/Port 阶段执行
- (void)handlePortMessage:(NSPortMessage *)message { ... }
```

**重点**：Port 是 **Source1（mach port）**；接收线程 **必须有 RunLoop 且在 run**，否则消息 **无人处理**。

---

