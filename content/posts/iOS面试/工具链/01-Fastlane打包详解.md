+++
date = '2026-07-15T20:41:50+08:00'
draft = true
title = '第一章：Fastlane 打包详解（本地打包 · 从零到上架）'
tags = ["Fastlane", "CI/CD", "工具"]
categories = ['iOS 面试']
+++

# 第一章：Fastlane 打包详解（本地打包 · 从零到上架）

> Fastlane 是 iOS/Android 自动化的行业标准工具，覆盖 **打包、签名、上传、自动化** 全流程。  
> 本文专注 **本地打包场景**，不依赖 CI，适合个人开发者或小团队。

---

## 1.1 Fastlane 是什么？

```
Fastlane
├── gym        → 构建 .ipa / .app（替代 Xcode → Archive → Export）
├── match      → 证书 & Profile 管理（多设备共享签名）
├── pilot      → 上传 TestFlight & 管理测试员
├── deliver    → 上传 App Store（元数据 + 二进制）
├── scan       → 运行单元测试
├── sigh       → 管理 Provisioning Profile
├── cert       → 管理开发/发布证书
├── produce    → 在 App Store Connect 创建 App
├── snapshot   → 自动截图
├── frameit    → 截图加设备边框
└── pem        → 推送证书管理
```

**核心工作流**：

```
写代码 → gym 打包 → (match 签名) → pilot/deliver 上传
```

---

## 1.2 安装与环境准备

### 安装

```bash
# 推荐通过 Homebrew 安装
brew install fastlane

# 验证
fastlane --version

# 项目根目录初始化
cd YourProject
fastlane init
```

`fastlane init` 会自动创建 `fastlane/` 目录，包含 `Fastfile`、`Appfile`。

### 目录结构

```
YourProject/
├── fastlane/
│   ├── Fastfile          # 核心：定义所有 lane（任务）
│   ├── Appfile           # App 基本信息
│   ├── Matchfile         # match 配置（如果用 match）
│   └── README.md
└── Gemfile               # (可选) 依赖管理
```

---

## 1.3 Fastfile 基础结构

```ruby
default_platform(:ios)

platform :ios do
  before_all do
    # 所有 lane 执行前都会运行
    cocoapods
  end

  lane :build_debug do
    gym(
      scheme: "YourApp",
      workspace: "YourApp.xcworkspace",
      configuration: "Debug",
      export_method: "development",
      output_directory: "./builds"
    )
  end

  lane :build_release do
    gym(
      scheme: "YourApp",
      workspace: "YourApp.xcworkspace",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "./builds"
    )
  end

  after_all do |lane|
    # 每个 lane 成功后运行
    cleanup_build_artifacts
  end

  error do |lane, exception|
    # 出错时运行
    UI.error("Lane #{lane} failed: #{exception}")
  end
end
```

### 关键概念

| 概念 | 说明 |
|------|------|
| **lane** | 一个任务单元，如 `build_debug`、`beta`、`appstore` |
| **action** | 内置功能，如 `gym`、`pilot`、`cocoapods` |
| **before_all** | 该 platform 下所有 lane 的前置钩子 |
| **after_all** | 该 platform 下所有 lane 的后置钩子 |
| **error** | 异常处理 |

---

## 1.4 核心：gym 打包详解

`gym` 是 Fastlane 的构建工具，封装了 `xcodebuild`。

### 常用参数

```ruby
gym(
  # 必须
  scheme: "YourApp",                          # Xcode Scheme 名
  workspace: "YourApp.xcworkspace",           # 使用 CocoaPods/SPM 时必填

  # 编译配置
  configuration: "Release",                   # Debug / Release
  sdk: "iphoneos",                            # iphoneos / iphonesimulator

  # 输出
  output_directory: "./builds",               # .ipa 输出目录
  output_name: "YourApp_v1.0.0.ipa",          # 自定义 .ipa 文件名

  # 签名
  export_method: "app-store",                 # app-store / ad-hoc / development / enterprise
  export_team_id: "YOUR_TEAM_ID",

  # 高级
  derived_data_path: "./builds/DerivedData",  # 编译中间产物目录
  clean: true,                                # 是否先 clean
  include_bitcode: false,                     # App Store 已无需 bitcode
  include_symbols: true,                      # 包含 dSYM（Crash 分析用）

  # 跳过打包（只需编译验证时）
  skip_package_ipa: false,

  # Xcode 命令行参数透传
  xcargs: "-allowProvisioningUpdates"
)
```

### 实战：四种常见打包配置

