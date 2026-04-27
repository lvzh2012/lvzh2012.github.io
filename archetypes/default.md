+++
date = '{{ .Date }}'
draft = true
title = '{{ replace .File.ContentBaseName "-" " " | title }}'
tags = [""]
categories = [""]

# cover: https://picsum.photos/1920/1080 随机每次刷新页面都会更改
cover = "https://picsum.photos/seed/{{ .Date }}/1920/1080"
+++
