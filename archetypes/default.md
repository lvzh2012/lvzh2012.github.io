+++
date = '{{ .Date }}'
draft = true
title = '{{ replace .File.ContentBaseName "-" " " | title }}'
tags = ["Swift"]
# 可选栏目（与 content/posts 下目录一致）：iOS 开发 | 依赖管理 | 调试 | CI/CD | 工具与环境
categories = ["iOS 开发"]

# cover: https://picsum.photos/1920/1080 随机每次刷新页面都会更改
cover = "https://picsum.photos/seed/{{ .Date }}/1920/1080"
+++
