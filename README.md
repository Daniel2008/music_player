# 🎵 Music Player

<div align="center">

[![Flutter CI](https://github.com/Daniel2008/music_player/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Daniel2008/music_player/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.41.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Version](https://img.shields.io/badge/version-1.2.0%2B2-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey?style=for-the-badge)

一个基于 Flutter 的跨平台桌面音乐播放器，支持本地/在线音乐、同步歌词、播放列表、下载管理、主题皮肤、均衡器、Windows SMTC 与实时音频可视化。

[功能特性](#-功能特性) • [快速开始](#-快速开始) • [自动构建](#-github-actions-自动构建) • [项目结构](#-项目结构) • [开发文档](#-开发文档)

</div>

---

## 📸 预览

> 精美的 Material Design 3 界面，支持深色/浅色主题

<!-- 添加您的应用截图 -->
![主界面](./docs/main.png)

## ✨ 功能特性

### 🎧 播放功能
- **本地音乐播放** - 支持 MP3、WAV、AAC、FLAC、OGG、WMA、M4A、OPUS
- **多音乐源** - 通过可配置的 GD 音乐台 API 访问多个在线音乐源
- **稳定音乐源** - 默认展示网易云、酷我、JOOX、Bilibili
- **扩展音乐源** - 设置页可启用 QQ 音乐、酷狗、咪咕、Tidal、Spotify、YouTube Music、Qobuz、Deezer、喜马拉雅、Apple Music 等
- **高品质音频** - 使用 SoLoud 引擎，支持 128kbps、192kbps、320kbps、740kbps、999kbps 五档音质
- **播放控制** - 播放/暂停、停止、上一曲/下一曲、进度跳转、音量调节
- **播放模式** - 顺序播放、列表循环、随机播放、单曲循环
- **播放列表** - 文件/文件夹添加、拖拽排序、M3U/M3U8 导入和 M3U 导出

### 📝 歌词系统
- **本地歌词** - 自动识别同名 .lrc 文件
- **在线歌词** - 智能搜索和匹配在线歌词
- **同步显示** - 实时歌词滚动和高亮
- **双语支持** - 支持原文和翻译歌词

### 🎨 界面与主题
- **Material Design 3** - 遵循最新设计规范
- **深色/浅色模式** - 支持主题切换
- **自定义皮肤** - 通过 JSON 配置自定义主题颜色
- **响应式设计** - 适配不同屏幕尺寸

### 📊 音频可视化
- **12 种样式** - 柱状、镜像柱状、曲线、点阵、圆形、波浪、粒子、火焰、雷达、环形、渐变柱、3D 频谱
- **全屏模式** - 支持沉浸式全屏可视化
- **均衡器** - 8 段均衡器，频率覆盖 64Hz 至 8kHz

### ⌨️ 快捷键支持
- **全局快捷键** - 系统级媒体控制
- **Ctrl+Alt+P** - 播放/暂停
- **Alt+左/右** - 快进/快退 5 秒

### ❤️ 收藏与历史
- **收藏管理** - 收藏喜欢的歌曲
- **播放历史** - 自动记录播放历史
- **快速访问** - 快速访问收藏和历史记录

### 📥 下载功能
- **在线下载** - 下载在线音乐到本地
- **多音质选择** - 支持 128kbps、192kbps、320kbps、740kbps 无损、999kbps Hi-Res
- **下载管理** - 查看下载进度和状态，支持取消和失败重试
- **并发控制** - 默认最多 3 个并发下载任务

## 🚀 快速开始

### 前置要求

- **Flutter SDK** 3.41.0 或更高版本（Dart 3.11+）
- **操作系统**: Windows 10/11、macOS 10.14+、Linux (Ubuntu 20.04+)
- **Windows 开发构建**: 需要 Rust/Cargo，因为 `smtc_windows` 使用 Cargokit

### 安装步骤

1. **克隆仓库**

```bash
git clone https://github.com/Daniel2008/music_player.git
cd music_player
```

2. **安装依赖**

```bash
flutter pub get
```

3. **启用桌面支持**

```bash
# Windows
flutter config --enable-windows-desktop

# macOS
flutter config --enable-macos-desktop

# Linux
flutter config --enable-linux-desktop
```

4. **运行应用**

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

Windows 环境可使用项目脚本先检查 Rust 和插件缓存，再启动应用：

```powershell
.\scripts\run_windows.ps1 -CheckOnly
.\scripts\run_windows.ps1
```

### 构建 Release 版本

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## ✅ GitHub Actions 自动构建

项目已配置 [Flutter CI](./.github/workflows/ci.yml)：

- 推送到任意分支时自动运行，也支持在 Actions 页面手动触发
- Ubuntu runner 执行 `flutter pub get`、`flutter analyze` 和全量测试
- 分析和测试通过后，Windows runner 执行 `flutter build windows --release`
- Windows 构建产物自动上传到对应 Actions 运行页面，保留 14 天
- Pull Request 到 `main` 时执行相同检查

查看构建状态和下载产物：

- [GitHub Actions](https://github.com/Daniel2008/music_player/actions)
- [Windows CI 工作流](https://github.com/Daniel2008/music_player/actions/workflows/ci.yml)

## 📖 使用说明

### 添加本地音乐

1. 从播放页或底部播放器打开播放列表面板
2. 选择"添加文件"或"添加文件夹"
3. 从列表中选择歌曲开始播放

### 搜索在线音乐

1. 切换到"搜索"标签页
2. 输入歌曲名、歌手名或专辑名
3. 选择音乐源（网易云、QQ 音乐等）
4. 点击搜索结果播放

### 歌词显示

- **本地歌曲**: 将 `.lrc` 文件与音乐文件放在同一目录并同名
- **在线歌曲**: 自动获取在线歌词
- **自动搜索**: 在设置中启用"自动为本地歌曲搜索在线歌词"

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Alt+P` | 播放/暂停 |
| `Alt+→` | 快进 5 秒 |
| `Alt+←` | 快退 5 秒 |

> 全局快捷键可能受系统权限或桌面环境限制，注册失败不会阻止应用启动。

## 🏗️ 项目结构

```text
music_player/
├── .github/workflows/      # GitHub Actions 自动构建
├── assets/
│   ├── branding/           # 品牌图标源文件
│   ├── lyrics/             # 示例歌词
│   └── skins/              # JSON 主题皮肤
├── docs/                   # 架构、部署和使用文档
├── lib/
│   ├── audio/              # 音频辅助与转码
│   ├── models/             # 数据模型
│   ├── platform/           # 平台能力与全局快捷键
│   ├── providers/          # 状态管理与业务状态
│   ├── services/           # API、存储、歌词、连接与 SMTC
│   ├── ui/
│   │   ├── pages/          # 页面
│   │   └── widgets/        # 通用组件与可视化
│   ├── utils/              # 工具类
│   ├── app.dart            # Provider 初始化和应用根节点
│   └── main.dart           # 程序入口与桌面窗口初始化
├── scripts/                # 开发辅助脚本
├── test/                   # Flutter 测试
├── tool/                   # 图标生成工具
├── wiki/                   # 项目 Wiki
├── macos/                  # macOS 平台工程
├── windows/                # Windows 平台工程
└── linux/                  # Linux 平台工程
```

## 🛠️ 技术栈

### 核心框架
- **Flutter 3.41.0+** - 跨平台 UI 框架
- **Dart 3.11+** - 编程语言

### 主要依赖
- **provider** - 状态管理
- **flutter_soloud** - 音频播放、FFT/波形和均衡器
- **file_picker** - 文件、文件夹和 M3U 选择
- **shared_preferences** - 轻量设置持久化
- **path_provider** - 应用数据与下载目录
- **hotkey_manager** - 全局快捷键
- **window_manager** - 桌面窗口控制
- **smtc_windows** - Windows 系统媒体控制
- **cached_network_image** / **flutter_cache_manager** - 封面缓存
- **google_fonts** - 字体支持
- **url_launcher** - 打开外部链接

查看完整依赖列表: [pubspec.yaml](./pubspec.yaml)

## 📚 开发文档

详细的开发文档请访问 [Wiki](./wiki/Home.md):

- [项目简介](./wiki/Project-Overview.md) - 了解项目背景和主要功能
- [快速入门](./wiki/Quick-Start.md) - 快速安装和运行指南
- [用户手册](./wiki/User-Guide.md) - 详细的功能使用说明
- [架构设计](./wiki/Architecture.md) - 系统架构和技术选型
- [开发指南](./wiki/Development-Guide.md) - 开发环境配置和开发流程
- [API 文档](./wiki/API-Documentation.md) - 核心 API 和接口说明
- [构建部署](./wiki/Build-Deploy.md) - 跨平台打包和发布

## 🤝 贡献指南

我们欢迎任何形式的贡献！

### 如何贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 指南
- 使用 `dart format` 格式化代码
- 运行 `flutter analyze` 检查代码
- 为新功能添加测试

更完整的开发流程见 [开发指南](./wiki/Development-Guide.md)。

## 🧪 测试

```bash
# 运行所有测试
flutter test

# 运行特定测试
flutter test test/lrc_parser_test.dart

# 代码分析
flutter analyze
```

## 📋 待办事项

- [ ] 支持更多音频格式（APE、DSD）
- [ ] 添加迷你模式窗口
- [ ] 支持歌词编辑
- [ ] 支持播客和电台
- [ ] 云同步功能
- [ ] 桌面歌词显示
- [ ] 多语言支持
- [ ] 增加 macOS/Linux CI 构建产物和代码签名

## 🐛 问题反馈

如果您遇到任何问题或有功能建议，请：

1. 查看 [常见问题](./wiki/User-Guide.md#常见问题)
2. 搜索 [已有 Issues](https://github.com/Daniel2008/music_player/issues)
3. 创建新的 [Issue](https://github.com/Daniel2008/music_player/issues/new)

## 📄 许可证

仓库当前未包含独立的 `LICENSE` 文件，许可证信息待维护者补充。

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 优秀的跨平台框架
- [SoLoud](https://sol.gfxile.net/soloud/) - 强大的音频引擎
- [GD 音乐台 API](https://music-api.gdstudio.xyz/) - 在线音乐 API 服务
- 所有贡献者和支持者

## 📞 联系方式

- **问题反馈**: [GitHub Issues](https://github.com/Daniel2008/music_player/issues)
- **邮箱**: jinda7632@163.com

---

<div align="center">

**如果这个项目对您有帮助，请给一个 ⭐ Star！**

Made with Flutter by [Daniel2008](https://github.com/Daniel2008)

</div>
