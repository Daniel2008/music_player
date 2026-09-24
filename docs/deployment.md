# 音乐播放器 部署说明

## 环境

- Flutter SDK：项目 `pubspec.yaml` 要求 Flutter `>=3.41.0`、Dart SDK `^3.11.0`。
- 桌面平台：Windows 10/11、macOS 10.14+、Linux Ubuntu 20.04+ 或等效桌面环境。
- 推荐先启用 Flutter 桌面支持：

```bash
flutter config --enable-windows-desktop --enable-macos-desktop --enable-linux-desktop
```

## 准备步骤

```bash
pwd
git status --short --branch
flutter pub get
flutter analyze
flutter test
```

### Windows 本地构建

Windows 构建包含 `smtc_windows` 的 Rust Cargokit。本机可通过项目脚本检查 Rust、插件缓存并启动：

```powershell
.\scripts\run_windows.ps1 -CheckOnly
.\scripts\run_windows.ps1
```

若使用普通 `flutter run -d windows` 命令，须确保**同一个 PowerShell 会话**的 `PATH` 中包含 `rustup.exe` 所在目录。例如本机 Rust 安装在 `D:\worksoft\.cargo`：

```powershell
$env:PATH = "D:\worksoft\.cargo\bin;$env:PATH"
$env:CARGO_HOME = "D:\worksoft\.cargo"
where.exe rustup
flutter run -d windows
```

执行发布构建时也需使用同样的 Rust 环境。`build/native_assets/windows` 是可选目录，构建生成原生资产时会安装，没有该目录时不会阻断安装步骤。

## 本地运行

```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

## 发布构建

### Windows

```bash
flutter build windows --release
```

构建产物位于 `build/windows/x64/runner/Release/`。

### macOS

```bash
flutter build macos --release
```

构建产物位于 `build/macos/Build/Products/Release/`。

### Linux

```bash
flutter build linux --release
```

构建产物位于 `build/linux/x64/release/bundle/`。

## 发布前检查

- 应用可启动，窗口标题栏、导航和迷你播放器显示正常。
- 本地文件添加、播放、暂停、上一首、下一首、进度跳转、音量调节正常。
- 在线搜索、播放 URL 解析、歌词缓存和封面显示在可用网络下正常。
- 收藏、历史、播放列表持久化在重启后仍可用。
- 下载目录配置、下载进度、取消、重试正常。
- 明暗主题、皮肤切换、频谱/波形可视化正常。

## 注意事项

- 在线能力依赖用户在设置页配置的 API 地址和网络连通性。
- 不要把 API key、token、password、secret、Authorization、私钥等敏感信息写入仓库文档或提交记录。
- 构建目录、`.dart_tool`、IDE 缓存和运行日志不应作为发布源码提交。
