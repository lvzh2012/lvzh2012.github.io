+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = '第六章：事件传递链（Hit-Testing）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# 第六章：事件传递链（Hit-Testing）

> **学习位置**：OC 学完 [第五章 RunLoop](../OC/05-扩展八股.md) / Swift 学完 [第五章扩展](../Swift/05-扩展八股.md) 后阅读。  
> **语言无关**：UIKit 机制，OC 与 Swift **原理完全相同**，下文代码块并列给出两种语法。

**传递链解决的是：触摸点落在哪个 View 上？**

## 方向：自上而下 ⬇️

```
UIWindow（最上层）
    ↓ hitTest 递归
rootViewController.view
    ↓
子 View → 子 View → …（从前到后、从上层到下层）
    ↓
找到最终接收触摸的 View（first responder 候选）
```

- **传递链 = Hit-Testing**，从 **Window 往 View 树深处** 找，**从上到下**
- 子 View 遍历是 **逆序**（`subviews` 从后往前），因为后添加的 View 在 **视觉上层**，优先命中
- 不要和 **响应链** 混：响应链是 hitTest 完成之后，事件 **从命中 View 向上** 传递（见 [第七章](./07-事件响应链ResponderChain.md)）

## 6.1 流程

```
UIApplication
  └── UIWindow
        └── rootViewController.view
              └── 子 View 树（递归）
```

### 核心两个方法

**Objective-C**

```objc
// UIView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event;
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;
```

**Swift**

```swift
// UIView
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView?
override func point(inside point: CGPoint, with event: UIEvent?) -> Bool
```

### 先调用哪一个？（高频）

**系统先调 `hitTest:`，`hitTest:` 内部再调 `pointInside:`。**

```
UIKit 从 UIWindow 开始
    │
    ▼
hitTest:withEvent:          ← 入口，负责「找最终 View」
    │
    ├─ 1. 判断 hidden / alpha / userInteractionEnabled
    │
    ├─ 2. pointInside:withEvent:   ← 被 hitTest 调用，负责「点是否在范围内」
    │       └─ NO → hitTest 返回 nil
    │
    ├─ 3. 逆序遍历 subviews，对每个子 View 递归 hitTest:
    │
    └─ 4. 子 View 都没命中 → 返回 self
```

| 方法 | 职责 | 典型重写场景 |
|------|------|--------------|
| **`hitTest:`** | 决定 **返回哪个 View**（含子 View 递归） | 点击穿透、自定义事件分发 |
| **`pointInside:`** | 只判断 **点是否落在当前 View 内** | 扩大/缩小点击热区 |

**注意**：只重写 `pointInside:` 也会影响 `hitTest:` 结果，因为默认 `hitTest:` 依赖 `pointInside:` 的返回值；重写 `hitTest:` 时可以不调用 `pointInside:`（完全自定义逻辑）。

**默认 `hitTest:` 伪代码**：

Objective-C

```objc
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.userInteractionEnabled || self.hidden || self.alpha <= 0.01) {
        return nil;
    }
    if ([self pointInside:point withEvent:event]) {
        for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
            CGPoint p = [subview convertPoint:point fromView:self];
            UIView *hit = [subview hitTest:p withEvent:event];
            if (hit) return hit;
        }
        return self;
    }
    return nil;
}
```

Swift

```swift
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
    guard point(inside: point, with: event) else { return nil }
    for subview in subviews.reversed() {
        let converted = subview.convert(point, from: self)
        if let hit = subview.hitTest(converted, with: event) { return hit }
    }
    return self
}
```

---

## 6.2 hitTest 算法（背下来）

1. 当前 View **`hidden=YES` / `alpha≤0.01` / `userInteractionEnabled=NO`** → 返回 `nil`
2. 调用 `pointInside:withEvent:`，点不在 bounds 内 → `nil`
3. **逆序**遍历 `subviews`（后添加的在上面），对每个子 View 转换坐标后递归 `hitTest`
4. 子 View 有返回值 → 返回该子 View
5. 都没有 → 返回 **self**（自己吃事件）

---

## 6.3 hitTest 返回 self，用户仍可能「点了没反应」（易错 ⚠️）

**`hitTest` 返回 self ≠ 用户一定能看到交互效果。**

| 阶段 | 含义 |
|------|------|
| **hitTest 返回 self** | 传递链认定：**这个 View 接收触摸**（first responder 候选） |
| **用户感觉有响应** | 还要看响应链：有没有 `touchesBegan`、手势、target-action 等 **实际处理** |

### 为什么「吃了事件」却像没反应？

```
hitTest 返回 self
    ↓
系统把 touchesBegan 等发给这个 View
    ↓
┌─ UIView 默认 touchesBegan 是空实现 → 什么都不做
├─ 没加 UITapGestureRecognizer / 没 bind target-action
├─ 透明父 View 拦截：子 View 都 nil，父 View 返回 self，但父 View 无 UI 反馈
└─ 手势识别器 delaysTouchesBegan / cancelsTouchesInView → View 的 touch 被取消
    ↓
用户感受：点了，没反应 ❌
```

### 典型场景

| 场景 | 原因 |
|------|------|
| **空白 UIView 盖在按钮上** | 父 View `hitTest` 返回 self，没手势，挡下面按钮 |
| **子 View 都不可点，父 View 接住** | 算法第 5 步「都没有 → return self」，父 View 默认不处理 touch |
| **UIScrollView 空白区域** | ScrollView 自己接 touch，没点中子控件，可能只滚动或无反馈 |
| **只重写 hitTest 没处理 touch** | 命中逻辑改了，响应逻辑没跟上 |

