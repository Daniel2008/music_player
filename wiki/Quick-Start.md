# 快速入门

本指南将帮助您快速安装和运行 Music Player。

## 前置要求

### 系统要求
- **操作系统**：Windows 10/11、macOS 10.14+、Linux（Ubuntu 20.04+ 或其他主流发行版）
- **内存**：至少 4GB RAM
- **磁盘空间**：至少 500MB 可用空间

### 开发环境
- **Flutter SDK**：3.10.1 或更高版本
- **Dart SDK**：随 Flutter 自动安装
- **IDE**：推荐使用 VS Code、Android Studio 或 IntelliJ IDEA

## 安装 Flutter

### Windows
```powershell
# 1. 下载 Flutter SDK
# 访问 https://flutter.dev/docs/get-started/install/windows

# 2. 解压到目标目录（如 C:\flutter）

# 3. 添加到环境变量 PATH
# 系统属性 -> 环境变量 -> Path -> 添加 C:\flutter\bin

# 4. 验证安装
flutter doctor
```

### macOS
```bash
# 使用 Homebrew 安装
brew install flutter

# 或手动下载
# 访问 https://flutter.dev/docs/get-started/install/macos

# 验证安装
flutter doctor
```

### Linux
```bash
# 1. 下载 Flutter SDK
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.10.1-stable.tar.xz

# 2. 解压
tar xf flutter_linux_3.10.1-stable.tar.xz

# 3. 添加到 PATH
echo 'export PATH="$PATH:`pwd`/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# 4. 验证安装
flutter doctor
```

## 启用桌面支持

```bash
# 启用 Windows 桌面支持
flutter config --enable-windows-desktop

# 启用 macOS 桌面支持
flutter config --enable-macos-desktop

# 启用 Linux 桌面支持
flutter config --enable-linux-desktop

# 查看配置
flutter config
```

## 获取项目

### 从 Git 克隆
```bash
# 克隆仓库
git clone https://github.com/your-repo/music_player.git

# 进入项目目录
cd music_player
```

### 或下载源码包
直接从 GitHub Release 页面下载源码压缩包并解压。

## 安装依赖

```bash
# 获取 Flutter 依赖包
flutter pub get
```

## 运行应用

### 开发模式运行

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 查看可用设备
```bash
flutter devices
```

## 构建应用

### Windows
```bash
# 构建 Release 版本
flutter build windows --release

# 输出位置：build/windows/runner/Release/
```

### macOS
```bash
# 构建 Release 版本
flutter build macos --release

# 输出位置：build/macos/Build/Products/Release/
```

### Linux
```bash
# 构建 Release 版本
flutter build linux --release

# 输出位置：build/linux/x64/release/bundle/
```

## 首次使用

### 1. 添加本地音乐
- 点击底部控制区的"添加歌曲"按钮
- 选择本地音乐文件（支持多选）
- 支持的格式：MP3、FLAC、WAV、M4A、OGG

### 2. 播放控制
- **播放/暂停**：点击播放按钮或按 Ctrl+Alt+P
- **上一曲/下一曲**：点击对应按钮
- **进度跳转**：拖动进度条
- **音量调节**：拖动音量滑块

### 3. 在线搜索
- 切换到"搜索"标签页
- 输入歌曲名、歌手名或专辑名
- 选择音乐源（网易云、QQ 音乐等）
- 点击搜索结果中的歌曲播放

### 4. 查看歌词
- 播放支持歌词的歌曲时，歌词会自动显示
- 本地歌曲：将 .lrc 文件与音乐文件放在同一目录并同名
- 在线歌曲：自动获取在线歌词

### 5. 主题切换
- 点击左侧导航栏底部的主题切换按钮
- 切换深色/浅色模式

### 6. 自定义皮肤
- 进入"设置"页面
- 选择预设皮肤或加载自定义皮肤 JSON 文件

## 常见问题

### 无法播放音频
- 检查音频文件格式是否支持
- 确保音频文件没有损坏
- 检查系统音量设置

### 歌词不显示
- 确保 .lrc 文件与音乐文件同名
- 检查 .lrc 文件编码（推荐 UTF-8）
- 在线歌词需要网络连接

### 快捷键不生效
- 确保应用有权限注册全局快捷键
- Windows：以管理员身份运行
- macOS：在系统偏好设置中授予辅助功能权限
- Linux：检查桌面环境的快捷键冲突

### 构建失败
```bash
# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 再次构建
flutter build windows --release
```

## 下一步

- 查看 [用户手册](./User-Guide.md) 了解详细功能
- 阅读 [开发指南](./Development-Guide.md) 参与开发
- 查看 [API 文档](./API-Documentation.md) 了解技术细节

## 获取帮助

- [GitHub Issues](https://github.com/your-repo/music_player/issues)
- [讨论区](https://github.com/your-repo/music_player/discussions)
