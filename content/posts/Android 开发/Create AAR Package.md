+++
date = '2026-05-09T16:18:51+08:00'
draft = false
title = 'Create AAR Package'
tags = ["Android"]

categories = ["Android 开发"]

cover = "https://picsum.photos/seed/2026-05-09T16:18:51+08:00/1920/1080"
+++

# Android AAR 包创建与发布完整指南

> 本指南基于 **AGP 8.x / 9.x + Gradle 8.x / 9.x** 编写，涵盖了从传统 Kotlin 插件到 AGP 9.0+ 内置 Kotlin 的演进。
> 适用于任何标准的 Android Library 开发与发布流程。

---

[TOC]

---

## 一、AAR vs APK：核心区别

| 维度 | APK（Application） | AAR（Library） |
|---|---|---|
| Gradle 插件 | `com.android.application` | `com.android.library` |
| 输出产物 | `app-release.apk` | `app-release.aar` |
| `applicationId` | ✅ 必须 | ❌ 不支持 |
| `versionCode` / `versionName` | ✅ 必须 | ❌ 不支持 |
| `targetSdk` | ✅ 影响 Play 行为 | ❌ 不消费 |
| 版本号控制方式 | `versionName = "1.0"` | `version = "1.0.0"`（Gradle 项目属性） |
| 混淆规则 | `proguardFiles` | **`consumerProguardFiles`** |
| ProGuard 时机 | 自己被混淆 | 规则交给消费方使用 |

> 一句话：**AAR 是给别人用的代码库，没有"应用入口"概念**。所有应用专属字段（图标、主题、applicationId、版本号）都不属于 AAR。

---

## 二、从零创建 AAR 项目

推荐流程：

1. 在 Android Studio 用模板创建一个空 Android 项目（New Project → Empty Activity / No Activity）。
2. **把 application 模块改造成 library 模块**（本指南后面章节就是干这个的）。
3. 或者：在已有项目里 **New → New Module → Android Library** 直接创建一个 library 模块。

如果是从 Empty Activity 模板改造（本工程的情况），需要做 4 件事：

1. 改 `app/build.gradle.kts` 的插件 `application` → `library`
2. 删除 `applicationId`、`versionCode`、`versionName`、`targetSdk`
3. 清理 `AndroidManifest.xml` 里的 application 元素
4. 清理 `res/` 下的应用模板资源（图标、主题、备份规则等）

---

## 三、`AndroidManifest.xml` 写法

AAR 模块的 manifest 应当**极简**。所有 SDK 配置（`minSdkVersion` 等）都应该交给 `build.gradle.kts`，不要手写 `<uses-sdk>`。

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

</manifest>
```

> ⚠️ 不要手写 `<uses-sdk android:minSdkVersion="30" />`：Lint 会告警 `UsesMinSdkAttributes`，因为 Gradle 在合并 manifest 时会自动注入 `defaultConfig.minSdk` 的值，手写一份只会引发冲突。

> 💡 **`package` 属性也不要写**：AGP 7+ 起，包名通过 `android.namespace = "com.example.mylibrary"` 在 build 文件里声明。

如果 SDK 需要权限或要注册组件（如 `ContentProvider`、`Receiver`），**才**在 manifest 里加；否则保持空。

---

## 四、模块级 `build.gradle.kts` 详解

下面是一个生产可用的 AAR 模块完整配置示例（以 `mylibrary` 模块为例）：

```kotlin
plugins {
    alias(libs.plugins.android.library)
    `maven-publish`
}

group = "com.example"
version = "1.0.0"