### touchesBegan 没有业务逻辑 → 用户就是「无响应」

Objective-C

```objc
// UIView 默认实现 —— 空方法
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}

// 只有写了逻辑，用户才能「感觉到响应」
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self doSomething];
}
```

Swift

```swift
// UIView 默认实现 —— 空方法
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}

override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    doSomething()
}
```

**常见「有响应」的实现方式**（不一定重写 `touchesBegan`）：

| 方式 | 说明 |
|------|------|
| **重写 `touchesBegan` 等** | 直接写 touch 业务 |
| **`UITapGestureRecognizer`** | 手势回调里写业务 |
| **`UIControl` / `UIButton`** | 内部 touch 处理 + target-action / `UIAction` |
| **`UITableViewCell` 选中** | 系统控件封装了 touch → 回调 delegate |

**面试一句话**：

> **传递链**决定 **谁接** touch；**响应链**决定 **谁处理**。`hitTest` 返回 self 只是「接住了」，若没实现 touch 处理或手势，用户点击可以 **完全无响应**。

---

## 6.4 hitTest 返回 nil 会怎样？（易错 ⚠️）

**常见误解**：`hitTest` 返回 `nil` → 向上找能响应的 View。  
**正确理解**：传递链全程 **自上而下**；`nil` 表示 **当前 View 这棵子树不接收**，把决定权 **交回给调用它的父 View**，**不是**响应链里沿 `nextResponder` 向上。

### 父 View 收到 nil 后的逻辑（仍在 hitTest 阶段）

```
父 View 的 hitTest:
    │
    ├─ 子 View A（最上层）hitTest → nil
    ├─ 子 View B hitTest → nil
    ├─ 子 View C hitTest → 返回 C ✅     ← 试 **下面的兄弟 View**
    │
    └─ 若所有子 View 都 nil → 返回 **self**（父 View 自己接收）
```

### 和响应链的区别（必背）

```
┌─────────────────────────────────────────────────────────┐
│  阶段 1：Hit-Testing（传递链）  方向 ⬇️ 自上而下          │
│  Window → … → 子 View                                     │
│  hitTest 返回 nil → 父 View 换兄弟 / 返回 self / 最终 nil │
└─────────────────────────────────────────────────────────┘
                          ↓ 命中某个 View 后
┌─────────────────────────────────────────────────────────┐
│  阶段 2：Responder Chain（响应链）  方向 ⬆️ 自下而上      │
│  命中 View → touchesBegan → nextResponder → … → App      │
└─────────────────────────────────────────────────────────┘
```

**面试一句话**：

> `hitTest` 返回 nil = 「我不接」；父 View 在同一层 **继续问别的 subview 或自己接**。**向上传递是 hitTest 完成之后响应链的事**。

### 传递链截断（前置检查 fail → 子 View 不会被问）

| 说法 | 对不对 |
|------|--------|
| 传递链从上到下 | ✅ |
| UIWindow 无法通过 hitTest 前置条件 → 子 View 收不到 | ✅ |
| 任意 View 返回 nil → 一定向上找响应者 | ❌ 那是响应链 |
| 子 View 返回 nil → 父 View 还可能问兄弟或自己接 | ✅ |

---

## 6.5 常见考点

| 场景 | 原理 |
|------|------|
| **点了没反应** | `hitTest` 返回 self 只表示 **接收** touch；无 `touchesBegan`/手势/target → 用户仍无感 |
| **扩大按钮点击区域** | 重写 `pointInside:withEvent:` 扩大 bounds |
| **穿透点击** | 上层 View 的 `hitTest` 返回 `nil`，父 View 继续尝试其他 subview |
| **ScrollView 与 Button 冲突** | 触摸阶段 hitTest 已定目标；滚动靠 `touchesMoved` 判断 |
| **UITableViewCell 子 View 不响应** | Cell 的 `contentView` 默认 `userInteractionEnabled=NO`（iOS 14+ 有变化） |
| **事件坐标转换** | `convertPoint:fromView:` / `convert(_:from:)` |

### 语法对照：扩大点击区域

Objective-C

```objc
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect larger = UIEdgeInsetsInsetRect(self.bounds, UIEdgeInsetsMake(-10, -10, -10, -10));
    return CGRectContainsPoint(larger, point);
}
```

Swift

```swift
override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.inset(by: UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)).contains(point)
}
```

### 语法对照：穿透透明区域

Objective-C

```objc
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
```

Swift

```swift
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    return hit === self ? nil : hit
}
```

### SwiftUI 补充（语法层差异）

SwiftUI 不直接重写 `hitTest`，用修饰符控制命中：

- `.contentShape(Rectangle())` — 扩大点击区域
- `.allowsHitTesting(false)` — 禁用命中（类似 hitTest 返回 nil）

底层仍走 UIKit Hosting View 的 Hit-Testing。

---

## 6.6 高频面试 Q&A

### Q1：两个 View 重叠，谁接收触摸？

`hitTest` 从 **后添加的 subview（上层）** 开始逆序查找，先命中者优先。

### Q2：superview 比 subview 大，点在 subview 外但在 superview 内？

subview 的 `hitTest` 返回 nil，事件由 superview 接收（算法第 5 步 return self）。

### Q3：UITableViewCell 上的 Button 点不到？

Cell 或 contentView 的 `hitTest` 被重写、手势冲突、或按钮 `isUserInteractionEnabled = false`。用 Debug View Hierarchy 排查。
