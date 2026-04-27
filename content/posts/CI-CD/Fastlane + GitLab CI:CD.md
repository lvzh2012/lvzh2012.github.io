+++
date = '2026-04-26T16:22:32+08:00'
draft = true
title = 'Fastlane + GitLab CI/CD'
tags = ["Fastlane", "GitLab", "CI/CD"]
categories = ["CI/CD"]
cover = "https://images.unsplash.com/photo-1776518411187-de29b9b1bcc1?q=80&w=1742&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

+++

# iOS 项目 Fastlane + GitLab CI/CD 完整配置指南

**面向小白用户的详细教程**  
**项目**：snap2chat  
**最后更新**：2026-04-26

---

## 1. 这是什么？为什么需要？

这个文档教你如何使用 **Fastlane** 自动化打包 iOS App，并通过 **GitLab CI/CD** 实现：

- `runner_test` 分支 → 自动触发**编译测试**（`test_compile`）
- 其他分支 → 手动触发**上传 TestFlight**（Beta 测试）
- `main` 分支 → 手动触发**发布 App Store**

这样可以避免每次手动在 Mac 上打包、上传，大大提高效率。

---

## 2. 前置条件（必须准备好）

### 2.1 本地环境（已通过 Homebrew 安装）

```bash
# 确保已安装
brew install fastlane cocoapods

# 验证
fastlane --version
pod --version
ruby --version (有可能查看的是系统的版本信息)
# brew 查看版本信息
brew info fastlane
brew info pod
brew info ruby
```

### 2.2 项目文件结构（当前已有）

```
snap2chat/
├── fastlane/
│   ├── Fastfile          # 核心配置文件（所有 lane）
│   ├── Appfile           # 项目基本信息
│   └── README.md
├── .gitlab-ci.yml        # GitLab 流水线配置
├── Podfile
├── snap2chat.xcodeproj/
└── docs/
    └── IOS_CICD_FASTLANE_GITLAB_GUIDE.md   # 本文档
```

### 2.3 GitLab CI/CD Variables（**必须设置**）

进入 GitLab 项目 → **Settings → CI/CD → Variables**，添加以下 **Masked + Protected** 变量：

| 变量名                                | 说明                         | 示例值                                 |
| ------------------------------------- | ---------------------------- | -------------------------------------- |
| `MATCH_PASSWORD`                      | fastlane match 证书加密密码  | `your-strong-password`                 |
| `APP_STORE_CONNECT_API_KEY_KEY_ID`    | App Store Connect API Key ID | `ABC123DEF`                            |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID                    | `12345678-1234-1234-1234-1234567890ab` |
| `APP_STORE_CONNECT_API_KEY_KEY`       | .p8 文件完整内容（重要！）   | `-----BEGIN PRIVATE KEY-----...`       |

> **如何获取 API Key**：App Store Connect → Users and Access → Keys → 生成新的 API Key（选 **App Manager** 权限），下载 `.p8` 文件，把**全部内容**复制到变量中。

---

## 3. Fastlane 配置详解

### 3.1 `fastlane/Appfile`（项目基本信息）

```ruby
app_identifier "test.kaixin.ios.com"
apple_team_id "YOUR_TEAM_ID"   # 替换为你的 Team ID
```

**作用**：告诉 Fastlane 你的 App Bundle ID 和团队信息。

### 3.2 `fastlane/Fastfile`（核心逻辑）

以下是主要 lane 的**详细解释**：

#### (1) `install_deps` - 安装依赖（最基础）

```ruby
lane :install_deps do
  UI.message("🚀 Running pod install...")
  begin
    sh("pod install")
    UI.success("✅ Pods installed successfully using cache")
  rescue => ex
    UI.message("⚠️ pod install failed: #{ex.message}")
    sh("pod repo update --silent || true")
    sh("pod install")
    UI.success("✅ Pods installed successfully after repo update")
  end
end
```

**说明**：先尝试使用缓存安装，如果失败再更新仓库。避免了之前 `--repo-update` 总是失败的问题。

#### (2) `test_compile` - **测试编译**（您当前重点使用的）

```ruby
lane :test_compile do
  install_deps
  UI.header("🔨 Starting test compilation (Debug mode)")

  gym(
    scheme: "snap2chat",
    workspace: "snap2chat.xcworkspace",
    configuration: "Debug",           # 使用 Debug 更快
    export_method: "development",
    output_directory: "builds/test",
    skip_package_ipa: true,           # 关键！只编译不打包
    xcargs: "-allowProvisioningUpdates",
    derived_data_path: "builds/DerivedData"
  )

  UI.success("✅ Test compilation completed successfully!")
end
```

**用途**：`runner_test` 分支自动触发，用于快速验证代码是否能编译通过。

#### (3) `beta` - 上传 TestFlight

```ruby
lane :beta do
  install_deps
  # cert()  # 如果使用 match 证书管理则取消注释
  increment_build_number(...)   # 自动增加构建号
  gym(...)                      # 打包 Release 版本
  pilot(...)                    # 上传到 TestFlight
end
```

