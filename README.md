# 我的个人博客

这是一个使用 [Hugo](https://gohugo.io/) 构建的个人博客网站。

## 技术栈

- **静态站点生成器**: Hugo
- **主题**: Dream Theme
- **部署**: GitHub Pages
- **构建**: GitHub Actions

## 本地开发

### 前置要求

- Hugo Extended 版本 (推荐 0.97.0+)
- Git

### 运行步骤

1. 克隆仓库
```bash
git clone git@github.com:lvzh2012/lvzh2012.github.io.git
cd lvzh2012.github.io
```

2. 启动开发服务器
```bash
hugo server --buildDrafts
```

3. 访问 http://localhost:1313

### 构建生产版本

```bash
hugo --gc --minify
```

## 部署

网站通过 GitHub Actions 自动部署到 GitHub Pages。

- 网站地址: https://lvzh2012.github.io
- 每次推送到 `main` 分支时自动构建和部署

## 项目结构

```
myblog/
├── content/          # 博客内容
├── layouts/          # 自定义布局
├── static/           # 静态资源
├── themes/           # Hugo主题
├── hugo.toml         # Hugo配置文件
└── .github/          # GitHub Actions配置
```

## 许可证

MIT License
