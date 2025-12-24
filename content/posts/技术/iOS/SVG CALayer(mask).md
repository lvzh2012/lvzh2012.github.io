+++
date = '2025-12-23T16:44:11+08:00'
draft = false
title = 'SVG在iOS中的处理方式'
tags = ["iOS", "SVG"]
categories = ["iOS", "SVG"]
cover = "https://plus.unsplash.com/premium_photo-1719943511528-7589c22de3ae?q=80&w=1742&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
+++

在iOS中我们可以用SVG去绘制不规则图形

## 实现方式:

### 1. 利用浏览器打开SVG图片,显示源码,粘贴源码

告诉Cursor这种专业的工具,绘制UIBezierPath

然后同样设置指定目标view的layer.mask属性为绘制的path

### 2. 在线工具转换

http://svg-converter.kyome.io/

### 3. 直接加载SVG转换成指定平台的控件

Android: 天然支持SVG

iOS: UIImage

使用layer.mask属性可以设置成对应的形状

```swift
let svgImage = UIImage(named: "Light")
let maskLayer = CALayer()
maskLayer.contents = svgImage?.cgImage
contentView.layer.mask = maskLayer
```

