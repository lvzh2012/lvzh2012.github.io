+++
date = '2026-06-28T19:13:28+08:00'
draft = true
weight = 9
title = '第九章：性能优化与 UIKit（大厂高频 · 原理详解）'
tags = ["UIKit", "面试", "通用"]
categories = ['iOS 面试']
+++

# 第九章：性能优化与 UIKit（大厂高频 · 原理详解）

> 本章讲 **渲染管线、内存、缓存** 的底层机制，不只列优化清单。

---

## 9.1 卡顿原理：一帧 16.67ms 里发生了什么

### 屏幕刷新与 VSync

```
Display 每 16.67ms（60Hz）发 VSync 信号
    │
    ▼
GPU 把渲染好的帧缓冲区（Frame Buffer）送显
    │
    ▼
用户看到画面
```

**掉帧**：主线程在一帧时间内没准备好下一帧 → 重复显示旧帧 → 卡顿。

### 主线程一帧的典型工作

```
VSync 到来
  │
  ├─ RunLoop 处理 Touch / Timer / Source
  ├─ layoutSubviews / Auto Layout 求解
  ├─ drawRect: / Core Graphics 绘制
  ├─ Core Animation 提交 layer tree 给 Render Server
  └─ （GPU 侧）离屏渲染、合成、光栅化
```

**任何一步超时** 都可能掉帧。Instruments Time Profiler 看主线程；Core Animation 看 GPU。

### 卡顿监控原理


| 方案              | 原理                                           |
| --------------- | -------------------------------------------- |
| **FPS**         | `CADisplayLink` 统计每秒回调次数                     |
| **Ping 主线程**    | 子线程发信号，主线程 RunLoop 回应，超时则记录堆栈                |
| **RunLoop 观察者** | 监听 BeforeWaiting / AfterWaiting，某阶段耗时 > 阈值报警 |


---

## 9.2 渲染管线：UIView → 屏幕

### UIView 与 CALayer 的关系（继承与职责）

**继承关系**：

```
NSObject
  ├── UIResponder              ← 事件响应链根
  │     └── UIView             ← UIKit 视图，直接父类
  │           ├── UILabel / UIButton / UITableView …
  └── NSObject
        └── CALayer            ← QuartzCore，直接父类
              ├── CAShapeLayer / CAGradientLayer / CATextLayer …
```

UIView 直接继承自 **UIResponder**（间接 NSObject）；CALayer 直接继承自 **NSObject**。

**核心关系：UIView 是「宿主 + 门面」，CALayer 是「渲染引擎」**


| 维度       | UIView                              | CALayer                                    |
| -------- | ----------------------------------- | ------------------------------------------ |
| 职责       | **交互层**：触摸事件、响应链、Auto Layout        | **渲染层**：内容绘制、动画、帧合成                        |
| 事件       | hitTest / 响应链（UIResponder）          | ❌ **不处理触摸**                                |
| 从属       | 一个 UIView 对应一个根 layer（`view.layer`） | 一个 layer 可有多个 `sublayers`                  |
| 独立性      | 必须有 layer 才能显示                      | **可脱离 UIView 单独存在**（纯 layer 层）             |
| 动画       | block 动画封装                          | **隐式动画**（改属性自动有事务）——UIView 动画的底层           |
| delegate | layer 的 delegate 就是 view 本身         | view 实现 CALayerDelegate（layout/display 回调） |


**一一对应的属性映射（必背）**：


| UIView                        | CALayer                          |
| ----------------------------- | -------------------------------- |
| `frame` / `bounds` / `center` | `frame` / `bounds` / `position`  |
| `backgroundColor`（UIColor）※   | `backgroundColor`（CGColor）       |
| `alpha`                       | `opacity`                        |
| `hidden`                      | `hidden`                         |
| `clipsToBounds`               | `masksToBounds`                  |
| `cornerRadius`（无，走 layer）     | `cornerRadius` / `maskedCorners` |
| 阴影（无，走 layer）                 | `shadowColor` / `shadowOffset` 等 |


※ `view.backgroundColor` 本质也是**存到 layer 上**。

**为什么拆两层（面试加分）**：