```ruby
# 1. Debug 开发包（快速验证）
lane :build_debug do
  gym(
    scheme: "YourApp",
    configuration: "Debug",
    export_method: "development",
    output_directory: "./builds/debug",
    skip_package_ipa: false
  )
end

# 2. AdHoc 内测包（TestFlight 之外的第三方分发）
lane :build_adhoc do
  match(type: "adhoc")                       # 使用 adhoc 签名
  gym(
    scheme: "YourApp",
    configuration: "Release",
    export_method: "ad-hoc",
    output_directory: "./builds/adhoc",
    output_name: "YourApp_AdHoc.ipa"
  )
end

# 3. App Store 发布包
lane :build_appstore do
  match(type: "appstore")                    # 使用发布签名
  gym(
    scheme: "YourApp",
    configuration: "Release",
    export_method: "app-store",
    output_directory: "./builds/release",
    output_name: "YourApp_AppStore.ipa"
  )
end

# 4. 仅编译验证（不打包，CI 常用）
lane :test_compile do
  gym(
    scheme: "YourApp",
    configuration: "Debug",
    export_method: "development",
    skip_package_ipa: true,
    derived_data_path: "./builds/DerivedData"
  )
end
```

---

## 1.5 签名管理：match

### 为什么需要 match？

```
手动管理签名的问题：
  ├─ 每台 Mac 单独生成证书，团队协作困难
  ├─ 证书过期排查麻烦
  ├─ Profile 手动下载安装
  └─ 多人共用开发者账号时冲突

match 的解决方式：
  ├─ 证书 & Profile 加密存储在 Git 仓库
  ├─ 所有成员使用同一套签名
  ├─ 自动续期 & 修复
  └─ 一条命令配置所有设备
```

### 配置流程

```bash
# 1. 初始化（选择存储方式）
fastlane match init
# 会生成 fastlane/Matchfile

# 2. 创建开发证书 + Profile
fastlane match development

# 3. 创建发布证书 + Profile
fastlane match appstore

# 4. 创建 AdHoc 证书 + Profile
fastlane match adhoc
```

### Matchfile 配置

```ruby
git_url("https://github.com/yourname/certificates.git")
git_branch("master")
type("development")             # development / appstore / adhoc
app_identifier(["com.yourapp.*"])
username("your@appleid.com")
storage_mode("git")              # git / google_cloud / s3
```

### 在 lane 中使用 match

```ruby
lane :beta do
  match(type: "appstore", readonly: true)  # readonly: CI 环境只读
  gym(
    scheme: "YourApp",
    export_method: "app-store"
  )
  pilot
end
```

**关键参数**：

| 参数 | 说明 |
|------|------|
| `readonly: true` | CI 环境必须加，避免写 Git 仓库失败 |
| `force_for_new_devices: true` | 添加新设备时强制重新生成 Profile |
| `type` | `development` / `appstore` / `adhoc` / `enterprise` |

### 不依赖 match（自动签名）

如果不想用 match，Xcode 13+ 的 **自动签名** 也可工作：

```ruby
lane :build_with_auto_sign do
  gym(
    scheme: "YourApp",
    export_method: "development",
    xcargs: "-allowProvisioningUpdates"  # 允许 Xcode 自动管理签名
  )
end
```

---

## 1.6 版本号管理

Fastlane 提供两个 action：`increment_build_number` 和 `increment_version_number`。

```ruby
# 自动递增构建号（基于 App Store Connect 最新版本）
lane :beta do
  increment_build_number(
    build_number: number_of_commits       # 推荐：用 Git 提交数做构建号
  )
  gym(...)
  pilot
end

# 手动指定版本号
lane :release do
  increment_version_number(               # 更新 version（如 1.0.0 → 1.1.0）
    version_number: "1.1.0"
  )
  increment_build_number(
    build_number: 1                        # 新版本从 1 开始
  )
  gym(...)
  deliver
end
```

**最佳实践**：用 `number_of_commits` 作为构建号

```ruby
build_number = number_of_commits  # Git 总提交次数
increment_build_number(build_number: build_number)
```

这样每次提交构建号自动 +1，永远不会重复。

---

## 1.7 上传 TestFlight（pilot）

```ruby
lane :beta do
  match(type: "appstore", readonly: true)
  increment_build_number(build_number: number_of_commits)
  gym(scheme: "YourApp", export_method: "app-store")
  pilot(
    skip_waiting_for_build_processing: false,  # 是否等待 Apple 处理完成
    ipa: "./builds/YourApp.ipa",
    changelog: "本次更新内容：\n- 修复了 XXX bug\n- 优化了 YYY 性能",
    groups: ["Internal Testers"],               # 指定 Tester Group
    notify_external_testers: false              # 是否通知外部测试员
  )
end
```

### pilot 常用参数

| 参数 | 说明 |
|------|------|
| `skip_waiting_for_build_processing` | 默认 false，设为 true 则不等待处理完成 |
| `changelog` | 更新日志 |
| `groups` | 指定 Tester Group 数组 |
| `notify_external_testers` | 是否发邮件通知外部测试员 |
| `demo_account_required` | 是否需要演示账号 |
| `distribute_external` | 是否直接分发到外部测试 |

---

## 1.8 上传 App Store（deliver）