#### (4) `appstore` - 发布 App Store

类似 `beta`，但最后调用 `upload_to_app_store`。

---

## 4. GitLab CI/CD 配置（`.gitlab-ci.yml`）

```yaml
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH
    - if: $CI_COMMIT_TAG
    - if: $CI_PIPELINE_SOURCE == "web"
      when: always
    - when: never

stages:
  - test
  - deploy

variables:
  LC_ALL: en_US.UTF-8
  LANG: en_US.UTF-8
  FASTLANE_SKIP_UPDATE_CHECK: "1"

.default_job:
  tags:
    - macos
    - shell
  before_script:
    - echo "🚀 Starting iOS CI/CD for snap2chat (Homebrew mode)"
    - ruby --version
    - 'which fastlane && echo "✅ fastlane: $(which fastlane)" || (echo "❌ fastlane not found"; exit 1)'
    - 'which pod && echo "✅ pod: $(which pod)" || (echo "❌ pod not found"; exit 1)'
  artifacts:
    paths:
      - builds/*.ipa
    expire_in: 1 week
    when: always

# ==================== 以下是具体 Job ====================

test_compile:          # runner_test 分支专用
  extends: .default_job
  stage: test
  script:
    - echo "🔬 Running test compilation for runner_test branch..."
    - fastlane install_deps
    - fastlane test_compile
  rules:
    - if: $CI_COMMIT_BRANCH == "runner_test"
      when: always

testflight:            # 其他分支手动上传 TestFlight
  extends: .default_job
  stage: deploy
  script:
    - echo "📲 Building for TestFlight..."
    - fastlane install_deps
    - fastlane beta
  rules:
    - if: $CI_COMMIT_BRANCH != "main"
      when: manual
  environment: testflight

appstore:              # main 分支手动发布 App Store
  extends: .default_job
  stage: deploy
  script:
    - echo "🚀 Building for App Store..."
    - fastlane install_deps
    - fastlane appstore
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  environment: production
```

**逐行解释**：

- `stages`：定义两个阶段，test 用于快速测试，deploy 用于发布
- `.default_job`：所有 job 继承的公共配置（tags、before_script、artifacts）
- `rules` + `when: manual`：让发布操作需要人工点击“Play”按钮，更安全

---

## 5. 完整流程图

```mermaid
flowchart TD
    A[代码提交] --> B{分支判断?}
    B -->|runner_test 分支| C[test_compile Job]
    B -->|其他分支| D[testflight Job 手动]
    B -->|main 分支| E[appstore Job 手动]
    
    C --> F[install_deps → test_compile]
    F --> G[仅编译验证\n不打包IPA]
    G --> H[显示编译结果]
    
    D --> I[install_deps → beta lane]
    I --> J[gym打包 → pilot上传 TestFlight]
    
    E --> K[install_deps → appstore lane]
    K --> L[gym打包 → upload_to_app_store]
    
    subgraph "GitLab CI Pipeline"
    C
    D
    E
    end
    
    subgraph "Fastlane Lanes"
    F
    I
    K
    end
```

---

## 6. 完整验证流程（小白手把手）

### 6.1 本地验证（推荐先在本地跑通）

```bash
# 1. 进入项目目录
cd ~/Desktop/AI/snap2chat

# 2. 测试编译（最重要）
fastlane test_compile

# 3. 测试完整打包（可选）
fastlane build_ipa

# 4. 如果要测试上传（需要配置好 Variables）
# fastlane beta
```

**成功标志**：

- 看到 `✅ Test compilation completed successfully!`
- `builds/test/` 目录下有编译产物

### 6.2 GitLab Pipeline 验证

1. 将代码 push 到 `runner_test` 分支
2. 进入 GitLab → CI/CD → Pipelines
3. 应该自动运行 `test_compile` job
4. 切换到其他分支，应该看到 `testflight` 和 `appstore` 可手动触发

---

## 7. 常见问题排查

### 7.1 pod install 失败

- 见 `install_deps` 的容错逻辑
- 可手动运行 `pod install --repo-update`

### 7.2 Git 提交失败（HTTP Basic Access denied）

- 必须使用 **Personal Access Token**

- 命令：

  ```bash
  git remote set-url origin https://oauth2:YOUR_TOKEN@git.costnovel.com/cashbox-ai/snap2chat.git
  ```

### 7.3 编译失败（gym error）

- 检查 Xcode 是否能正常编译项目
- 查看 `builds/logs` 目录下的详细日志

---

## 8. 后续优化建议

1. 配置 `fastlane/match` 进行证书管理（推荐生产环境）
2. 添加 `scan` 运行单元测试
3. 配置 Slack/企业微信通知
4. 使用 `increment_version_number` 管理版本号

---

**文档结束**

如果您在任何一步遇到问题，请把错误信息发给我，我会继续帮您完善这个文档或修复配置。

**祝您打包顺利！** 🚀
