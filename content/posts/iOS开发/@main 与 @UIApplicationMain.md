+++
date = '2025-12-11T11:18:11+08:00'
draft = false
title = '@main与@UIApplicationMain'

tags = ['Swift', '应用入口']

categories = ['iOS 开发']

cover = "https://plus.unsplash.com/premium_photo-1673292293042-cafd9c8a3ab3?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

+++

# @main 与 @UIApplicationMain 的区别

> **文档说明**：本文档详细对比 iOS 开发中两种应用程序入口点标记方式的区别，并深入讲解如何自定义应用入口（UIKit 与 SwiftUI 两套玩法），帮助开发者理解并正确使用。

---

## 🎯 快速对比

|         特性         |    @UIApplicationMain    |     @main      |
| :------------------: | :----------------------: | :------------: |
|     **引入版本**     |      Swift 早期版本      |   Swift 5.3+   |
|     **适用范围**     | 仅 UIKit/AppKit 应用程序 | 所有类型的程序 |
|      **灵活性**      |    较低，仅限应用程序    | 高，通用入口点 |
|   **SwiftUI 支持**   |         ❌ 不支持         |   ✅ 完全支持   |
| **自定义 main 函数** |         ❌ 不支持         |     ✅ 支持     |
|     **推荐使用**     |   ⚠️ 已弃用（推荐迁移）   |   ✅ **推荐**   |

**核心区别**：`@UIApplicationMain` 是专门为 UIKit 应用程序设计的旧方式，而 `@main` 是 Swift 5.3+ 引入的通用入口点标记，功能更强大、适用范围更广。

---

## 📖 @UIApplicationMain 详解

### 定义与背景

`@UIApplicationMain` 是 Swift 中专门为 iOS/macOS UIKit/AppKit 应用程序设计的属性，用于标记应用程序的主入口点。它是 Swift 早期版本中引入的特性。

### 核心特点

- **专用性**：专门为 UIKit/AppKit 应用程序设计，不能用于其他类型的程序
- **自动合成入口**：编译器自动合成入口代码，内部调用 `UIApplicationMain` 函数
- **限制性**：只能用于应用程序入口，无法自定义启动流程（主类固定为 nil）

### 工作原理

当使用 `@UIApplicationMain` 时，Swift 编译器会执行以下步骤：

1. 合成一个入口（相当于虚拟的 `main`）
2. 调用 `UIApplicationMain(_:_:_:_:)` 函数
3. 以 `nil` 作为主类（`UIApplication` 或其子类），以被标记的类作为应用代理（AppDelegate）
4. 创建 `UIApplication` 实例并启动事件循环

### 使用示例

```swift
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 应用程序启动代码
        return true
    }
}
```

---

## 🚀 @main 详解

### 定义与背景

`@main` 是 Swift 5.3+ 引入的通用属性，用于标记程序的入口点。它不仅适用于应用程序，还可以用于命令行工具、测试等多种类型的程序。这是 Swift 推荐的现代化方式。

### 核心特点

- **通用性**：可用于各种类型的程序入口点（应用程序、命令行工具、测试等）
- **灵活性**：可以标记任何符合特定协议的类型，支持自定义启动逻辑
- **现代化**：Swift 官方推荐的现代方式
- **向后兼容**：可以替代 `@UIApplicationMain`、`@NSApplicationMain` 等旧属性

### 工作原理

`@main` 属性要求被标记的类型满足以下条件之一：

- 必须有一个静态的 `main()` 方法，或者
- 符合 `@main` 协议（如 SwiftUI 的 `App` 协议）

编译器会调用这个 `main()` 方法作为程序入口。

### 使用示例

