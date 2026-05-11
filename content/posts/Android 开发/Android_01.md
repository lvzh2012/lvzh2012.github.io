+++
date = '2026-05-06T15:44:20+08:00'
draft = false
title = 'Android_01'

tags = ["Andorid ", "Jetpack", "Compose"]

categories = ["Andorid 开发"]

cover = "https://picsum.photos/seed/2026-05-06T13:44:20+08:00/1920/1080"
+++

# Android开发

### 编译

```groovy
./gradlew assembleDebug
```

### 布局

#### LinearLayout

> [!NOTE]
>
> 与UIStackView类似 支持水平，垂直布局

常用属性与影响：

| Android 属性 | 影响 | iOS 对照 |
| --- | --- | --- |
| `android:orientation`（`horizontal` / `vertical`） | 决定主轴方向。`horizontal` 时子 View 横向排列，`vertical` 时纵向排列。 | `UIStackView.axis`（`.horizontal` / `.vertical`） |
| `android:gravity` | 控制容器内所有子 View 的整体对齐方式（如居中、靠底、靠右）。 | `UIStackView.alignment` + `distribution`（部分语义对应，不是完全一一映射） |
| `android:baselineAligned`（默认 `true`） | 在水平布局中按文本基线对齐，文本类控件对齐更自然；关闭后可减少一次基线计算。 | `UIStackView.alignment = .firstBaseline / .lastBaseline` |
| 子 View 的 `android:layout_weight` + `android:layout_width/height=0dp` | 按权重分配剩余空间；权重使用不当会增加测量复杂度（多次 measure）。 | `UIStackView.distribution = .fillProportionally / .fillEqually`，或 Auto Layout 比例约束 |
| 子 View 的 `android:layout_gravity` | 控制单个子 View 在父容器中的对齐方式，优先级高于部分父容器默认对齐。 | 子视图约束（`NSLayoutConstraint`）或 `UIStackView` 的 `alignment` 组合 |

#### FrameLayout 

堆叠组件 类似ZStack

常用属性与影响：

| Android 属性 | 影响 | iOS 对照 |
| --- | --- | --- |
| `android:foreground` | 在内容层上方绘制前景（如遮罩、点击态 Ripple），常用于卡片高亮与可点击反馈。 | 额外 overlay `UIView` 或 `CALayer`（无完全等价单属性） |
| `android:foregroundGravity` | 控制前景在 FrameLayout 中的位置（如居中、顶部）。 | overlay 视图的 Auto Layout 定位约束 |
| `android:measureAllChildren` | 是否测量 `GONE` 子 View。开启后有助于过渡动画场景，但会增加测量开销。 | `isHidden` 视图通常不参与渲染，但约束系统是否参与计算取决于约束关系 |
| 子 View 的 `android:layout_gravity` | 在堆叠容器内控制单个子 View 对齐位置（例如右下角角标）。 | `ZStack`（SwiftUI）`alignment` 或 UIKit 子视图定位约束 |

适用场景：

- 叠层 UI（背景图 + 文案 + 按钮）
- 悬浮角标、加载蒙层、点击态覆盖层

#### ConstraintLayout 

> [!NOTE]
>
> Autolayout

常用属性与影响：

| Android 属性 | 影响 | iOS 对照 |
| --- | --- | --- |
| `app:layout_constraintStart_toStartOf` / `End_toEndOf` / `Top_toTopOf` / `Bottom_toBottomOf` | 定义基础锚点约束关系，决定 View 相对父容器或兄弟控件的位置。 | `leading/trailing/top/bottomAnchor` 约束 |
| `app:layout_constraintHorizontal_bias` / `Vertical_bias`（`0.0~1.0`） | 在双向约束成立时决定偏移比例（如更靠左或更靠右）。 | 无直接单属性；常通过约束优先级或 spacer 约束组合实现 |
| `app:layout_constraintDimensionRatio`（如 `16:9`） | 按比例约束宽高，常用于图片、视频卡片，减少手工计算尺寸。 | `widthAnchor.constraint(equalTo: heightAnchor, multiplier:)` |
| `app:layout_constraintHorizontal_chainStyle` / `Vertical_chainStyle` | 链式布局可实现均分、紧凑、加权分配，替代部分线性布局嵌套。 | `UIStackView.distribution` 或多视图约束组 |
| `app:layout_goneMarginStart` / `goneMarginTop` 等 | 当目标锚点 View 为 `GONE` 时，使用备用 margin，避免界面塌陷。 | 动态更新 constraint constant、激活/失活约束 |
| `app:layout_constraintWidth_default="wrap"` + `app:layout_constraintWidth_min/max` | 提供最小/最大边界，增强大屏与小屏适配稳定性。 | `contentCompressionResistance`、`contentHugging`、`>=` / `<=` 约束 |

实践建议：

- 优先减少深层嵌套，使用约束关系表达层级，可降低层级复杂度。
- 复杂交互布局优先使用 `ConstraintLayout`，简单线性排列仍推荐 `LinearLayout`。
- 大量动态状态变化时，注意约束数量与可读性，必要时引入 `Group` / `Barrier` / `Guideline` 优化结构。