1. **职责分离**：UIKit（交互/布局）与 QuartzCore（渲染）解耦，渲染层跨平台
2. **性能**：`CALayer` **更轻量**（无事件、无约束系统），纯装饰只用 layer（如 `CAShapeLayer` 绘制圆角/贝塞尔），省去 UIView 开销
3. 纯展示、不响应事件的场景用 layer 更省（系统内部大量这么干）

> **面试 30 秒版**：UIView 继承 `UIResponder` 负责**交互与布局**；CALayer 继承 `NSObject` 负责**渲染与动画**。每个 UIView 必有一个根 layer，UIView 是其 delegate；`frame/alpha/hidden` 一一映射到 layer 的 `position/opacity/hidden`，UIView 动画最终也是操作 layer（CATransaction）。CALayer 不响应触摸、可脱离 UIView 单独使用且更轻量。

### 渲染管线流程

```
UIView（逻辑树，负责交互）
    │  每个 UIView 对应一个 CALayer
    ▼
CALayer（渲染树，负责显示）
    │  修改 frame/bounds/contents → 标记 dirty
    ▼
Core Animation（Render Server 进程，跨进程）
    │  递归遍历 layer tree，生成绘制指令
    ▼
OpenGL/Metal（GPU）
    │  顶点处理 → 光栅化 → 片段着色
    ▼
Frame Buffer → 屏幕
```

### setNeedsLayout / setNeedsDisplay 原理

- 调用后 **不立即执行**，只 **标记 dirty**
- 当前 RunLoop 迭代结束时，统一 `layoutSubviews` / `display`
- 这样多次修改只 layout 一次，批量优化

---

## 9.3 离屏渲染（Off-screen Rendering）原理

### 什么是离屏渲染？

**正常路径（On-screen）**：

```
GPU 直接在当前屏幕缓冲区绘制 → 合成 → 显示
```

**离屏路径**：

```
GPU 先开辟 **离屏缓冲区** 单独绘制
    → 对结果做圆角/遮罩/阴影等效果
    → 再把结果 **合成** 到主缓冲区
```

多一次 **分配 + 绘制 + 合成**，内存和 GPU 时间翻倍，列表滚动时大量 cell 圆角 → 严重掉帧。

### 哪些属性会触发？


| 组合                                   | 原因                  |
| ------------------------------------ | ------------------- |
| `cornerRadius` + `masksToBounds=YES` | 需要按圆角裁剪，GPU 先离屏再裁   |
| 阴影无 `shadowPath`                     | 系统不知道阴影形状，先离屏算阴影    |
| `group opacity`                      | 子 layer 先合成到离屏再整体透明 |
| `shouldRasterize=YES`                | 故意光栅化到纹理缓存（静态内容可用）  |


### 如何优化？（理解原理后选型）


| 方案                                             | 原理                                  |
| ---------------------------------------------- | ----------------------------------- |
| **预渲染圆角图片**                                    | 圆角在 CPU 离线做好，GPU 只贴图，无裁剪            |
| **设置 shadowPath**                              | 告诉 GPU 阴影轮廓，跳过探索性离屏                 |
| **单独 CALayer 只设 cornerRadius 不 masksToBounds** | 仅当无子 layer 溢出时可行                    |
| **异步绘制**                                       | CPU 子线程画好 bitmap 设 `layer.contents` |


Instruments → Core Animation → **Color Offscreen-Rendered Yellow** 定位。

### 预渲染圆角图片实现（防离屏渲染 · 必会）

**核心思路**：把「圆角裁剪」从 GPU 渲染时提前到 CPU 绘制阶段——用 Core Graphics 把圆角效果直接「印」进位图，之后 `layer.contents` 只管贴图，GPU 零裁剪零离屏。

```objc
+ (UIImage *)roundedImage:(UIImage *)image
                   radius:(CGFloat)radius
                     size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // ① 圆角路径裁剪
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
        CGRectMake(0, 0, size.width, size.height) cornerRadius:radius];
    [path addClip];

    // ② 画图（顺带完成图片解码！）
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];

    // ③ 可选：描边
    [path stroke];

    UIImage *rounded = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rounded;
}
```

