+++
date = '2026-06-28T19:13:28+08:00'
draft = true
title = '第七章：事件响应链（Responder Chain）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# 第七章：事件响应链（Responder Chain）

> **学习位置**：紧接 [第六章 Hit-Testing](./06-事件传递链HitTesting.md)。  
> **语言无关**：UIKit 机制，OC 与 Swift **原理完全相同**。

**响应链解决的是：谁来处理这个事件？处理不了交给谁？**

## 方向：自下而上 ⬆️

```
hitTest 命中的 View（touch 首先发到这里）
    ↓ touchesBegan / Moved / Ended …
    ↓ touch 默认不自动向上；Motion / action 等可沿 nextResponder 向上
父 View → ViewController → Window → Application
    ↓
无人处理 → 丢弃
```

- **响应链 = 事件处理链**，从 **被 hitTest 选中的 View** 开始，沿 `nextResponder` **向上**传递
- 典型顺序：`子 View → 父 View → ViewController → Window → Application`
- 不要和 **传递链** 混：传递链是 hitTest **从上到下找** 谁接收；响应链是找到之后 **从下到上处理**
- **hitTest 返回 self 不代表一定有 UI 反馈**——默认 `UIView` 的 `touchesBegan` 为空（见第六章 §6.3）

---

## 7.1 响应者对象（UIResponder）

能处理事件的对象都继承 `UIResponder`：`UIView`、`UIViewController`、`UIWindow`、`UIApplication` 等。

每个对象有一个 **`nextResponder`** 属性（Swift 中为 `next`），表示 **响应链上的下一个对象**。

---

## 7.2 nextResponder 是什么？（高频）

### 一句话

> **`nextResponder` = 响应链上的「上一级负责人」**，只读属性，由系统按对象类型 **自动维护**（一般不要手动改）。

### 和 superview 的区别

| | `superview` | `nextResponder` |
|--|-------------|-----------------|
| 所属 | View **层级**关系 | **事件响应**关系 |
| 方向 | 父 View | 链上的下一个响应者 |
| 是否相同 | 多数子 View 中 **相同**（next = superview） | 根 View、VC、Window 等处 **不同** |

### 默认指向规则（背这条链）

```
被点击的子 View
    │  nextResponder
    ▼
父 View（superview）
    │  一路 superview 向上…
    ▼
控制器的 rootView（顶层 View）
    │  nextResponder（特殊：不是继续 superview）
    ▼
UIViewController
    │  nextResponder
    ▼
UIWindow
    │  nextResponder
    ▼
UIApplication
    │  nextResponder
    ▼
AppDelegate / nil
```

| 对象 | `nextResponder` 通常指向 |
|------|--------------------------|
| **普通 UIView** | `superview` |
| **VC 的根 View** | 所属的 **`UIViewController`**（特例） |
| **UIViewController** | `view.window` 或容器相关上级 |
| **UIWindow** | **`UIApplication`** |
| **UIApplication** | **AppDelegate**（或 nil） |

### 什么时候会用到 nextResponder？

| 场景 | 是否自动沿链向上 |
|------|------------------|
| **Touch 事件**（`touchesBegan` 等） | ⚠️ **默认不自动向上传**——只发给 hitTest 命中的 View |
| **`sendAction:to:from:` 且 target 为 nil** | ✅ 系统沿响应链 **查找** 能响应 selector 的对象 |
| **摇一摇等 Motion 事件** | ✅ 会沿响应链向上传递 |
| **键盘 / 输入**（First Responder） | ✅ 与 `becomeFirstResponder` / `resign` 相关 |
| **UIControl 事件** | 走 target-action / `UIAction`，不依赖你重写 touchesBegan |

**易错纠正**：

```
hitTest 返回 self
touchesBegan 无业务逻辑
    ↓
❌ 不会自动交给 nextResponder 处理 touch
    ↓
用户：点了没反应
```

### 语法对照：遍历响应链 / 手动转发

Objective-C

```objc
UIResponder *responder = self;
while (responder) {
    NSLog(@"%@", responder);
    responder = responder.nextResponder;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.nextResponder touchesBegan:touches withEvent:event];
}
```

Swift

```swift
var responder: UIResponder? = self
while let r = responder {
    print(r)
    responder = r.next
}

override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    next?.touchesBegan(touches, with: event)
}
```

---

## 7.3 触摸事件传递

```
hitTest 找到 first responder（通常是某个 UIView）
  ↓
touchesBegan/Moved/Ended/Cancelled 发给该 View
  ↓
默认：事件停在这个 View（touchesBegan 空实现 = 无业务 = 用户无感）
  ↓
可选：开发者手动转发给 nextResponder
  ↓
Motion / target=nil 的 action 等：系统沿链向上查找
  ↓
无人处理 → 丢弃
```

---

## 7.4 传递链 vs 响应链（对比表）

| | **传递链 Hit-Testing** | **响应链 Responder Chain** |
|--|------------------------|---------------------------|
| **方向** | 自上而下（Window → 子 View） | 自下而上（first responder → next） |
| **目的** | 找到**谁接收**触摸 | 找到**谁处理**触摸 |
| **核心方法** | `hitTest:` / `pointInside:` | `touchesBegan:` 等 + `nextResponder` |
| **时机** | 触摸开始瞬间 | 整个触摸生命周期 |

---

## 7.5 手势识别器（关联）

- `UIGestureRecognizer` 也是 `UIResponder` 子类
- 手势与 View 的 touch 存在 **延迟判定**（约 150ms，等双击等手势）
- `cancelsTouchesInView = YES`（默认）时，识别成功会 **cancel** View 的 touch 事件
- `delaysTouchesBegan` 影响 `touchesBegan` 触发时机

Swift 手势代理写法：

```swift
extension MyViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
```

---

## 7.6 语法对照：常见业务写法

### 点击空白收键盘

Objective-C

```objc
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
    [super touchesBegan:touches withEvent:event];
}
```

Swift

```swift
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    view.endEditing(true)
    super.touchesBegan(touches, with: event)
}
```

### UIButton / UIControl 事件

Objective-C

```objc
[button addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
```

Swift

```swift
button.addTarget(self, action: #selector(onTap), for: .touchUpInside)
// 或 iOS 14+
button.addAction(UIAction { _ in self.onTap() }, for: .touchUpInside)

@objc private func onTap() { }
```

Control 事件不经过 `touchesBegan`，是 Target-Action 机制，但 hitTest 仍决定按钮是否收到 touch。

### SwiftUI

SwiftUI View 是 struct，不直接参与响应链；底层 **Hosting UIView** 仍走 UIKit 响应链。用户交互通过 `Gesture`、`Button` action 等封装。

---

## 7.7 高频面试 Q&A

### Q1：点击按钮完整链路？

1. **Hit-Test**：Application → Window → … → UIButton
2. **Touch 阶段**：Button 内部 touch 处理 + 手势识别
3. **Action 阶段**：`sendAction:to:forEvent:` → selector / `UIAction`
4. 若 Button 不响应：事件 **不会自动** 沿链向上（touch 默认不冒泡）

### Q2：ViewController 为什么能收到事件？

VC 的根 View 的 `nextResponder` 指向 **ViewController** 本身（特例）。但 touch 默认只发给 hitTest 命中的 View，需手动转发才会到 VC。

### Q3：hitTest 返回 self 和响应链的关系？

传递链决定 **谁接**；响应链决定 **谁处理**。两者方向相反，别混。
