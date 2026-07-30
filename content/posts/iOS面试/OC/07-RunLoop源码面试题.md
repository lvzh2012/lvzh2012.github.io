+++
date = '2026-07-09T20:00:00+08:00'
draft = true
title = '第七章：RunLoop 源码面试题（基于 CFRunLoop.c）'
tags = ["Objective-C", "Runtime", "面试"]
categories = ['iOS 面试']
+++

# 第七章：RunLoop 源码面试题（基于 CFRunLoop.c）

> **学习位置**：学完 [第四章 多线程](/posts/%E7%AC%AC%E5%9B%9B%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) 后阅读。RunLoop 连接多线程与 [Common 触摸事件](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E4%BA%8B%E4%BB%B6%E4%BC%A0%E9%80%92%E9%93%BEhit-testing.html)。

---

## 7.1 RunLoop 概述

| 主题 | 要点 |
|------|------|
| **RunLoop** | 触摸、Timer、Source 由 RunLoop 驱动；**主线程默认开启**；子线程需 `run` |
| **AutoreleasePool** | `AutoreleasePoolPage` 双向链表；RunLoop **休眠/唤醒** 时 drain |
| **与线程** | 每条线程最多一个 RunLoop（存在线程 → RunLoop 一一对应）；主线程 RunLoop 在 `main` 里自动 run |

```
主线程 RunLoop
  ├── Source0（触摸、performSelector）
  ├── Source1（内核事件）
  ├── Timer
  └── 休眠前 / 唤醒后 → drain AutoreleasePool
```

---

## 7.2 RunLoop 源码核心结构（CFRunLoop.c）

RunLoop 本质是 `CFRunLoopRef` 结构体，核心字段（Apple 开源 CFRunLoop.c）：

```c
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;            // 保护内部数据结构
    pthread_t _pthread;               // 绑定的线程（一一对应）
    CFMutableSetRef _commonModes;     // CommonModes 集合
    CFMutableSetRef _commonModeItems; // Common 模式下的 Source/Timer/Observer
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
    CFMutableSetRef _timerPort;      //  timer port
    _CFPortSet _portSet;             // 所有 port 集合（CFMessagePort / dispatch port）
    dispatch_source_t _timerSource;  // GCD timer 源
    dispatch_source_t _portSource;   // port 事件源
    Boolean _timerFired;             // 标记 timer 是否触发
    Boolean _stopped;                // 标记是否被停止
};
```

> 同一个 RunLoop 的多个 Mode 之间 **Source/Timer/Observer 隔离**，切换 Mode 后只处理该 Mode 下的项。

---

## 7.3 RunLoop 生命周期：一次完整循环（源码级）

CFRunLoopRunSpecific → CFRunLoopRun 的核心流程：

```
① 通知 Observer：kCFRunLoopEntry                 // 进入 RunLoop
② 通知 Observer：kCFRunLoopBeforeTimers          // 即将处理 Timer
③ 通知 Observer：kCFRunLoopBeforeSources         // 即将处理 Source
④ 执行 Source0（非端口事件，触摸/performSelector）
⑤ 执行 blocks 队列（__CFRunLoopDoBlocks）
⑥ 通知 Observer：kCFRunLoopBeforeWaiting        // 即将休眠
⑦ __CFRunLoopDoObservers 检查是否要退出 → 否
    ├── 设置 sleepTime，mach_msg 等待唤醒
    ├── 唤醒方式：
    │   ├─ mach_msg 收到端口消息（Source1）
    │   ├─ Timer 超时
    │   ├─ dispatch 到该 RunLoop 的 block
    │   └─ 其他线程主动 CFRunLoopWakeUp
    └── 收到信号 → 继续
⑧ 通知 Observer：kCFRunLoopAfterWaiting         // 已唤醒
⑨ 处理唤醒事件：
    ├── mach_msg 端口消息 → Source1 回调
    ├── Timer 触发 → Timer 回调
    └── RunLoop 被 CFRunLoopStop → 检查 stopped 标志 → 退出
⑩ 回到步骤②，直到被停止
⑪ 通知 Observer：kCFRunLoopExit              // 退出 RunLoop
```

---

## 7.4 Source0 vs Source1 源码区别

| | Source0 | Source1 |
|--|---------|---------|
| 底层 | 应用层事件，**不依赖 mach_port** | 基于 **mach_port** 的内核事件 |
| 触发 | 手动 `CFRunLoopSourceSignal` + `CFRunLoopWakeUp` 唤醒 | mach_msg 自动唤醒 RunLoop |
| 典型场景 | 触摸事件（IOKit 回调后包装为 Source0）、`performSelector:withObject:afterDelay:` | CFMessagePort、mach port 通信 |
| 源码生成 | `__CFRunLoopSourceCreate` 时 `order=0`（Source0） | `order=-1`（Source1） |