**使用姿势（关键：子线程生成 + 缓存）**：

```objc
// 头像场景
dispatch_async(roundQueue, ^{
    UIImage *rounded = [self roundedImage:rawImage radius:20 size:CGSizeMake(80, 80)];
    dispatch_async(dispatch_get_main_queue(), ^{
        cell.avatarView.layer.contents = (id)rounded.CGImage;
        // 或 cell.avatarView.image = rounded;
    });
});
```

**为什么这样就不离屏**：圆角效果（裁剪+描边）已固化在位图里，`UIImageView` 只是**平铺显示位图**——`cornerRadius + masksToBounds` 的「裁剪」动作不存在了。

**方案对比**：


| 方案                             | 处理位置       | 是否离屏渲染         | 适用               |
| ------------------------------ | ---------- | -------------- | ---------------- |
| **预渲染位图**                      | CPU（建议子线程） | ❌ 否（GPU 只贴图）   | **列表头像、大量 cell** |
| `cornerRadius + masksToBounds` | GPU 渲染时    | ✅ 是            | 少量简单 view        |
| `layer.mask = CAShapeLayer`    | GPU 渲染时    | ✅ 是（mask 也是离屏） | 复杂遮罩，数量少         |
| 设计切图                           | 无          | ❌              | 静态装饰最省           |


**注意事项（面试追问 / 工程边界）**：

1. **同时解决解码卡顿**：`drawInRect` 会触发解码，预渲染天然完成「子线程预解码」（呼应 §9.4）
2. **必须缓存**：圆角图不可复用 → 重复 CPU 绘制；`NSCache`，key = `url + radius + size`（SDWebImage 的 transformer 就这么做）
3. **尺寸别超过显示大小**：先 Downsample 再画圆角（呼应 §9.5），否则位图内存 4byte/px 白烧
4. **失去动态性**：圆角值改变要重新预渲染；有圆角渐变动画的场景不适合
5. **别过度设计**：静态页三五个圆角 view，直接 `cornerRadius + masksToBounds` 无所谓——**只有列表滚动大量触发才值得预渲染**

> **面试 30 秒版**：预渲染圆角 = 子线程 `UIBezierPath addClip` + `drawInRect` 把圆角画进位图，再设 `layer.contents`，把 GPU 离屏裁剪变成 CPU 离线绘制 + 直接贴图；配合尺寸/半径缓存和 Downsample 避免重复绘制与内存浪费。动画场景或 view 数量少时，直接 `cornerRadius + masksToBounds` 即可。

---

## 9.4 图片：从磁盘到屏幕

### 压缩格式 vs 内存位图

```
磁盘：JPEG/PNG/WebP（压缩编码，体积小）
         │  decode（解码）
         ▼
内存：Bitmap 位图 = 宽 × 高 × 每像素字节数
```

**阿里三面常考**：1024×1024 RGBA = 1024 × 1024 × **4** ≈ **4MB**。

JPEG 文件可能只有 200KB，但 **解码后仍占 4MB 内存**——面试易错点。

### UIImage 懒解码陷阱

`UIImage` 从文件加载时，**只读文件头**，不解码像素。

**首次 `drawRect:` / `CALayer.display`** 时在 **调用线程** 解码：

- 若在主线程 → 大图 decode 几十 ms → **卡顿**
- 若在子线程预解码 → 主线程只赋值 `contents` → 流畅

```objc
// 预解码思路：子线程 draw 到 CGContext，生成已解码 CGImage
UIGraphicsBeginImageContextWithOptions(size, NO, scale);
[image drawInRect:CGRectMake(0, 0, size.width, size.height)];
UIImage *decoded = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
```

### imageNamed vs contentsOfFile


|     | `imageNamed:`          | `imageWithContentsOfFile:` |
| --- | ---------------------- | -------------------------- |
| 缓存  | 系统 **NSCache** 缓存解码后图片 | 不缓存，读完即释                   |
| 查找  | 在主 Bundle 搜索 @2x/@3x   | 需完整路径                      |
| 适用  | 小图标、频繁复用               | 大图、一次性、相册                  |


