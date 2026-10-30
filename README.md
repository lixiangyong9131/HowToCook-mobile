# HowToCook-mobile · 程序员做饭指南（Flutter）

离线可浏览的「程序员做饭指南」移动端，菜谱来自上游开源项目 **[Anduin2017/HowToCook](https://github.com/Anduin2017/HowToCook)**（[Unlicense](https://unlicense.org) / 公共领域）。感谢原作者 Anduin2017 与所有贡献者。

本仓库将菜谱 Markdown 打包进 App（`assets/recipes_db.json`），**不依赖**仅在线访问 https://howtocook.aiursoft.com 也能阅读全文。

## 功能

交互参考微信小程序 [LeeJim/HowToCookOnMiniprogram](https://github.com/LeeJim/HowToCookOnMiniprogram)。**v0.6.3** Wallet 单卡聚焦虚化 / 展开流畅 / 最近浏览做法大图 / 视频自动播 / 计时按钮主题：

- **视频做法**：详情页入口，底部弹层展示 B 站搜索结果（封面/标题/UP/时长/播放量），一键「在 B 站打开」（优先 [eat.ryanuo.cc](https://eat.ryanuo.cc/) `/api/video-search`，失败回落官方搜索 API，再不行打开搜索页）
- **整图做法**：有图时默认以 [king-jingxiang/HowToCook](https://github.com/king-jingxiang/HowToCook) 的 9:16 信息图替换步骤时间轴（`InteractiveViewer` 缩放）；按需从 GitHub Pages 下载并磁盘缓存，不打进 APK；原料仍保留（用量与原料同行合并）
- **桌面图标**：厨师帽 + 终端 `>_` mascot，奶油底 `#FFF6EB`（自适应图标约 55–60%）
- **分类 / 原料图标**：Food Doodle 涂鸦；原料关键词→图标已校对（牛奶/面粉/黄油/胡椒等）
- **Logo / 主题**：深蓝 `#1A1F3A`、奶油底 `#FFF6EB`、珊瑚强调 `#FF8A65`、霓虹绿 `#39FF5A`（无紫色）
- **首页**：搜索框（珊瑚）→ 历史芯片紧贴搜索框 → Wallet 分类叠卡（仅中间一张清晰，离焦虚化仍可读名；上滑选定打开）→ 最近浏览（最多 20）
- **动效**：分类 Wallet 叠卡（AnimatedPositioned / RepaintBoundary 展开）、步骤磁吸后绘时间轴、时:分惯性滚轮、底栏圆形揭示
- **底栏**：浅色奶油底（非黑/海军实心），选中珊瑚/海军
- **应用内更新**（Android）：「我的 → 检查更新」拉取 GitHub Releases APK
- 收藏、离线 JSON 菜谱、搜索结果页均保留

## 本地运行（Flutter）

### 环境

- [Flutter](https://docs.flutter.dev/get-started/install) stable（建议 3.24+）
- Android：OpenJDK 17 + Android SDK
- iOS：仅 macOS + Xcode

```bash
git clone https://github.com/lixiangyong9131/HowToCook-mobile.git
cd HowToCook-mobile
flutter pub get
flutter run
```

指定设备：

```bash
flutter devices
flutter run -d <deviceId>
```

仅分析 / 测试：

```bash
flutter analyze
flutter test
```

### 本地打 Android APK

```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

默认使用 Flutter debug/开发用签名即可试用。正式上架请自行配置 release keystore（见下方）。

### iOS 本地运行说明

1. 在 macOS 安装 Xcode 与 CocoaPods
2. `cd ios && pod install && cd ..`
3. `flutter run` 或用 Xcode 打开 `ios/Runner.xcworkspace`
4. 真机需配置签名 Team；模拟器可直接运行

## GitHub Actions 构建 APK

工作流： [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml)

触发方式：

1. **手动**：Actions →「Build Release APK」→ Run workflow
2. **打标签**：推送 `v*` 标签（例如 `v0.1.0`）会构建并将 APK 挂到 GitHub Release

产物：

- Actions Artifact：`HowToCook-apk` / `app-release.apk`
- 标签触发时：对应 Release 附件

## 如何安装 APK（未知来源）

1. 从本仓库 **Releases** 或 Actions Artifact 下载 `app-release.apk`
2. 传到 Android 手机
3. 打开系统设置 → 安全 / 应用 → 允许「安装未知应用」（不同品牌路径略有差异）
4. 用文件管理器打开 APK 安装

> 当前 Release 使用 Flutter 默认签名，仅供试用，不是商店正式签名。

## 可选：自备 Release Keystore

正式分发时建议：

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

在 `android/key.properties`（**不要提交到 Git**）中配置路径与密码，并在 `android/app/build.gradle.kts` 中引用。可将 keystore 与密码存为 GitHub Actions Secrets，在 workflow 中解码后签名。

## 菜谱数据更新

上游：https://github.com/Anduin2017/HowToCook

将 `dishes/` 下 Markdown 重新生成 `assets/recipes_db.json` 后提交即可。许可副本见 `assets/HOWTOCOOK_LICENSE`。

## 致谢与许可

- 菜谱内容：**Anduin2017/HowToCook**，Unlicense（公共领域）
- 本移动端壳工程代码：可按仓库后续声明使用；默认随仓库公开

网页版：https://howtocook.aiursoft.com
