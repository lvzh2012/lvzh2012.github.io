+++
date = '2026-04-30T18:13:25+08:00'
draft = false
title = 'Git'
tags = ["Git"]

categories = ["Git"]

cover = "https://picsum.photos/seed/2026-04-30T18:13:25+08:00/1920/1080"
+++

# Git

### Rebase

1. 在 `1.0.0` 上执行 `rebase main` —— 把 `1.0.0` 的提交重放到 `main` 顶端
2. 把 `main` 指针快进到 `1.0.0` 的位置(fast-forward,不会产生 merge commit)

```git
git checkout main
git pull origin main
git checkout 1.0.0
git rebase main
git checkout main
git merge --ff-only 1.0.0
```