android {
    namespace = "com.example.mylibrary"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        minSdk = 30
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
            // withJavadocJar()
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "com.example"
            artifactId = "mylibrary"
            version = "1.0.0"
            afterEvaluate { from(components["release"]) }
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}
```

### 关键点逐项说明

| 配置 | 用途 | 说明 |
|---|---|---|
| `alias(libs.plugins.android.library)` | 应用 library 插件 | **不再 apply `kotlin-android`**：AGP 9.0+ 内置 Kotlin |
| `` `maven-publish` `` | Gradle 内置发布插件 | 不需要在 toml 里声明 |
| `group = "com.example"` | Maven groupId | 决定本地仓库目录结构 |
| `version = "1.0.0"` | Gradle 项目版本 | AAR 的"版本号"由它决定 |
| `namespace` | R 类与 BuildConfig 的包名 | 取代了老的 `manifest package` |
| `compileSdk { ... minorApiLevel = 1 }` | 编译 SDK 版本（带次要 API 级别） | AGP 9 新 DSL，对应 Android 16 QPR 等次要版本 |
| `consumerProguardFiles("consumer-rules.pro")` | 消费方混淆规则 | **library 用这个，不是 `proguardFiles`** |
| `publishing { singleVariant("release") { withSourcesJar() } }` | 在 `android {}` 内声明可发布的变体 | **必须先声明再 register publication** |
| `kotlin { compilerOptions { jvmTarget = ... } }` | Kotlin 编译参数 | 取代弃用的 `android.kotlinOptions {}` |

### Kotlin 插件演进（AGP 8.x vs 9.x）

**如果你使用的是 AGP 8.x 及以下版本：**
- 需要在 `plugins {}` 中声明 `alias(libs.plugins.kotlin.android)`
- 需要在 `libs.versions.toml` 中定义 `kotlin` 版本
- 编译参数通常写在 `android { kotlinOptions { jvmTarget = "17" } }`

**如果你使用的是 AGP 9.0+（内置 Kotlin）：**
- ✅ **不要 apply** `org.jetbrains.kotlin.android` 插件
- ✅ **不要在 `libs.versions.toml`** 里写 `kotlin = "..."` 版本（AGP 自带）
- ✅ `android.kotlinOptions {}` 已弃用 → 用顶层 `kotlin.compilerOptions {}`
- ❌ 同时保留旧插件会报错：`Cannot add extension with name 'kotlin'`

参考：[Migrate to built-in Kotlin](https://developer.android.com/build/migrate-to-built-in-kotlin)

---

## 五、根 `build.gradle.kts` 与 `libs.versions.toml`

### 根 `build.gradle.kts`

```kotlin
// Top-level build file
plugins {
    alias(libs.plugins.android.library) apply false
}
```

> ⚠️ 根 build 文件**只声明插件不 apply**（`apply false`）。模块插件只能在模块的 `build.gradle.kts` 里 apply。

### `gradle/libs.versions.toml`

```toml
[versions]
agp = "9.2.1"
coreKtx = "1.18.0"
junit = "4.13.2"
junitVersion = "1.3.0"
espressoCore = "3.7.0"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
junit = { group = "junit", name = "junit", version.ref = "junit" }
androidx-junit = { group = "androidx.test.ext", name = "junit", version.ref = "junitVersion" }
androidx-espresso-core = { group = "androidx.test.espresso", name = "espresso-core", version.ref = "espressoCore" }

