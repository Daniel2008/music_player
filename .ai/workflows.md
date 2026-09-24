# 音乐播放器 常用工作流

## 环境确认

```bash
pwd
git status --short --branch
flutter --version
flutter doctor -v
```

## 依赖安装

```bash
flutter pub get
```

## 本地运行

Windows 优先使用 `.\scripts\run_windows.ps1 -CheckOnly` 检查前置条件，之后执行 `.\scripts\run_windows.ps1`。若手工执行 Flutter 且使用本机 `D:\worksoft` Rust 工具链，先在同一 PowerShell 会话执行：

```powershell
$env:PATH = "D:\worksoft\.cargo\bin;$env:PATH"
$env:CARGO_HOME = "D:\worksoft\.cargo"
```

```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

## 测试与静态检查

```bash
flutter analyze
flutter test
flutter test test/lrc_parser_test.dart
flutter test test/gd_music_api_test.dart
flutter test test/playlist_provider_test.dart
flutter test test/track_test.dart
```

## 构建

```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## 开发约定

- 修改前先确认工作区为 `F:\ai\music_player`。
- 不读取或输出 API key、token、password、secret、Authorization、私钥等敏感信息。
- 优先修改 `lib/`、`test/`、`docs/`、`.ai/` 下的一方文件；不要手工编辑构建产物。
- 代码变更后优先运行 `dart format`、`flutter analyze`、相关 `flutter test`。
