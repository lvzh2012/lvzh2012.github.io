+++
date = '2026-04-24T19:28:42+08:00'
draft = false
title = 'GitLab Runner (User Mode) 使用文档'
tags = ["GitLab", "GitLab Runner", "macOS"]
categories = ["CI/CD"]
cover = "https://cdn.freebiesupply.com/logos/large/2x/gitlab-logo-png-transparent.png"

+++

# GitLab Runner (User Mode) 使用文档

本文档说明如何在 macOS 上使用 **user mode** 运行 GitLab Runner（推荐配合 Homebrew）。

## 1. 适用场景

- 机器是个人开发机（macOS）
- 希望用当前登录用户运行 Runner
- 希望通过 `brew services` 后台托管

> 建议：在 macOS 上选择一种模式长期使用。  
> 如果使用 user mode，请不要再混用 system mode（`sudo gitlab-runner install/start`）。

## 2. 安装 GitLab Runner

```bash
brew install gitlab-runner
gitlab-runner --version
```

## 3. 注册 Runner（user mode）

### 3.1 交互式注册（推荐）

```bash
gitlab-runner register --config "$HOME/.gitlab-runner/config.toml"
```

按提示填写：

- GitLab URL：`https://git.costnovel.com/`（GitLab 根地址，不是项目详情页 URL）
- Token：项目/组下发的 Runner token
- Description：例如 `shell-runner-macos`
- Tags：例如 `macos,shell`
- Executor：输入 `shell`

### 3.2 非交互注册

```bash
gitlab-runner register --non-interactive \
  --url "https://git.costnovel.com/" \
  --registration-token "YOUR_TOKEN" \
  --description "shell-runner-macos" \
  --tag-list "macos,shell" \
  --executor "shell" \
  --config "$HOME/.gitlab-runner/config.toml"
```

## 4. 启动 Runner（user mode）

```bash
brew services start gitlab-runner
brew services list
```

常用命令：

```bash
brew services restart gitlab-runner
brew services stop gitlab-runner
```

## 5. 验证 Runner 状态

> user mode 下验证时，不要加 `sudo`。

```bash
gitlab-runner list
gitlab-runner verify
```

预期有 `is alive` 字样。

## 6. `.gitlab-ci.yml` 标签匹配示例

Runner 标签是 `macos,shell` 时，Job 需匹配：

```yaml
build:
  stage: build
  tags:
    - macos
    - shell
  script:
    - echo "Hello, World!"
```

## 7. 常见问题排查

### 7.1 Pipeline 一直 pending

按顺序检查：

1. `brew services list` 确认 `gitlab-runner` 在运行
2. `gitlab-runner verify` 是否 `is alive`
3. GitLab 页面确认 Runner 未暂停（Paused = off）
4. Job `tags` 与 Runner 标签完全一致（区分大小写）
5. 若 Runner 开启 Protected，分支也必须是受保护分支

### 7.2 `Pipeline filtered out by workflow rules`

这不是 Runner 问题，是 `.gitlab-ci.yml` 里 `workflow.rules` 过滤了当前触发来源或分支。

### 7.3 前台能跑、后台不接任务

通常是模式混用导致（system mode 与 user mode 配置不一致）。  
请统一使用 user mode，并只使用以下命令管理：

```bash
gitlab-runner register --config "$HOME/.gitlab-runner/config.toml"
brew services start|stop|restart gitlab-runner
gitlab-runner verify
```

## 8. 安全建议

- 不要在聊天记录、截图、仓库里暴露 token
- token 一旦泄露，立即在 GitLab 后台 revoke/rotate
- 定期清理不再使用的 Runner
