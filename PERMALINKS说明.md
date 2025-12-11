# Hugo Permalinks 详细说明

## 📖 什么是 Permalinks？

**Permalinks（永久链接）** 是 Hugo 中用于控制内容页面 URL 结构的配置。它决定了你的文章、页面等在网站上的访问地址。

## 🔗 Permalinks 与子目录的关系

### 核心概念

**重要理解：**
- **Content 目录结构** ≠ **URL 结构**
- Content 目录用于**组织文件**（方便管理）
- Permalinks 用于**控制 URL**（用户访问的地址）

### 当前配置分析

你的当前配置：
```toml
[permalinks]
  posts = "/posts/:slug.html"
```

这意味着：
- 无论文件在 `content/posts/` 下的哪个子目录
- 最终 URL 都是：`/posts/文件名.html`
- **子目录路径不会出现在 URL 中**

### 示例对比

假设你有文件：`content/posts/技术/iOS/LLDB.md`

#### 当前配置（`:slug`）
- **文件路径**：`content/posts/技术/iOS/LLDB.md`
- **生成的 URL**：`/posts/lldb.html`
- **完整 URL**：`https://lvzh2012.github.io/posts/lldb.html`

#### 如果使用 `:categories` 配置
```toml
[permalinks]
  posts = "/posts/:categories/:slug.html"
```
- **文件路径**：`content/posts/技术/iOS/LLDB.md`
- **生成的 URL**：`/posts/技术/iOS/lldb.html`
- **完整 URL**：`https://lvzh2012.github.io/posts/技术/iOS/lldb.html`

## 📝 Permalinks 可用变量

Hugo 提供了多种变量来构建 URL：

| 变量 | 说明 | 示例值 |
|------|------|--------|
| `:slug` | 文件名（不含扩展名） | `lldb` |
| `:title` | 文章标题（front matter 中的 title） | `LLDB` |
| `:filename` | 完整文件名（不含扩展名） | `LLDB` |
| `:section` | Section 名称（通常是父目录名） | `posts` |
| `:sections` | 所有父级目录（用 `/` 分隔） | `技术/iOS` |
| `:year` | 年份（4位数字） | `2025` |
| `:month` | 月份（2位数字） | `12` |
| `:day` | 日期（2位数字） | `09` |
| `:categories` | 分类（front matter 中的 categories） | `XCode调试` |
| `:tags` | 标签（front matter 中的 tags） | `调试` |

## 🎯 常用 Permalinks 配置示例

### 1. 简单格式（当前使用）
```toml
[permalinks]
  posts = "/posts/:slug.html"
```
**结果**：`/posts/lldb.html`

### 2. 包含分类路径
```toml
[permalinks]
  posts = "/posts/:categories/:slug.html"
```
**结果**：`/posts/XCode调试/lldb.html`

### 3. 包含子目录结构
```toml
[permalinks]
  posts = "/posts/:sections/:slug.html"
```
**结果**：`/posts/技术/iOS/lldb.html`

### 4. 按日期组织
```toml
[permalinks]
  posts = "/posts/:year/:month/:slug.html"
```
**结果**：`/posts/2025/12/lldb.html`

### 5. 混合使用
```toml
[permalinks]
  posts = "/posts/:year/:categories/:slug.html"
```
**结果**：`/posts/2025/XCode调试/lldb.html`

### 6. 完整路径（包含所有层级）
```toml
[permalinks]
  posts = "/posts/:sections/:slug.html"
```
**结果**：`/posts/技术/iOS/lldb.html`

## 🔄 子目录与 Permalinks 的对应关系

### 情况 1：使用 `:slug`（当前配置）

**文件结构**：
```
content/posts/
├── 技术/
│   └── iOS/
│       └── LLDB.md
└── 生活/
    └── 旅行.md
```

**URL 结果**：
- `/posts/lldb.html`
- `/posts/旅行.html`

**特点**：子目录不影响 URL，所有文章都在 `/posts/` 下

### 情况 2：使用 `:sections`

**文件结构**（同上）

**URL 结果**：
- `/posts/技术/iOS/lldb.html`
- `/posts/生活/旅行.html`

**特点**：URL 完全反映文件目录结构

### 情况 3：使用 `:categories`

**文件结构**（同上）

**Front Matter**：
```yaml
categories: ['XCode调试']
```

**URL 结果**：
- `/posts/XCode调试/lldb.html`

**特点**：URL 使用 front matter 中定义的分类，而不是文件路径

## ⚠️ 重要注意事项

### 1. URL 变更的影响

**如果修改 permalinks 配置：**
- 旧的 URL 会失效（404 错误）
- 搜索引擎索引会失效
- 外部链接会失效
- **建议**：在修改前做好重定向配置

### 2. `:sections` vs `:categories`

- **`:sections`**：基于**文件目录结构**
  - 文件在 `content/posts/技术/iOS/` → sections = `技术/iOS`
  
- **`:categories`**：基于**front matter 中的 categories**
  - 即使文件在 `content/posts/技术/iOS/`，如果 front matter 中 `categories: ['Swift']`，URL 会是 `/posts/Swift/...`

### 3. 中文路径问题

如果使用中文目录名或分类名：
- URL 会被 URL 编码（如：`技术` → `%E6%8A%80%E6%9C%AF`）
- 可能影响 SEO 和可读性
- **建议**：使用英文目录名，或使用 `:slug` 避免中文路径

### 4. 多个分类的处理

如果文章有多个分类：
```yaml
categories: ['iOS', 'Swift']
```

使用 `:categories` 时，Hugo 会使用**第一个分类**。

## 🛠️ 推荐配置方案

### 方案 A：保持简洁（推荐用于新站）

```toml
[permalinks]
  posts = "/posts/:slug.html"
```

**优点**：
- URL 简洁易记
- 不受目录结构影响
- 便于迁移和重组

**适用场景**：内容不多，不需要复杂的分类结构

### 方案 B：反映目录结构（推荐用于有组织的博客）

```toml
[permalinks]
  posts = "/posts/:sections/:slug.html"
```

**优点**：
- URL 反映内容组织
- 便于理解内容分类
- 支持多级分类

**适用场景**：内容较多，需要清晰的分类体系

### 方案 C：使用分类（推荐用于依赖 front matter 的场景）

```toml
[permalinks]
  posts = "/posts/:categories/:slug.html"
```

**优点**：
- 灵活，不依赖文件位置
- 可以一个文件属于多个分类（使用第一个）

**适用场景**：分类经常变化，或需要与文件位置解耦

## 📊 你的当前情况

**当前配置**：
```toml
[permalinks]
  posts = "/posts/:slug.html"
```

**文件结构**：
```
content/posts/技术/iOS/LLDB.md
```

**生成的 URL**：`/posts/lldb.html`

**建议**：
- 如果希望 URL 反映目录结构，可以改为：
  ```toml
  [permalinks]
    posts = "/posts/:sections/:slug.html"
  ```
  这样 URL 会是：`/posts/技术/iOS/lldb.html`

- 如果希望保持简洁，当前配置就很好

## 🔍 如何测试 Permalinks

1. **启动 Hugo 服务器**：
   ```bash
   hugo server
   ```

2. **查看生成的 URL**：
   - 访问 `http://localhost:1313/posts/`
   - 查看文章链接的 URL

3. **检查文件系统**：
   ```bash
   hugo --destination public
   ls -R public/posts/
   ```

## 📚 相关资源

- [Hugo 官方文档 - Permalinks](https://gohugo.io/content-management/urls/#permalinks)
- [Hugo 变量参考](https://gohugo.io/variables/page/)