---

## 9.5 SDWebImage 原理（字节一面 · 系统设计）

### 整体架构

```
sd_setImageWithURL:
    │
    ▼
SDWebImageManager（调度中心）
    ├── SDImageCache（内存 NSCache + 磁盘文件）
    ├── SDWebImageDownloader（NSURLSession 下载）
    └── SDWebImageTransformer（解码、缩放、圆角）
```

### 一次加载的完整流程

```
1. 生成 CacheKey = URL + transform 参数 + scale
2. 查 Memory Cache → 命中 → 主线程 setImage ✅
3. 查 Disk Cache → 命中 → 读文件 → 解码 → 写入 Memory → setImage
4. 未命中 → Downloader：
   a. 查 URL → Operation 映射表
   b. 若已有同 URL 下载中 → 当前 callback 挂到同一 Operation（去重）
   c. 若无 → 新建 Download Operation 入队
5. 下载完成 → 子线程解码 → 写 Disk → 写 Memory
6. 主线程回调所有等待的 ImageView
```

### TableView 多 Cell 同 URL 去重（字节真题）

**问题**：10 个 Cell 显示同一头像 URL → 不能发 10 次下载。

**原理**：

```objc
// 伪代码
NSMutableDictionary *urlToOperations;  // URL → SDWebImageDownloadOperation

- (void)loadURL:(NSURL *)url completed:(Block)block {
    SDWebImageDownloadOperation *op = urlToOperations[url];
    if (op) {
        [op addCompletion:block];  // 挂回调
        return;
    }
    op = [[SDWebImageDownloadOperation alloc] initWithURL:url];
    op.completions = @[block];
    urlToOperations[url] = op;
    [downloadQueue addOperation:op];
}
// 完成时遍历 completions 广播，移除映射
```

### 自研图片缓存要点


| 模块       | 职责                              |
| -------- | ------------------------------- |
| Memory   | `NSCache`，总成本限制，收到内存警告清空        |
| Disk     | 文件 = MD5(URL)，LRU 淘汰（访问时间）      |
| Download | 并发数限制、HTTPS、取消（Cell 滑出时 cancel） |
| Decode   | 子线程预解码 + Downsample（大图缩到显示尺寸）   |


**Downsample 原理**：3000×3000 图片显示在 100×100，`UIImageView` 只需 100×100 的 bitmap，提前缩放可省 **99% 内存**。

---

## 9.6 UITableView 重用机制原理

### 为什么需要重用？

1000 行数据若创建 1000 个 Cell → 内存爆炸、滑动卡顿。屏幕上可见约 10～15 个，**复用**即可。

### 内部数据结构（概念模型）

```
UITableView
  ├── visibleCells[]          当前屏幕上的 Cell
  ├── reusableQueue           字典 { identifier → [空闲 Cell 栈] }
  └── cellForRow 数据源回调
```

### dequeue 流程

```
dequeueReusableCellWithIdentifier:@"Cell"
    │
    ├─ reusableQueue[@"Cell"] 有闲置？
    │     YES → pop 一个 → prepareForReuse → 返回（跳过 alloc）
    │     NO  → [[Cell alloc] initWithStyle:...]  新建
    │
    └─ 配置数据 → 显示
```

Cell 滑出屏幕 → 不 destroy，放入 `reusableQueue` 对应 identifier 栈。

### prepareForReuse

系统调用，**重置 Cell 状态**：

- 清 image（防图片错乱）
- 取消网络请求
- 重置 text、选中态

### 常见问题与原理


| 现象   | 根因                      | 解法                                      |
| ---- | ----------------------- | --------------------------------------- |
| 图片错乱 | 异步回调回来时 Cell 已重用给别的 row | 回调里校验 `indexPath` / `url` 是否匹配          |
| 闪烁   | 重用后先显示旧图再换新图            | 置 placeholder、SDWebImage cancelPrevious |
| 高度跳动 | Auto Layout 每次重新算高      | 缓存 height；或手动 frame                     |


### NSArray O(1) 下标（美团）

