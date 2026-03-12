+++
date = '2026-03-12T11:19:27+08:00'
draft = false
title = 'Swift Package 源码与二进制分发指南'
tags = ["iOS"]
categories = ["Swift Package"]
cover = "https://d-image.i4.cn/i4web/image//upload/20190227/1551233745646040866.jpg"

+++

# Swift Package 源码与二进制分发指南

一个同时支持**源码引用**和**二进制（XCFramework）分发**的 Swift Package 工程模板。

## Package.swift 核心概念

`Package.swift` 由三个核心部分组成：`products`、`dependencies`、`targets`。理解它们之间的关系是正确编写清单文件的关键。

### 整体结构

```swift
let package = Package(
    name: "MyPackage",
    platforms: [.iOS(.v15)],
    products: [       // 对外暴露什么
        .library(name: "MyLibrary", targets: ["MyTarget"]),
    ],
    dependencies: [   // 需要哪些外部包
        .package(url: "https://github.com/xxx/Foo.git", from: "1.0.0"),
    ],
    targets: [        // 如何组织代码
        .target(name: "MyTarget", dependencies: ["Foo"]),
    ]
)
```

### products — 对外暴露的产品

`products` 定义了这个包**对外提供什么**，是消费方通过 `.product(name:package:)` 引用的入口。

```swift
products: [
    // name: 消费方引用时使用的名称
    // targets: 该产品包含哪些 targets
    .library(name: "MyLibrary", targets: ["MyTarget"]),
]
```

**注意事项：**

- `name` 是消费方 `.product(name: "MyLibrary", package: "...")` 中使用的名称
- `targets` 数组中的 target 必须在下方 `targets` 中定义
- 一个 product 可以包含多个 targets
- 未列入任何 product 的 target 是内部的，消费方无法使用

### dependencies — 外部包依赖

`dependencies` 声明这个包**依赖了哪些外部包**，是 package 级别的声明。

```swift
dependencies: [
    // 远程依赖
    .package(url: "https://github.com/xxx/Foo.git", from: "1.0.0"),
    // 本地路径依赖
    .package(path: "../AnotherPackage"),
]
```

**注意事项：**

- 仅声明依赖不够，还必须在 target 的 `dependencies` 中引用，否则 SwiftPM 会报 **"dependency is not used by any target"** 错误
- 本地路径依赖的**包标识符是目录名**（路径最后一段），不是 Package.swift 中的 `name`。例如 `.package(path: "../Foo/Binary")` 的标识符是 `"Binary"`
- 远程依赖的包标识符是仓库名（URL 最后一段去掉 `.git`）

### targets — 代码组织单元

`targets` 定义了包内的**模块**，每个 target 编译为一个 Swift module。

```swift
targets: [
    // 普通源码 target
    .target(
        name: "MyTarget",
        dependencies: [
            "InternalTarget",                                    // 同包内的 target
            .product(name: "Foo", package: "Foo"),               // 外部包的 product
        ]
    ),
    // 二进制 target（不支持 dependencies）
    .binaryTarget(
        name: "MyBinary",
        path: "MyModule.xcframework"
    ),
    // 测试 target
    .testTarget(
        name: "MyTests",
        dependencies: ["MyTarget"]
    ),
]
```

**注意事项：**

- `name` 同时决定了 **module 名**（即 `import MyTarget` 中的名称）和默认的源码目录（`Sources/MyTarget/`）
- target 的 `dependencies` 分两种写法：
  - 字符串 `"Foo"` — 引用**同包内的 target**
  - `.product(name:package:)` — 引用**外部包的 product**
- `.binaryTarget` **不支持 `dependencies` 参数**，这是需要 wrapper target 的根本原因
- 可通过 `path` 参数自定义源码路径，不受 `name` 约束

### 三者的关系

```
消费方 ──.product(name:package:)──▶ products
                                      │
                                      │ targets: [...]
                                      ▼
                                   targets
                                      │
                                      │ dependencies: [...]
                                      ▼
                               dependencies (外部包)
                              或同包内其他 targets
```

关键链路：**消费方只能引用 products → products 指向 targets → targets 声明自己依赖什么**。三层缺一不可。

## 目录结构

```
YourPackage/
├── Package.swift                       # 源码包清单
├── Sources/YourModule/                 # 源码
├── Binary/                             # 二进制分发包
│   ├── Package.swift                   # 二进制包清单
│   ├── Sources/YourModuleWrapper/      # Wrapper target（有第三方依赖时需要）
│   │   └── Exports.swift
│   └── YourModule.xcframework/         # 预编译的 XCFramework
├── Example/                            # 示例/宿主工程（用于构建 XCFramework）
├── Makefile
├── build-xcframework.sh
└── create-example.sh
```

## 源码引用

消费方直接依赖根目录的 `Package.swift`：

```swift
dependencies: [
    .package(path: "../YourPackage"),
    // 或远程仓库
    // .package(url: "https://github.com/xxx/YourPackage.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "YourModule", package: "YourPackage"),
        ]
    ),
]
```

## 二进制引用

