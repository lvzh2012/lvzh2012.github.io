+++
date = '2025-12-15T14:22:28+08:00'
draft = false
title = 'Homebrew Tap'
tags = ["homebrew"]
categories = ["homebrew"]
cover = "https://images.unsplash.com/photo-1762887863007-26facb90ef24?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

+++

# Homebrew Tool Tap

这是一个私有的 Homebrew tap，用于安装和管理自定义工具。

## 安装 Tap

### 方法 1: 本地 Git 仓库（推荐用于本地开发）

```bash
brew tap xxx/tool file:///Users/xxx/Desktop/Swift/tool/homebrew-tool
```

**注意**：确保 `homebrew-tool` 目录已经初始化为 Git 仓库（已完成）。

### 方法 2: Git 远程仓库（推荐用于分享）

如果你已经将这个目录推送到 Git 仓库：

```bash
brew tap xxx/tool <git-repo-url>
```

例如：

```bash
brew tap xxx/tool https://github.com/xxx/tool.git
```

### 方法 3: 直接使用本地路径（如果上述方法不行）

```bash
brew tap xxx/tool /Users/xxx/Desktop/Swift/tool/homebrew-tool
```

## 安装工具

安装测试工具：

```bash
brew install test-tool
```

## 使用方法

安装完成后，可以直接在终端中使用 `test-tool` 命令：

```bash
test-tool
```

**输出示例：**

```
Welcome to use this tool!!!
```

### 验证安装

检查工具是否已正确安装：

```bash
which test-tool
# 应该输出: /opt/homebrew/bin/test-tool (或类似路径)

test-tool --version
# 或者直接运行查看输出
```

### 工具位置

安装后，`test-tool` 可执行文件位于：

- **Apple Silicon (M1/M2)**: `/opt/homebrew/bin/test-tool`
- **Intel Mac**: `/usr/local/bin/test-tool`

你可以通过以下命令查看：

```bash
brew list test-tool
```

## 卸载工具

```bash
brew uninstall test-tool
```

## 移除 Tap

如果你想完全移除这个 tap（包括所有通过此 tap 安装的工具）：

```bash
brew untap xxx/tool
```

**注意**：

- `brew untap` 只会移除 tap 本身，不会自动卸载通过该 tap 安装的工具
- 如果你想先卸载所有工具再移除 tap，可以这样做：

```bash
# 先卸载所有通过此 tap 安装的工具
brew uninstall test-tool

# 然后移除 tap
brew untap xxx/tool
```

### 查看已安装的 Tap

#### 查看所有已安装的 tap

列出所有已安装的 tap：

```bash
brew tap
```

**输出示例：**

```
homebrew/core
homebrew/cask
xxx/tool
```

#### 查看特定 tap 的详细信息

查看某个 tap 的详细信息，包括：

- Tap 的路径
- Formula 数量
- 是否已安装
- 最后更新时间

```bash
brew tap-info xxx/tool
```

查看所有 tap 的详细信息：

```bash
brew tap-info --installed
```

#### 查看 tap 中可用的 Formula

查看某个 tap 中所有可用的 Formula（工具）：

```bash
brew search xxx/tool
```

或者：

```bash
ls /opt/homebrew/Library/Taps/xxx/homebrew-tool/
```

#### 查看 tap 的安装路径

查看 tap 在系统中的实际位置：

```bash
brew --repo xxx/tool
```

**输出示例：**

```
/opt/homebrew/Library/Taps/xxx/homebrew-tool
```

#### 检查 tap 是否已安装

检查特定 tap 是否已安装：

```bash
brew tap | grep xxx/tool
```

如果已安装，会显示 `xxx/tool`；如果未安装，则没有输出。

## 更新 Tap

```bash
brew update
```

## 目录结构

```
homebrew-tool/
├── README.md          # 本文件
└── test-tool.rb       # Test Tool 的 Formula
```

## 添加新的 Formula

1. 在 `homebrew-tool/` 目录下创建新的 `.rb` 文件
2. 按照 Homebrew Formula 规范编写 Formula
3. 使用 `brew install <formula-name>` 安装

### 生成 SHA256 校验和

在创建或更新 Formula 时，需要为下载的文件生成 SHA256 校验和。Homebrew 使用这个校验和来验证文件的完整性。

#### 方法 1: 使用 `shasum` 命令（macOS 内置）

对于本地文件：

```bash
shasum -a 256 /path/to/your/file
```

**示例：**

```bash
cd /Users/xxx/Desktop/Swift/tool/homebrew-tool
shasum -a 256 test.py
```

**输出示例：**

```
bd12cfb53cc7c7bb8881f3625a93695c75ff65f4b65caed7f30c66055c737728  test.py
```

只需要复制 SHA256 值（第一列）到 Formula 文件中。

#### 方法 2: 使用 `sha256sum` 命令（如果可用）

```bash
sha256sum /path/to/your/file
```

#### 方法 3: 使用 Homebrew 的 `brew fetch` 命令

如果文件已经可以通过 URL 访问，可以使用：

```bash
brew fetch --formula <formula-name>
```

这会显示下载文件的 SHA256 值。

#### 方法 4: 使用 `openssl` 命令

```bash
openssl dgst -sha256 /path/to/your/file
```

**输出示例：**

```
SHA256(/path/to/your/file)= bd12cfb53cc7c7bb8881f3625a93695c75ff65f4b65caed7f30c66055c737728
```

#### 在 Formula 中使用 SHA256

将生成的 SHA256 值添加到 Formula 文件中：

```ruby
class YourTool < Formula
  # ... 其他配置 ...
  url "file://#{File.expand_path(__dir__)}/your-file"
  sha256 "bd12cfb53cc7c7bb8881f3625a93695c75ff65f4b65caed7f30c66055c737728"
  # ... 其他配置 ...
end
```

#### 注意事项

- **更新文件后必须更新 SHA256**：如果修改了源文件，必须重新计算并更新 Formula 中的 SHA256 值
- **SHA256 是必需的**：Homebrew 要求所有下载的文件都有 SHA256 校验和（除非使用 `:no_check` 跳过，但不推荐）
- **验证 SHA256**：安装时 Homebrew 会自动验证文件的 SHA256，如果不匹配会报错

## 注意事项

- 这是一个本地 tap，Formula 中的 URL 使用 `file://` 协议
- 如果需要分享给其他人，建议将 tap 推送到 Git 仓库
- 确保脚本有执行权限