[plugins]
android-library = { id = "com.android.library", version.ref = "agp" }
```

> 注意：如果你使用的是 AGP 9.0+，这里**不需要** `kotlin-android` 插件和 `kotlin` 版本号（已被 AGP 内置接管）。如果是 AGP 8.x，则需要自行补充 `kotlin-android` 插件声明。

---

## 六、资源目录清理

application 模板会生成一堆 SDK 用不上的资源，**必须删除**，否则会有冲突或冗余：

```text
app/src/main/res/
├── mipmap-anydpi/         ← 删（启动器图标）
├── mipmap-hdpi/           ← 删
├── mipmap-mdpi/           ← 删
├── mipmap-xhdpi/          ← 删
├── mipmap-xxhdpi/         ← 删
├── mipmap-xxxhdpi/        ← 删
├── drawable/              ← 删（启动器矢量背景）
├── values/
│   ├── colors.xml         ← 删
│   ├── strings.xml        ← 保留或按需保留
│   └── themes.xml         ← 删（依赖 Theme.MaterialComponents）
├── values-night/          ← 删
└── xml/                   ← 删（备份规则、数据提取规则，application 才用）
```

清理命令（在 `app/src/main/res/` 目录执行）：

```bash
rm -rf mipmap-anydpi mipmap-hdpi mipmap-mdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi
rm -rf drawable values-night xml
rm -f values/themes.xml values/colors.xml
```

> ⚠️ 如果不删 `themes.xml` 又同时移除了 `material` 依赖，编译会报：
> ```
> AAPT: error: resource attr/colorPrimary not found
> ```

清理之后，纯 SDK 通常只保留：
- `res/values/strings.xml`（如有需要）
- `res/drawable/`（SDK 自己的图标素材）
- 其他 SDK 实际使用的资源

---

## 七、版本号设置

AAR 没有 `versionCode` / `versionName`，**版本号 = Gradle 项目的 `version` 属性**：

```kotlin
// app/build.gradle.kts
group = "com.example"
version = "1.0.0"
```

升级版本：把 `version = "1.0.0"` 改为 `1.0.1`、`1.1.0` 等即可，再次发布会生成新坐标。

> 💡 **开发期推荐用 `-SNAPSHOT` 后缀**，比如 `version = "1.0.0-SNAPSHOT"`：Gradle 不会缓存 SNAPSHOT 版本，每次都会去仓库拉最新，避免"我改了 SDK 但消费方拿到的还是旧的"陷阱。

### Maven 坐标三要素

| 要素 | 配置 | 示例 |
|---|---|---|
| `groupId` | `group = "..."` | `com.example` |
| `artifactId` | publication 的 `artifactId` | `mylibrary` |
| `version` | `version = "..."` | `1.0.0` |

最终消费方写：`implementation("com.example:mylibrary:1.0.0")`

---

## 八、发布到本地 Maven 仓库

### 一行命令发布

```bash
./gradlew :app:publishToMavenLocal
```

### 产物位置

```
~/.m2/repository/com/example/mylibrary/1.0.0/
├── mylibrary-1.0.0.aar          ← 主产物（AAR）
├── mylibrary-1.0.0.pom          ← 依赖声明
├── mylibrary-1.0.0.module       ← Gradle 元数据
└── mylibrary-1.0.0-sources.jar  ← 源码
```

### AAR 内部结构

```
mylibrary-1.0.0.aar (zip 格式)
├── AndroidManifest.xml
├── classes.jar               ← 编译后的 .class 字节码
│   └── com/example/mylibrary/MyBinarySdk.class
├── res/                      ← SDK 自带的资源
├── R.txt                     ← R 类文本表
├── proguard.txt              ← 消费方混淆规则
└── META-INF/
    └── com/android/build/gradle/aar-metadata.properties
```

### 仅打包不发布

```bash
./gradlew :app:assembleRelease
```

产物位于 `app/build/outputs/aar/app-release.aar`。

---

## 九、在另一个工程中消费 AAR

### Step 1：消费方 `settings.gradle.kts` 加 `mavenLocal()`

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        mavenLocal()              // ← 关键
    }
}
```

> ⚠️ 必须放在 `dependencyResolutionManagement.repositories`，**不是** `pluginManagement.repositories`（那个是给插件用的）。

### Step 2：消费方模块加依赖

```kotlin
// 消费方 app/build.gradle.kts
dependencies {
    implementation("com.example:mylibrary:1.0.0")
}
```

### Step 3：在代码中使用

```kotlin
import com.example.mylibrary.MyBinarySdk

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val sdk = MyBinarySdk()
        Log.d("SDK", "info=${sdk.getSdkInfo()}, 1+2=${sdk.calculate(1, 2)}")
    }
}
```

### Step 4：验证 Gradle 解析路径

```bash
./gradlew :app:dependencyInsight \
  --dependency mylibrary \
  --configuration releaseRuntimeClasspath
```

输出包含 `From file:/Users/.../.m2/repository/com/example/mylibrary/...` 即说明 mavenLocal 工作正常。

### 进阶：`includeBuild` 实时联调

如果你需要"边改 SDK 边在消费方验证"，复合构建是最佳方案：

```kotlin
// 消费方 settings.gradle.kts
includeBuild("/Users/a/Desktop/AndroidModules/mylibrary") {
    dependencySubstitution {
        substitute(module("com.example:mylibrary"))
            .using(project(":app"))
    }
}
```

消费方依赖照常写 `implementation("com.example:mylibrary:1.0.0")`，但 Gradle 会**直接编译 SDK 源码**，跳过发布步骤，改一行立刻生效。

---

## 十、常见错误与排查