---

## 7.5 RunLoop 与 AutoreleasePool 的源码联动

在 CFRunLoop.c 中，Observer 回调 `_wrapRunLoopWithAutoreleasePoolHandler`：

```
kCFRunLoopEntry       → objc_autoreleasePoolPush()
kCFRunLoopBeforeWaiting → objc_autoreleasePoolPop() + objc_autoreleasePoolPush()
kCFRunLoopExit        → objc_autoreleasePoolPop()
```

即：**每轮循环开始 push，休眠前（BeforeWaiting）pop 旧池 + push 新池，退出时最终 pop**。也就是说，AutoreleasePool 在 RunLoop 每轮迭代中 **至少 drain 一次**（休眠前）。

---

## 7.6 RunLoop 与 GCD 的源码交互

main GCD queue 的底层机制：

```c
// dispatch_once 设置主队列 RunLoop 的 GCD source
_os_object_alloc_realized(OS_OBJECT_CLASS_DISPATCH_QUEUE);
// _dispatch_worker_thread 最终调用
_dispatch_main_queue_drain → CFRunLoopPerformBlock → __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__
```

核心：主线程 RunLoop 的 `__CFRunLoopDoBlocks` 步骤中，会执行通过 `dispatch_async(dispatch_get_main_queue(), block)` 提交的 block。它是通过向主线程 RunLoop 注册一个 **dispatch source** 实现的。

---

## 7.7 RunLoop 休眠原理

RunLoop **不会忙等**。休眠前调 `mach_msg`：

```c
// 核心：mach_msg 是系统调用，让线程进入内核态等待
// RunLoop 设置一个超时时间（distantFuture 则永远等待）
mach_msg(msg, MACH_RCV_MSG, 0, sizeof(msg), port, timeout, MACH_MSG_TIMEOUT_NONE);
```

- 线程在 **内核态休眠**，不消耗 CPU
- 收到端口消息（Source1 触发）、Timer 超时或被其他线程 `CFRunLoopWakeUp` → mach_msg 返回
- 这种方式比 `while(1)` 忙等 **高效 100 倍以上**（零 CPU 占用 vs 满核空转）

---

## 7.8 RunLoop Mode 详解

### iOS 系统定义的 Mode

| Mode | 用途 |
|------|------|
| `NSDefaultRunLoopMode` | 默认状态 |
| `UITrackingRunLoopMode` | ScrollView 滑动时切换到此 Mode |
| `NSRunLoopCommonModes` | 上面两个的合集（不是真 Mode，是标记集） |
| `GSEventReceiveRunLoopMode` | 系统内部，处理图形事件 |
| `kCFRunLoopDefaultMode` | CF 层等同 NSDefaultRunLoopMode |

### CommonModes 实现原理（源码）

`NSRunLoopCommonModes` 不是一个真正的 Mode，而是 `__CFRunLoop` 中 `_commonModes` 集合的标记：

```c
// 添加到 CommonModes 的 Source/Timer/Observer → 会同步到
// _commonModes 集合里所有已注册的 Mode
// 如：_commonModes = { NSDefault, UITracking }
// 添加一个 Timer 到 CommonModes → Timer 同时出现在两个 Mode
```

所以通过 `NSRunLoopCommonModes` 添加的 Timer，在滑动和默认模式下都能触发。

---

## 7.9 基于源码的高频面试 Q&A

### Q1：AutoreleasePool 什么时候释放？

RunLoop 每轮循环**休眠前**（BeforeWaiting）pop + push 一次；退出时最终 pop。线程退出时也 drain。或手动 `@autoreleasepool {}` 作用域结束。

### Q2：RunLoop 和触摸事件？

主线程 RunLoop 接收触摸 Source → 触发 hitTest。见 [Common/06](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E4%BA%8B%E4%BB%B6%E4%BC%A0%E9%80%92%E9%93%BEhit-testing.html)。

### Q3：RunLoop 为什么不会导致 CPU 忙等？（源码原理）

RunLoop **休眠前调用 `mach_msg`** 系统调用，让线程进入**内核态等待**，此时线程不占用 CPU 时间片。被唤醒时才回到用户态继续执行。所以即使主线程 RunLoop 一直在跑，CPU 占用率几乎为 0。

### Q4：RunLoop 内部数据结构中 Mode 之间如何隔离？