消费方依赖 `Binary/` 目录的 `Package.swift`：

```swift
dependencies: [
    .package(path: "../YourPackage/Binary"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            // 注意：本地路径依赖时，package 参数使用目录名，而非 Package.swift 中的 name
            .product(name: "YourModule", package: "Binary"),
        ]
    ),
]
```

## 二进制包的 Package.swift 写法

### 情况一：XCFramework 无第三方依赖

如果 XCFramework 的 `.swiftinterface` 中只有系统框架的 import（如 Foundation、UIKit 等），直接暴露 `.binaryTarget` 即可：

```swift
// Binary/Package.swift
let package = Package(
    name: "YourModule",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "YourModule", targets: ["YourModule"]),
    ],
    targets: [
        .binaryTarget(
            name: "YourModule",
            path: "YourModule.xcframework"
        ),
    ]
)
```

### 情况二：XCFramework 有第三方依赖（Wrapper Target 模式）

SwiftPM 的 `.binaryTarget` 不支持 `dependencies` 参数。当 XCFramework 的 `.swiftinterface` 中存在第三方 import 时，编译器加载模块需要解析这些 import，因此必须通过 wrapper target 传递依赖：

```swift
// Binary/Package.swift
let package = Package(
    name: "YourModule",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "YourModule", targets: ["YourModuleWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/xxx/SomeDependency.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "YourModuleWrapper",
            dependencies: [
                "YourModuleBinary",
                .product(name: "SomeDependency", package: "SomeDependency"),
            ],
            path: "Sources/YourModuleWrapper"
        ),
        .binaryTarget(
            name: "YourModuleBinary",
            path: "YourModule.xcframework"
        ),
    ]
)
```

同时需要创建 wrapper target 的源文件，通过 `@_exported import` 重新导出模块：

```swift
// Binary/Sources/YourModuleWrapper/Exports.swift
@_exported import YourModule
```

消费方仍然使用 `import YourModule`，无需感知 wrapper 的存在。

### 为什么 .swiftinterface 会包含第三方 import

Swift 编译器在 `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` 模式下生成 `.swiftinterface` 时，会保留源文件中**所有顶层 import**，即使公开 API 没有暴露任何第三方类型。这是编译器行为，与代码写法无关。

可通过以下命令检查 `.swiftinterface` 的 import 列表，判断是否需要 wrapper：

```bash
head -20 YourModule.xcframework/ios-arm64/YourModule.framework/Modules/YourModule.swiftmodule/*.swiftinterface
```

## 构建 XCFramework

### 前置条件

- Xcode 15+
- [Tuist](https://tuist.io)（用于生成 Example 宿主工程）

### 构建步骤

```bash
cd YourPackage

# 1. 生成 Example 工程（首次需要）
make example

# 2. 构建 XCFramework
make xcframework

# 3. 复制到 Binary 目录
cp -R YourModule.xcframework Binary/
```

### 构建原理

1. 通过 Tuist 生成包含 framework target 的 Example 工程
2. `build-xcframework.sh` 使用 `xcodebuild build` 分别编译：
   - iOS Device（arm64）
   - iOS Simulator（arm64 + x86_64）
3. 通过 `xcodebuild -create-xcframework` 合并为 XCFramework

构建时启用 `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`，生成 `.swiftinterface` 保证跨 Swift 版本兼容。

## 验证 XCFramework

```bash
# 查看支持的架构
lipo -info YourModule.xcframework/ios-arm64/YourModule.framework/YourModule

# 查看是否为动态/静态库
file YourModule.xcframework/ios-arm64/YourModule.framework/YourModule

# 查看模块接口
cat YourModule.xcframework/ios-arm64/YourModule.framework/Modules/module.modulemap

# 检查第三方符号是否已链入（判断是否需要 wrapper）
nm YourModule.xcframework/ios-arm64/YourModule.framework/YourModule | grep -i "SomeDependency"
```

## 常见问题

### 1. 二进制引用时报 `unknown package` 错误

SwiftPM 对本地路径依赖使用**目录名**作为包标识符。依赖路径为 `../YourPackage/Binary` 时，`package` 参数应填 `"Binary"` 而非 Package.swift 中的 `name` 值。

### 2. 二进制引用时报模块找不到

检查 `.swiftinterface` 是否包含第三方 import。如果有，需要使用 wrapper target 模式，确保第三方依赖传递给消费方。

### 3. 编译器参数不兼容

`-file-prefix-map` 在某些 Xcode 版本下可能不兼容，可替换为 `-debug-prefix-map`：

```bash
# 兼容写法
OTHER_SWIFT_FLAGS="-debug-prefix-map ${SRC}=${DST}"
```

### 4. 架构缺失

确保同时构建 device 和 simulator 版本：

```bash
VALID_ARCHS="arm64"           # iOS Device
VALID_ARCHS="arm64 x86_64"    # iOS Simulator
```

## Makefile 命令

```bash
make example        # 生成 / 打开 Example 工程
make example-clean  # 清理 Example 工程
make xcframework    # 构建 XCFramework
make clean          # 清理构建产物
```