```ruby
lane :appstore do
  match(type: "appstore", readonly: true)
  increment_build_number(build_number: number_of_commits)

  # 方式一：自动上传
  gym(scheme: "YourApp", export_method: "app-store")

  deliver(
    ipa: "./builds/YourApp.ipa",
    submit_for_review: true,                  # 是否提交审核
    force: true,                              # 跳过元数据验证
    skip_metadata: true,                      # 跳过上传元数据
    skip_screenshots: true,                   # 跳过上传截图
    skip_app_version_update: false            # 更新版本信息
  )

  # 方式二：只上传二进制，不提交审核
  # upload_to_app_store(
  #   skip_metadata: true,
  #   skip_screenshots: true,
  #   submit_for_review: false      # 只上传，不提交审核
  # )
end
```

---

## 1.9 完整实战 Lane

### 个人开发者常用组合

```ruby
fastlane_version "2.220.0"
default_platform(:ios)

platform :ios do
  # ─── 编译验证 ───
  desc "仅编译验证代码"
  lane :check do
    gym(
      scheme: "YourApp",
      configuration: "Debug",
      export_method: "development",
      skip_package_ipa: true
    )
  end

  # ─── Debug 包 ───
  desc "打包 Debug 开发包"
  lane :debug do
    gym(
      scheme: "YourApp",
      configuration: "Debug",
      export_method: "development",
      output_directory: "./builds",
      output_name: "YourApp_Debug.ipa"
    )
  end

  # ─── TestFlight ───
  desc "打包并上传 TestFlight"
  lane :beta do
    match(type: "appstore", readonly: true)
    increment_build_number(build_number: number_of_commits)
    gym(
      scheme: "YourApp",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "./builds"
    )
    pilot(
      changelog: make_changelog,
      groups: ["Beta Testers"]
    )
  end

  # ─── App Store 发布 ───
  desc "打包并提交 App Store"
  lane :release do
    match(type: "appstore", readonly: true)
    increment_build_number(build_number: number_of_commits)
    gym(
      scheme: "YourApp",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "./builds"
    )
    deliver(
      skip_metadata: true,
      skip_screenshots: true,
      submit_for_review: true
    )
  end

  # ─── 自定义 changelog ───
  def make_changelog
    commits = last_git_commit_dict
    "Build #{number_of_commits}\n" +
    "Commit: #{commits[:abbreviated_commit_hash]}\n" +
    "Message: #{commits[:message]}"
  end
end
```

---

## 1.10 App Store Connect API 配置

Fastlane 推荐使用 **API Key** 替代账号密码（更安全，无需 2FA）。

### 获取 API Key

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 用户和访问 → 密钥 → 生成 API Key
3. 权限：选择 **App Manager**
4. 下载 `.p8` 文件（只能下载一次！）

### 配置方式

**方式一：环境变量（推荐）**

```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="ABC123DEF"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="12345678-1234-1234-1234-1234567890ab"
export APP_STORE_CONNECT_API_KEY_KEY="$(cat ~/Downloads/AuthKey_ABC123DEF.p8)"
```

**方式二：fastlane Appfile**

```ruby
app_identifier "com.yourapp"
apple_id "your@email.com"
team_id "YOUR_TEAM_ID"

# API Key 配置
app_store_connect_api_key(
  key_id: "ABC123DEF",
  issuer_id: "12345678-1234-1234-1234-1234567890ab",
  key_filepath: "./AuthKey_ABC123DEF.p8"
)
```

---

## 1.11 常见问题

### Q1: xcrun: error: unable to find utility "xcodebuild"

Xcode 路径未设置：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Q2: 签名错误 "No matching provisioning profiles found"

原因与解决：

```
├─ match 未运行 → fastlane match development (或 appstore)
├─ Bundle ID 不匹配 → 检查 Appfile app_identifier
├─ 证书过期 → fastlane match --force
└─ 设备未注册 (AdHoc) → fastlane match adhoc --force_for_new_devices
```

### Q3: 上传失败 "Redundant Binary"（重复二进制）

构建号未递增，或上次上传的处理还未完成。解决：

```ruby
increment_build_number(build_number: number_of_commits)
```

### Q4: pilot 上传后 TestFlight 一直 "Processing"

Apple 处理一般需要 5-30 分钟。若超过 2 小时：

```bash
fastlane pilot list  # 查看处理状态
```

或登录 App Store Connect 手动检查。

---

## 1.12 一键打包（完整命令参考）

```bash
# 项目根目录

# 编译验证
fastlane check

# Debug 包
fastlane debug

# TestFlight
fastlane beta

# App Store 发布
fastlane release

# 如果只想打包不上传
fastlane build_appstore

# 查看所有可用 lane
fastlane lanes

# 查看 actions 文档
fastlane action gym
```

---

## 1.13 推荐学习路径

1. **先跑通** `fastlane gym` 打包（1.4 节）
2. **配置签名** 选择 `match` 或 `自动签名`（1.5 节）
3. **掌握版本号管理**（1.6 节）
4. **尝试 TestFlight 上传**（1.7 节）
5. **最终打通 App Store 发布**（1.8 节）

---

## 相关资源

- 博客已有文章：`CI-CD/Fastlane + GitLab CI:CD.md`（侧重 CI 集成）
- 本文侧重**本地打包**
- 大厂面试题中 `06-高频考点TOP50.md` 有 Fastlane/CI 面试题