`__NSArrayI`（immutable zero-based array）内部 **连续存储指针**，下标访问 = `base + index * sizeof(id)`，O(1)。  
对比链表 O(n)。`NSArray` 类簇，不同类型实现不同。

---

## 9.7 GIF 滑动不动原理（字节一面）

### RunLoop Mode

主线程 RunLoop 有多个 **Mode**，同一 Mode 下才处理 Source/Timer：


| Mode                    | 何时             |
| ----------------------- | -------------- |
| `NSDefaultRunLoopMode`  | 默认             |
| `UITrackingRunLoopMode` | ScrollView 滑动时 |
| `NSRunLoopCommonModes`  | 上面两个的合集        |


**滑动时** RunLoop 切到 `UITrackingRunLoopMode`：

- 注册在 `NSDefaultRunLoopMode` 的 Timer **暂停**
- GIF 逐帧解码常依赖 Timer → **动画停**

**解法**：

```objc
[runLoop addTimer:timer forMode:NSRunLoopCommonModes];
```

---

## 9.8 启动优化原理

### pre-main 阶段（dyld）

```
点击图标
  │
  ▼
内核加载 Mach-O
  │
  ▼
dyld：
  ① 加载依赖动态库（递归，每个 .dylib 都有开销）
  ② Rebase：修正内部指针（ASLR 偏移）
  ③ Bind：绑定外部符号（lazy/non-lazy）
  ④ ObjC setup：
     - 注册所有 class
     - 注册 Category（methodizeClass）
     - selector uniquing
  ⑤ 调用 +load（所有类、所有 Category 的 +load）
  │
  ▼
main() → UIApplicationMain
```

**耗时大头**：动态库数量、+load 里重逻辑、ObjC 类数量。

### post-main 阶段

```
didFinishLaunching
  → 各种 SDK 初始化（推送、统计、地图…）
  → 首屏 VC 加载 → viewDidLoad → 网络请求 → 首帧渲染
```

**首屏时间** = pre-main + didFinishLaunching + 首帧绘制。

### 优化与原理对应


| 优化         | 原理                           |
| ---------- | ---------------------------- |
| 减动态库       | dyld 加载每个库要 mmap、rebase、bind |
| +load 改懒加载 | +load 在 main 前串行执行           |
| 二进制重排      | 启动时访问的代码放同一物理页，减 page fault  |
| 延迟 SDK     | 挪到首屏后或子线程（注意线程安全）            |
| 骨架屏        | 首帧先画占位，感知速度提升                |


---

## 9.9 Auto Layout 原理（阿里 Masonry）

基于 **Cassowary** 线性约束求解器：

```
每个约束 = 线性方程  view1.attr = multiplier × view2.attr + constant
    │
    ▼
构建方程组 → 求解各 view 的 frame
```

**性能**：约束越多、嵌套越深，求解越慢。列表 **万级 Cell** 应用：

- 预计算 height 缓存
- 或手动 frame（layoutSubviews 里算）

**Masonry 写在哪**：

- `updateConstraints`：只 **添加/更新** 约束，可能被多次调用
- 避免在 `layoutSubviews` 里 **重复 addConstraint**

---

## 9.10 无 Instruments 如何查泄漏（美团）


| 手段                            | 原理                                                      |
| ----------------------------- | ------------------------------------------------------- |
| **Memory Graph**（Xcode Debug） | 运行时对象引用图，找 retain cycle                                 |
| **Zombie Objects**            | 对象 dealloc 不真释放，访问已释放对象 crash 并报 zombie                 |
| **malloc_stack**              | 记录每次 alloc 堆栈，泄漏对象找谁 alloc 的                            |
| **代码审查**                      | delegate 是否 weak、Block 是否 weak self、Timer 是否 invalidate |


---

## 9.11 大厂真题 ↔ 本章对照


| 题目                | 见本章  |
| ----------------- | ---- |
| 离屏渲染              | §9.3 |
| 图片内存 4MB          | §9.4 |
| SDWebImage / 自研缓存 | §9.5 |
| TableView 重用      | §9.6 |
| GIF 滑动            | §9.7 |
| 启动 pre-main       | §9.8 |
| 卡顿监控              | §9.1 |