每个 `CFRunLoopMode` 维护独立的 `_sources0`、`_sources1`、`_timers`、`_observers`、`_portSet`。RunLoop 切换 Mode 时只处理当前 Mode 下的这五类事件，其他 Mode 不管。所以 `UITrackingRunLoopMode` 下 timer 不触发是因为 timer 注册在 `NSDefaultRunLoopMode`。

### Q5：CFRunLoopRunSpecific 核心流程分为几个步骤？

10 步：Entry → BeforeTimers → BeforeSources → Source0 → DoBlocks → BeforeWaiting（休眠）→ mach_msg 等待 → AfterWaiting → 处理端口/Timer → 循环（被 Stop 则 Exit）。

### Q6：RunLoop Source0 为什么需要手动唤醒？Source1 为什么不需要？

- **Source0**：应用层事件，不绑定 mach_port。触发后只 `CFRunLoopSourceSignal` 标记待处理，需配合 `CFRunLoopWakeUp` 让 RunLoop 从 mach_msg 返回，才能在下一轮循环中处理。
- **Source1**：基于 **mach_port** 的事件。内核通过 mach_msg 发消息到 RunLoop 的 port，正在 mach_msg 等待的 RunLoop 自动返回，无需手动唤醒。

### Q7：RunLoop 中 `performSelector:withObject:afterDelay:`、`dispatch_async(main_queue)`、`mach_msg` 属于哪种 Source 或机制？

- `performSelector:withObject:afterDelay:` → 底层创建了一个 **Timer**（不是 Source），由 RunLoop 的 Timer 机制触发
- `dispatch_async(dispatch_get_main_queue(), block)` → 通过向主线程 RunLoop 注册 **dispatch source**，在 `__CFRunLoopDoBlocks` 阶段执行
- 纯 `mach_msg` 唤醒 → 由 **Source1** 处理（CFMessagePort 等）

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

**卡顿监控**：监听 `BeforeSources` 和 `AfterWaiting` 的时间差，或子线程 ping 主线程 RunLoop 的超时。若 BeforeSources → AfterWaiting（即一次完整事件处理）超过阈值（如 50ms），则记录堆栈上报。

### Q9：为什么子线程默认没有 RunLoop？手动调 `[runLoop run]` 后发生了什么？

`CFRunLoopGetCurrent()` 采用 **TLS（线程局部存储）**，首次调用时创建 RunLoop 并绑定当前线程：

```c
CFRunLoopRef CFRunLoopGetCurrent(void) {
    CFRunLoopRef loop = _CFRunLoopGet0(pthread_self());  // TLS 取/建
    return loop;
}
```

但 RunLoop 只在**有事件源**时才会循环。子线程新建的 RunLoop 无 Source/Timer/Observer → 调 `run` 会立即返回。所以常驻线程必须**先添加 Port 或 Timer** 才能让 RunLoop 不退出：

```objc
// 子线程 RunLoop 要「活得住」，必须有事件源
[runLoop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];  // Source1
[runLoop run];  // mach_msg 等待 port 消息，不会立即返回
```

### Q10：`CFRunLoopStop` 是如何停止 RunLoop 的？

`CFRunLoopStop` 设置 `__CFRunLoop->_stopped = true`，然后调用 `CFRunLoopWakeUp`（通过 mach_msg 发空消息）。RunLoop 在下一轮循环的 `__CFRunLoopDoObservers` 中检查 `_stopped` 标志，若为 true → 跳出循环 → 触发 `kCFRunLoopExit` → 返回。

**注意**：`CFRunLoopStop` 必须在目标线程的 RunLoop 上调用（或通过 `performSelector:onThread:` 派发过去），否则有线程安全问题。

### Q11：CADisplayLink 和 NSTimer 底层区别？

| | NSTimer | CADisplayLink |
|--|---------|---------------|
| 底层 | CFRunLoopTimerRef，基于 **mach_absolute_time** | **CVDisplayLink**（CoreVideo），与 VSync 同步 |
| 触发时机 | 设定的时间点到达时 | 屏幕每次 VSync 信号时触发 |
| 精度 | 受 RunLoop 模式影响，不精确 | 与 VSync 对齐，适合动画 |
| 使用限制 | 滑动时 UITracking 下可能暂停 | 同受 RunLoop Mode 影响，需加 CommonModes |

### Q12：手写卡顿监控的核心代码（RunLoop 观察者方案）

```objc
// 注册 RunLoop Observer 监听 BeforeSources / AfterWaiting
CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(
    kCFAllocatorDefault,
    kCFRunLoopAllActivities,
    YES, 0,
    ^(CFRunLoopObserverRef obs, CFRunLoopActivity activity) {
        static int64_t lastTime = 0;
        if (activity == kCFRunLoopBeforeSources) {
            lastTime = CACurrentMediaTime() * 1000;
        } else if (activity == kCFRunLoopAfterWaiting) {
            int64_t now = CACurrentMediaTime() * 1000;
            if (lastTime > 0 && (now - lastTime) > 50) {
                // 超过 50ms → 卡顿，上报堆栈
                // [BSBacktraceLogger 或其他方式收集]
            }
        }
    });
CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
```