#### 示例 1：iOS UIKit 应用程序

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 应用程序启动代码
        return true
    }
}
```

#### 示例 2：SwiftUI 应用程序

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 示例 3：命令行工具

```swift
@main
struct MyTool {
    static func main() {
        print("Hello, World!")
    }
}
```

---

## ⚖️ 详细对比

### 功能对比

|       对比维度       |    @UIApplicationMain    |     @main      |
| :------------------: | :----------------------: | :------------: |
|     **引入版本**     |      Swift 早期版本      |   Swift 5.3+   |
|     **适用范围**     | 仅 UIKit/AppKit 应用程序 | 所有类型的程序 |
|      **灵活性**      |    较低，仅限应用程序    | 高，通用入口点 |
|   **SwiftUI 支持**   |         ❌ 不支持         |   ✅ 完全支持   |
| **自定义 main 函数** |         ❌ 不支持         |     ✅ 支持     |
|  **命令行工具支持**  |         ❌ 不支持         |     ✅ 支持     |
|     **测试支持**     |         ❌ 不支持         |     ✅ 支持     |
|     **推荐使用**     |   ⚠️ 已弃用（推荐迁移）   |   ✅ **推荐**   |

### 使用场景对比

|       场景       | @UIApplicationMain |     @main      |
| :--------------: | :----------------: | :------------: |
|  UIKit 应用程序  |       ✅ 可用       |   ✅ **推荐**   |
| SwiftUI 应用程序 |      ❌ 不可用      | ✅ **必须使用** |
|    命令行工具    |      ❌ 不可用      |   ✅ **支持**   |
|  自定义启动逻辑  |      ❌ 不支持      |   ✅ **支持**   |

---

## 🎯 为什么 `UIApplicationMain` 函数没有被废弃？

废弃的是 `@UIApplicationMain` **属性**，而 `UIApplicationMain` 这个 C **函数**至今依然可用、未标记 deprecated。原因如下：

1. **它仍是 UIKit 应用的"真实入口"**：`@main`/`@UIApplicationMain` 只是编译器的糖衣，`@main` 合成的代码底层照样调用 `UIApplicationMain`。一个仍在幕后工作的函数不会被废弃，否则就自相矛盾了。

2. **废弃的是"属性"，不是"函数"**：`@UIApplicationMain` 属性在 iOS 14 被标记废弃，目的是统一入口写法（和 SwiftUI 的 `@main` 对齐）；函数本身没有替代物。

3. **兼容性包袱**：大量存量代码直接调用它（`main.swift`、`main.m`、游戏/工具类工程），废弃它会让老工程灌满警告，收益为零。

4. **它提供不可替代的能力**：默认入口无法指定自定义 `UIApplication` 主类（`@main` 合成代码传 nil），想定制就必须直接调这个函数。一个"无法被替代"的 API 没有废弃的动机。

5. **苹果的废弃惯例**：只有存在更优替代方案时才标记废弃。Swift 里很多底层 C API（如 `dispatch_main`、`CFRunLoopRun`）同理——语言层糖化了，但底层函数永存。

> 签名 `UIApplicationMain(Int32, UnsafeMutablePointer<UnsafeMutablePointer<Int8>>!, String?, String?)` 中两个 `String?` 可空参数（主类/代理类），正是为"自定义"保留的缺口。

---

## 🔄 迁移指南

### 为什么需要迁移？

- `@main` 是 Swift 官方推荐的现代化方式
- `@main` 功能更强大，适用范围更广
- `@main` 支持 SwiftUI 和未来新特性
- `@UIApplicationMain` 已被标记为弃用

### 迁移步骤

迁移非常简单，只需将 `@UIApplicationMain` 替换为 `@main`：

#### 迁移前

```swift
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    // ...
}
```

#### 迁移后

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // ...
}
```

**就这么简单！** 只需替换一个属性名称，无需修改其他任何代码。

### 迁移注意事项

1. **版本要求**
   - Swift 5.3 或更高版本
   - Xcode 12.0 或更高版本

2. **功能等价性**
   - 迁移后功能完全相同
   - 无需修改其他代码
   - 应用程序行为保持一致

3. **兼容性**
   - 完全向后兼容
   - 可以逐步迁移
   - 不影响现有功能

---

## 💡 UIKit 入口自定义（实战）

`@main` 的原理：编译器生成代码调用该类型上的 `static func main()`。`UIApplicationDelegate` 的协议扩展提供了默认实现——等价于 `UIApplicationMain(argc, argv, nil, NSStringFromClass(self))`，**第三个参数（自定义 Application 类）写死 nil**。想自定义，只需自己接管 `main()`。

### 方案 A：main.swift（最接近原始 UIApplicationMain 的玩法）

新建 `main.swift`，删掉 AppDelegate 上的 `@UIApplicationMain`/`@main`（main.swift 有顶层代码就是入口，`@main` 与它不能共存）：

```swift
// main.swift
import UIKit

// 自定义 Application：可重写 sendEvent 做全局触摸统计/超时监控等
final class MyApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        // 例如：记录最后触摸时间、防崩溃过滤非法事件
        super.sendEvent(event)
    }
}

UIApplicationMain(
    CommandLine.argc,                     // 参数
    CommandLine.unsafeArgv,
    NSStringFromClass(MyApplication.self), // 主类：nil 或自定义
    NSStringFromClass(AppDelegate.self)    // 代理类
)
```

### 方案 B：保留 @main，自己写 static func main()

```swift
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    // 编译器优先用类型内自己的声明，覆盖掉协议扩展的默认实现
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            NSStringFromClass(MyApplication.self),
            NSStringFromClass(AppDelegate.self)
        )
    }
}
```

比方案 A 少一个文件，但语义略隐晦，实际工程里两种都常见。

### 方案 B 抽取到单独文件

想把入口逻辑挪出 AppDelegate，但**不能叫 `main.swift`**（顶层代码与 `@main` 互斥），用 extension 即可：

