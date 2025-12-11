# Permalinks 配置对比示例

## 📁 当前文件结构

```
content/posts/
└── 技术/
    └── iOS/
        ├── LLDB.md
        ├── Swift Codable Macro.md
        ├── 全局pop返回手势.md
        └── 创建私有的podspec.md
```

## 🔗 不同配置下的 URL 对比

### 配置 1：当前配置（`:slug`）

```toml
[permalinks]
  posts = "/posts/:slug.html"
```

**生成的 URL**：
- `https://lvzh2012.github.io/posts/lldb.html`
- `https://lvzh2012.github.io/posts/swift-codable-macro.html`
- `https://lvzh2012.github.io/posts/全局pop返回手势.html`
- `https://lvzh2012.github.io/posts/创建私有的podspec.html`

**特点**：
- ✅ URL 简洁
- ✅ 不受目录结构影响
- ❌ 无法从 URL 看出分类

---

### 配置 2：使用目录结构（`:sections`）

```toml
[permalinks]
  posts = "/posts/:sections/:slug.html"
```

**生成的 URL**：
- `https://lvzh2012.github.io/posts/技术/iOS/lldb.html`
- `https://lvzh2012.github.io/posts/技术/iOS/swift-codable-macro.html`
- `https://lvzh2012.github.io/posts/技术/iOS/全局pop返回手势.html`
- `https://lvzh2012.github.io/posts/技术/iOS/创建私有的podspec.html`

**特点**：
- ✅ URL 反映目录结构
- ✅ 便于理解内容分类
- ⚠️ 中文路径会被 URL 编码

---

### 配置 3：使用分类（`:categories`）

假设文章的 front matter 是：
```yaml
categories: ['XCode调试']
```

```toml
[permalinks]
  posts = "/posts/:categories/:slug.html"
```

**生成的 URL**：
- `https://lvzh2012.github.io/posts/XCode调试/lldb.html`
- `https://lvzh2012.github.io/posts/Swift/swift-codable-macro.html`
- `https://lvzh2012.github.io/posts/iOS/全局pop返回手势.html`
- `https://lvzh2012.github.io/posts/CocoaPods/创建私有的podspec.html`

**特点**：
- ✅ 使用 front matter 中的分类
- ✅ 不依赖文件位置
- ⚠️ 需要确保每篇文章都有正确的 categories

---

### 配置 4：按日期组织

```toml
[permalinks]
  posts = "/posts/:year/:month/:slug.html"
```

**生成的 URL**（假设日期是 2025-12-09）：
- `https://lvzh2012.github.io/posts/2025/12/lldb.html`
- `https://lvzh2012.github.io/posts/2025/12/swift-codable-macro.html`
- `https://lvzh2012.github.io/posts/2025/12/全局pop返回手势.html`
- `https://lvzh2012.github.io/posts/2025/12/创建私有的podspec.html`

**特点**：
- ✅ 按时间组织，便于归档
- ✅ URL 包含时间信息
- ❌ 无法体现内容分类

---

### 配置 5：混合使用（日期 + 分类）

```toml
[permalinks]
  posts = "/posts/:year/:categories/:slug.html"
```

**生成的 URL**：
- `https://lvzh2012.github.io/posts/2025/XCode调试/lldb.html`
- `https://lvzh2012.github.io/posts/2025/Swift/swift-codable-macro.html`

**特点**：
- ✅ 同时包含时间和分类信息
- ✅ 便于归档和分类浏览
- ⚠️ URL 较长

---

## 🎯 推荐方案

### 对于你的博客，我推荐：

**方案 A：保持当前配置（如果内容不多）**
```toml
[permalinks]
  posts = "/posts/:slug.html"
```
- 简洁明了
- 便于分享
- 不受目录重组影响

**方案 B：使用目录结构（如果想在 URL 中体现分类）**
```toml
[permalinks]
  posts = "/posts/:sections/:slug.html"
```
- URL 反映内容组织
- 便于理解文章分类
- 如果以后添加其他分类（如 `技术/前端/`），URL 会自动包含

## ⚠️ 修改配置的注意事项

如果要从当前配置改为其他配置：

1. **备份当前配置**
2. **设置重定向**（避免 404）：
   ```toml
   # 在 hugo.toml 中添加
   [permalinks]
     posts = "/posts/:sections/:slug.html"
   
   # 或者使用别名（在每篇文章的 front matter 中）
   aliases:
     - /posts/lldb.html  # 旧 URL
   ```

3. **测试新配置**：
   ```bash
   hugo server
   # 访问 http://localhost:1313/posts/ 检查 URL
   ```

## 📝 如何修改配置

编辑 `hugo.toml` 文件，找到：
```toml
[permalinks]
  posts = "/posts/:slug.html"
```

修改为你想要的格式，例如：
```toml
[permalinks]
  posts = "/posts/:sections/:slug.html"
```

保存后重启 Hugo 服务器即可生效。