### Q13：RunLoop 的 `_commonModes` 和 `_commonModeItems` 是什么关系？

- `_commonModes`：`CFMutableSetRef`，存的是 Mode 名称（如 `NSDefaultRunLoopMode`、`UITrackingRunLoopMode`）
- `_commonModeItems`：关联到 CommonModes 的 Source/Timer/Observer 集合
- 当一个 Mode 被加入 `_commonModes`，RunLoop 会把 `_commonModeItems` 中所有 item **同步添加**到这个 Mode 中
- 所以 `[timer addToRunLoop:forMode:NSRunLoopCommonModes]` 之后，只要往 `_commonModes` 里加新 Mode，该 timer 自动出现在新 Mode 中

### Q14：RunLoop 循环中 BeforeWaiting 之前为什么要设置 `_sleepTime`？

源码中 `__CFRunLoopSetSleepTime` 记录休眠时刻。用途：
1. 在 `AfterWaiting` 中用当前时间 - `_sleepTime` 计算实际休眠时长
2. 用于卡顿监控判断线程是否被异常卡住（长时间没醒来）
3. 调试时定位 RunLoop 阻塞时间

### Q15：一次触摸事件在 RunLoop 层面的完整传递路径是怎样的？

```
① IOKit 驱动接收触摸 → 进程间通信
② SpringBoard 通过 mach port 转发到 App 进程
③ 主线程 RunLoop 的 Source1 收到 mach_msg → 唤醒
④ 回调 `__IOHIDEventSystemClientQueueCallback`
⑤ IOHIDEvent 被包装为 UIEvent → 入 Source0
⑥ 下一轮循环处理 Source0 → UIApplication sendEvent
⑦ hitTest → 触摸事件分发
```

### Q16：`CFRunLoopTimerRef` 的时间精度如何保证？为什么有时不准确？

CFRunLoopTimer 内部基于 `mach_absolute_time`（系统启动以来的 ticks），通过 `mach_timebase_info` 转换为纳秒。但实际触发时间受以下因素影响：

1. **Mode 隔离**：timer 注册的 Mode 非当前 Mode 时，即使时间到了也不触发
2. **当前事件处理阻塞**：如果 Source0 处理耗时超过 timer 间隔，timer 会被**延迟**到下一轮循环
3. **tolerance**：iOS 7+ 支持 `tolerance`（宽容度），系统可批量合并 timer 触发以省电

```c
// CFRunLoop.c 中 Timer 触发判断
if (timer->fireTime <= now) {
    // 触发，但若当前正在执行其他 Source，需等当前结束后再处理
}
```

---

## 7.10 关联参考

| 主题 | 参考 |
|------|------|
| 常驻线程 / 线程保活 | [第四章 §4.8](/posts/%E7%AC%AC%E5%9B%9B%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) |
| GCD 与 RunLoop 结合 | [第四章 §4.3](/posts/%E7%AC%AC%E5%9B%9B%E7%AB%A0%E5%A4%9A%E7%BA%BF%E7%A8%8B%E9%9D%A2%E8%AF%95%E5%85%AB%E8%82%A1.html) |
| 触摸事件链 | [Common/06](/posts/%E7%AC%AC%E5%85%AD%E7%AB%A0%E4%BA%8B%E4%BB%B6%E4%BC%A0%E9%80%92%E9%93%BEhit-testing.html) |
| 卡顿监控 | [Common/09 §9.1](/posts/%E7%AC%AC%E4%B9%9D%E7%AB%A0%E6%80%A7%E8%83%BD%E4%BC%98%E5%8C%96%E4%B8%8E-uikit%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) |
| GIF 滑动卡顿（RunLoop Mode） | [Common/09 §9.7](/posts/%E7%AC%AC%E4%B9%9D%E7%AB%A0%E6%80%A7%E8%83%BD%E4%BC%98%E5%8C%96%E4%B8%8E-uikit%E5%A4%A7%E5%8E%82%E9%AB%98%E9%A2%91-%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3.html) |
| 大厂考频统计 | [大厂面试题/06-高频考点TOP50](/posts/%E9%AB%98%E9%A2%91%E8%80%83%E7%82%B9-top-50%E8%B7%A8%E5%85%AC%E5%8F%B8%E7%BB%9F%E8%AE%A1.html) |