```swift
// AppDelegate.swift —— 保持 @main
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    // ... 只保留业务代理逻辑
}
```

```swift
// AppEntry.swift —— 任意文件名，唯独不能叫 main.swift
import UIKit

extension AppDelegate {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            NSStringFromClass(MyApplication.self),
            NSStringFromClass(AppDelegate.self)
        )
    }
}
```

原理：`@main` 要求该类型有一个 `static func main()`，**类型自身的声明（含 extension）优先于协议扩展的默认实现**，入口逻辑被完整挪到独立文件，AppDelegate 保持干净。

### 两条路对比

| 方案 | 入口文件 | @main | 效果 |
| :--: | :------: | :---: | :--: |
|  A   | `main.swift`（顶层代码） | 不能用 | 最接近原 UIApplicationMain |
|  B   | 任意文件 + `extension AppDelegate` | 保留 | 单文件逻辑迁移、改动最小 |

---

## 💡 SwiftUI 的 @main 入口重写

SwiftUI 的 `@main` 机制与 UIKit 版同源：`App` 协议扩展里提供了一个 `static func main()`（内部走 UIKit 生命周期 + SwiftUI 场景托管）。按定制深度分三层：

### 层次 1：最常用——不改 main，注入 UIKit 生命周期钩子

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

`AppDelegate` 里照常写 `didFinishLaunching` 等 UIKit 回调，这是 SwiftUI 官方支持的"接 UIKit"姿势。

### 层次 2：自定义 UIApplication 子类——靠 Info.plist，不碰 main

SwiftUI 入口里没有传主类的参数，但 `UIApplicationMain` 会读 plist 里的 `NSPrincipalClass`：

```xml
<key>NSPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).MyApplication</string>
```

```swift
final class MyApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)  // 全局触摸统计、超时监控等
    }
}
```

SwiftUI 的隐藏启动代码照常跑，只换掉了 Application 类。

### 层次 3：真·重写 main()——前置初始化后仍走默认启动

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// 单独文件（别叫 main.swift）
extension MyApp {
    static func main() {
        // 启动前的自定义逻辑：日志系统、启动参数解析、环境探测……
        Bootstrap.initialize()

        // 关键：调协议扩展的默认实现，而不是递归调自己
        (Self.self as any App).main()
    }
}
```

`(Self.self as any App).main()` 是"类型自己的 main 覆盖协议扩展默认实现"后的逃生通道——通过 `any App` 存在类型调用，精确命中协议扩展的实现，不会递归。

### SwiftUI 的两个坑

- **别用 main.swift 顶层代码全接管**：SwiftUI 的场景托管、`WindowGroup` 的 lifecycle 都在它隐藏的 AppDelegate 里，自己跑 `UIApplicationMain` 会丢失这些行为
- `@main` 与 `main.swift` 互斥，SwiftUI 项目一律用 `@main` + 上面三层的某一种组合

---

## 📝 总结与建议

### 核心要点

- **@UIApplicationMain**：旧的方式，专门用于 UIKit 应用程序，功能有限，属性已弃用（但底层 `UIApplicationMain` 函数永存，是唯一能自定义主类的通道）
- **@main**：现代方式，通用入口点标记，支持所有类型的程序，**推荐使用**
- **自定义入口三条路**：`main.swift` 顶层代码（全接管）、类型内自定义 `static func main()`（半接管）、`extension` 单独文件（逻辑分离 + 保持 @main）

### 推荐做法

|     项目类型     | 推荐做法                                  |
| :--------------: | :---------------------------------------- |
|    **新项目**    | ✅ 直接使用 `@main`                        |
|   **现有项目**   | ✅ 逐步迁移到 `@main`                      |
| **SwiftUI 项目** | ✅ **必须**使用 `@main`                    |
|  **旧项目维护**  | ⚠️ `@UIApplicationMain` 仍可用，但建议迁移 |

### 最佳实践

1. ✅ **统一使用 `@main`**：在新项目和现有项目中统一使用 `@main`
2. ✅ **保持代码现代化**：利用 `@main` 的灵活性实现更好的代码结构
3. ✅ **利用自定义能力**：自定义 `UIApplication` 时优先用方案 B 的 extension 写法
4. ✅ **及时迁移**：将现有项目从 `@UIApplicationMain` 迁移到 `@main`
5. ⚠️ **SwiftUI 别碰 main.swift**：需要自定义入口用 `@UIApplicationDelegateAdaptor` / `NSPrincipalClass` / 自定义 `static func main()` 三层方案

---

## 📚 参考资源

- [Swift Evolution: SE-0281](https://github.com/apple/swift-evolution/blob/main/proposals/0281-main-attribute.md) - `@main` 属性的官方提案
- [Apple Developer Documentation](https://developer.apple.com/documentation/swift/main) - Swift `@main` 属性官方文档

---
