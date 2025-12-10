+++
date = '2025-12-10T11:45:39+08:00'
draft = false
title = 'Swift Codable Macro'
+++

# CodableMacro

`CodableMacro` 是一个轻量级的 Swift Macro 库，旨在简化 Swift 中 `Codable` 协议的实现。通过使用宏，你可以极大地减少处理 JSON 解析时的样板代码，轻松处理自定义键名映射和默认值。

## ✨ 特性 (Features)

- **自动实现 Codable**: 使用 `@CodableModel` 宏自动生成 `init(from: Decoder)`、`encode(to: Encoder)` 和 `CodingKeys`。
- **自定义键名**: 使用 `@CKey("json_key")` 宏轻松映射 JSON 中的字段名。
- **默认值支持**: 使用 `@Default(value)` 宏为属性指定默认值，当 JSON 中缺少字段或解析失败时自动使用默认值。
- **便捷解码**: 提供 `.rk` 命名空间扩展，支持直接从 `Data` 或 JSON `String` 解码。

## 📦 安装 (Installation)

### Swift Package Manager

在你的 `Package.swift` 文件中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/lvzh2012/CodableMacro.git", from: "0.1.0")
]
```

然后将 `CodableMacro` 添加到你的 target 依赖中：

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CodableMacro"]
    )
]
```

## 📖 使用指南 (Usage)

### 1. 基础用法

只需在你的 `struct` 或 `class` 上添加 `@CodableModel` 宏，即可自动获得 Codable 能力。

```swift
import CodableMacro

@CodableModel
struct User: Codable {
    let name: String
    let age: Int
}
```

### 2. 自定义键名映射 (@CKey)

如果后端返回的 JSON 字段名与你的属性名不一致，可以使用 `@CKey` 指定 JSON 中的键名。

```swift
@CodableModel
struct User: Codable {
    // 将 JSON 中的 "user_name" 映射到 name 属性
    @CKey("user_name") 
    let name: String
    
    let age: Int
}
```

### 3. 设置默认值 (@Default)

当 JSON 数据中可能缺少某个字段，或者你想为失败的解析提供一个兜底值时，使用 `@Default`。

```swift
@CodableModel
struct Product: Codable {
    let title: String
    
    // 如果 JSON 中缺少 "count" 或解析失败，默认为 0
    @Default(0)
    let count: Int
    
    // 支持可选类型，默认值可以是 nil 或具体值
    @Default(true)
    let isAvailable: Bool?
}
```

### 4. 便捷解码

`CodableMacro` 提供了一个 `rk` 命名空间扩展，使得解码过程更加流畅。

```swift
let jsonString = """
{
    "user_name": "ZhangSan",
    "age": 25
}
"""

do {
    // 直接从 String 解码
    let user = try User.rk.decode(from: jsonString)
    print(user.name)
} catch {
    print("Decode error: \(error)")
}
```

## 完整示例

```swift
import CodableMacro
import Foundation

@CodableModel
struct User: Codable {
    // 自定义键名映射
    @CKey("server_id")
    let id: Int
    
    let name: String
    
    // 设置默认值
    @Default(18)
    let age: Int
    
    @Default(false)
    let isAdmin: Bool
}

// 使用示例
let json = """
{
    "server_id": 1001,
    "name": "Alice"
}
"""

if let user = try? User.rk.decode(from: json) {
    print("ID: \(user.id)")       // 1001
    print("Name: \(user.name)")   // Alice
    print("Age: \(user.age)")     // 18 (Default)
    print("Admin: \(user.isAdmin)") // false (Default)
}
```

## ⚠️ 注意事项

- `@CodableModel` 宏会自动生成 `CodingKeys` 枚举，请勿手动声明，否则可能会产生冲突。
- 确保你的属性类型本身是遵循 `Codable` 协议的。

## License

MIT License