| 报错 | 根因 | 解决方案 |
|---|---|---|
| `Cannot add extension with name 'kotlin'` | 同时 apply 了 `kotlin-android` 与 AGP 9 内置 Kotlin | 移除 `kotlin-android` 插件、版本及 `kotlinOptions` |
| `applicationId is not allowed` 或类似 | library 模块写了 application 字段 | 删 `applicationId`、`versionCode`、`versionName` |
| `AAPT: error: attr/colorPrimary not found` | `themes.xml` 引用了 Material 父主题但没 `material` 依赖 | 删除 application 模板的 `themes.xml` 等资源 |
| `Could not find com.example:mylibrary:1.0.0` | 消费方没注册 `mavenLocal()` 或加错位置 | `settings.gradle.kts` 的 `dependencyResolutionManagement.repositories` 加 `mavenLocal()` |
| 改完 SDK 重发后消费方仍旧行为 | Gradle 缓存了旧 AAR | 升版本号；或加 `--refresh-dependencies`；或用 `-SNAPSHOT` 后缀 |
| `Build was configured to prefer settings repositories...` | 模块里又写了 `repositories {}` 与 `FAIL_ON_PROJECT_REPOS` 冲突 | 删模块里的 `repositories`，只在 settings 配 |
| `Unresolved reference: MyBinarySdk` | Sync 没生效 / 包路径错 | Build → Clean → Sync；检查 import 路径 |
| `UsesMinSdkAttributes` Lint 警告 | manifest 里写了 `<uses-sdk>` | 删除该行，由 `build.gradle.kts` 的 `minSdk` 自动注入 |

### 调试三件套

```bash
# 1. 看依赖树（确认 mylibrary 被解析）
./gradlew :app:dependencies --configuration releaseRuntimeClasspath

# 2. 强制刷新缓存
./gradlew :app:assembleRelease --refresh-dependencies

# 3. 打开 AAR 看里面到底打了什么
unzip -l app/build/outputs/aar/app-release.aar
```

---

## 十一、检查清单

发布一个干净的 AAR 前，对照检查：

### 工程结构
- [ ] `app/build.gradle.kts` 用的是 `com.android.library` 插件
- [ ] 根 `build.gradle.kts` 插件都加了 `apply false`
- [ ] **AGP 9+ 专属**：没有 apply `org.jetbrains.kotlin.android`，`libs.versions.toml` 也没有 `kotlin` 版本
- [ ] **AGP 8.x 专属**：已 apply `org.jetbrains.kotlin.android` 并指定了版本

### `defaultConfig`
- [ ] **没有** `applicationId`、`versionCode`、`versionName`、`targetSdk`
- [ ] 有 `minSdk`
- [ ] 用 `consumerProguardFiles` 而不是 `proguardFiles`

### Manifest 与资源
- [ ] manifest 里**没有** `<uses-sdk>`、`<application>`（除非 SDK 真的需要）
- [ ] `res/` 下没有应用图标、主题、备份规则等模板残留

### 版本与发布
- [ ] 顶层声明了 `group` 与 `version`
- [ ] `android.publishing.singleVariant("release")` 已声明
- [ ] `publications.register<MavenPublication>("release")` 已配置
- [ ] `from(components["release"])` 写在 `afterEvaluate {}` 内

### 验证
- [ ] `./gradlew :app:assembleRelease` 成功
- [ ] `./gradlew :app:publishToMavenLocal` 成功
- [ ] `~/.m2/repository/<groupId>/<artifactId>/<version>/` 下有 4 个文件
- [ ] 消费方能 `implementation("com.example:mylibrary:1.0.0")` 通过编译

---

## 附录：常用命令速查

```bash
# 仅构建 AAR（不发布）
./gradlew :app:assembleRelease
# 产物：app/build/outputs/aar/app-release.aar

# 发布到本地 Maven 仓库
./gradlew :app:publishToMavenLocal
# 产物：~/.m2/repository/<groupId>/<artifactId>/<version>/

# 清理构建缓存
./gradlew clean

# 查看 SDK 类是否正确打入
unzip -p app/build/outputs/aar/app-release.aar classes.jar > /tmp/classes.jar
unzip -l /tmp/classes.jar
```
