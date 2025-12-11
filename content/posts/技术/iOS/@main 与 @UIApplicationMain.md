+++
date = '2025-12-11T11:18:11+08:00'
draft = false
title = '@main与@UIApplicationMain'

tags = ['iOS']

categories = ['iOS']

cover = "https://plus.unsplash.com/premium_photo-1673292293042-cafd9c8a3ab3?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

+++

# @main 与 @UIApplicationMain 的区别

> **文档说明**：本文档详细对比 iOS 开发中两种应用程序入口点标记方式的区别，帮助开发者理解并正确选择使用。

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
- **自动生成代码**：编译器会自动生成 `main.swift` 文件（虚拟的），包含 `UIApplicationMain` 函数调用
- **限制性**：只能用于应用程序入口，无法自定义启动流程

### 工作原理

当使用 `@UIApplicationMain` 时，Swift 编译器会执行以下步骤：

1. 自动生成一个虚拟的 `main.swift` 文件
2. 在该文件中调用 `UIApplicationMain(_:_:_:_:)` 函数
3. 创建 `UIApplication` 实例
4. 将标记的类设置为应用程序代理（AppDelegate）

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

## 💡 实际应用场景

### 场景 1：传统 UIKit 应用程序

在传统的 UIKit 应用程序中，使用 `@main` 标记 `AppDelegate`：

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 创建窗口
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // 设置根视图控制器
        window?.rootViewController = ViewController()
        
        // 显示窗口
        window?.makeKeyAndVisible()
        
        return true
    }
}
```

### 场景 2：SwiftUI 应用程序

在 SwiftUI 应用程序中，**必须**使用 `@main` 标记符合 `App` 协议的结构体：

```swift
import SwiftUI

@main
struct MyApp: App {
    @StateObject private var dataModel = DataModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataModel)
        }
    }
}
```

### 场景 3：自定义启动逻辑

`@main` 支持自定义启动逻辑，这是 `@UIApplicationMain` 无法实现的：

```swift
import UIKit

@main
enum AppLauncher {
    static func main() {
        // 自定义启动逻辑
        let app = UIApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // 执行自定义初始化
        delegate.customSetup()
        
        // 启动应用程序
        _ = UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(AppDelegate.self)
        )
    }
}
```

---

## 📝 总结与建议

### 核心要点

- **@UIApplicationMain**：旧的方式，专门用于 UIKit 应用程序，功能有限，已弃用
- **@main**：现代方式，通用入口点标记，支持所有类型的程序，**推荐使用**

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
3. ✅ **利用自定义能力**：在需要时使用 `@main` 的自定义启动逻辑功能
4. ✅ **及时迁移**：将现有项目从 `@UIApplicationMain` 迁移到 `@main`

---

## 📚 参考资源

- [Swift Evolution: SE-0281](https://github.com/apple/swift-evolution/blob/main/proposals/0281-main-attribute.md) - `@main` 属性的官方提案
- [Apple Developer Documentation](https://developer.apple.com/documentation/swift/main) - Swift `@main` 属性官方文档

---

