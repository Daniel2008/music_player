# 开发指南

本指南帮助开发者快速上手 Music Player 项目的开发。

## 目录

- [开发环境配置](#开发环境配置)
- [项目结构](#项目结构)
- [开发流程](#开发流程)
- [代码规范](#代码规范)
- [调试技巧](#调试技巧)
- [常见开发任务](#常见开发任务)

## 开发环境配置

### 必需工具

1. **Flutter SDK**
   - 版本：3.10.1 或更高
   - 安装方法：参见 [快速入门](./Quick-Start.md)

2. **IDE**（选择其一）
   - **VS Code**（推荐）
     - 插件：Flutter、Dart
   - **Android Studio**
     - 插件：Flutter、Dart
   - **IntelliJ IDEA**
     - 插件：Flutter、Dart

3. **Git**
   - 用于版本控制

### VS Code 配置

#### 推荐插件

```json
{
  "recommendations": [
    "dart-code.flutter",
    "dart-code.dart-code",
    "alexisvt.flutter-snippets",
    "nash.awesome-flutter-snippets"
  ]
}
```

#### 调试配置（.vscode/launch.json）

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Windows)",
      "request": "launch",
      "type": "dart",
      "deviceId": "windows"
    },
    {
      "name": "Flutter (macOS)",
      "request": "launch",
      "type": "dart",
      "deviceId": "macos"
    },
    {
      "name": "Flutter (Linux)",
      "request": "launch",
      "type": "dart",
      "deviceId": "linux"
    },
    {
      "name": "Flutter (Profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile"
    }
  ]
}
```

### 克隆项目

```bash
# 克隆仓库
git clone https://github.com/your-repo/music_player.git

# 进入项目目录
cd music_player

# 安装依赖
flutter pub get
```

### 验证环境

```bash
# 检查 Flutter 环境
flutter doctor

# 列出可用设备
flutter devices

# 运行测试
flutter test
```

## 项目结构

```
music_player/
├── lib/                      # 主要源代码
│   ├── audio/               # 音频相关
│   │   ├── equalizer.dart   # 均衡器（已移除）
│   │   └── ffmpeg_transcoder.dart  # FFmpeg 转码器（已移除）
│   ├── models/              # 数据模型
│   │   ├── playlist.dart    # 播放列表模型
│   │   └── track.dart       # 曲目模型
│   ├── platform/            # 平台相关
│   │   └── hotkeys.dart     # 快捷键管理
│   ├── providers/           # 状态管理（Provider）
│   │   ├── api_settings_provider.dart
│   │   ├── download_provider.dart
│   │   ├── favorites_provider.dart
│   │   ├── history_provider.dart
│   │   ├── player_provider.dart
│   │   ├── playlist_provider.dart
│   │   ├── search_provider.dart
│   │   └── theme_provider.dart
│   ├── services/            # 服务层
│   │   ├── favorites_service.dart
│   │   └── gd_music_api.dart
│   ├── ui/                  # 用户界面
│   │   ├── pages/           # 页面
│   │   │   ├── favorites_page.dart
│   │   │   ├── home_page.dart
│   │   │   ├── main_layout.dart
│   │   │   ├── player_page.dart
│   │   │   ├── search_page.dart
│   │   │   ├── settings_page.dart
│   │   │   └── visualizer_fullscreen_page.dart
│   │   └── widgets/         # 组件
│   │       ├── controls.dart
│   │       ├── equalizer_panel.dart
│   │       ├── hotkey_binder.dart
│   │       ├── lyric_view.dart
│   │       ├── mini_player.dart
│   │       ├── playlist_panel.dart
│   │       ├── playlist_view.dart
│   │       ├── theme_skin_bar.dart
│   │       └── visualizer_view.dart
│   ├── utils/               # 工具类
│   │   └── lrc_parser.dart  # 歌词解析器
│   ├── app.dart             # 应用根组件
│   └── main.dart            # 入口文件
├── assets/                  # 资源文件
│   ├── lyrics/              # 示例歌词
│   └── skins/               # 皮肤配置
├── docs/                    # 文档
├── test/                    # 测试文件
├── wiki/                    # Wiki 文档
├── windows/                 # Windows 平台代码
├── macos/                   # macOS 平台代码
├── linux/                   # Linux 平台代码
├── web/                     # Web 平台代码
├── pubspec.yaml            # 依赖配置
├── analysis_options.yaml   # 分析选项
└── README.md               # 项目说明
```

## 开发流程

### 1. 创建新分支

```bash
# 从 main 分支创建功能分支
git checkout -b feature/your-feature-name

# 或修复 bug 分支
git checkout -b fix/bug-description
```

### 2. 开发功能

遵循 [代码规范](#代码规范) 编写代码。

### 3. 运行和测试

```bash
# 运行应用（开发模式）
flutter run -d windows

# 运行测试
flutter test

# 分析代码
flutter analyze
```

### 4. 提交代码

```bash
# 查看改动
git status
git diff

# 添加文件
git add .

# 提交（使用有意义的提交信息）
git commit -m "feat: add new feature"
```

提交信息格式：
- `feat:` 新功能
- `fix:` 修复 bug
- `docs:` 文档更新
- `style:` 代码格式调整
- `refactor:` 重构
- `test:` 测试相关
- `chore:` 构建/工具相关

### 5. 推送和创建 PR

```bash
# 推送到远程分支
git push origin feature/your-feature-name
```

在 GitHub 上创建 Pull Request。

## 代码规范

### Dart 代码风格

遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 指南。

#### 命名规范

```dart
// 类名：大驼峰（PascalCase）
class PlayerProvider extends ChangeNotifier {}

// 变量、函数：小驼峰（camelCase）
String currentTrackTitle = '';
void playTrack(Track track) {}

// 常量：小驼峰
const Duration defaultTimeout = Duration(seconds: 12);

// 私有成员：下划线开头
String _privateField;
void _privateMethod() {}

// 文件名：蛇形命名（snake_case）
// player_provider.dart
// gd_music_api.dart
```

#### 格式化

```bash
# 格式化单个文件
dart format lib/main.dart

# 格式化整个项目
dart format .
```

#### 导入顺序

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:io';

// 2. Flutter SDK
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. 第三方包
import 'package:provider/provider.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

// 4. 项目内部
import '../models/track.dart';
import '../services/gd_music_api.dart';
```

### Widget 最佳实践

#### 使用 const 构造函数

```dart
// 好
const SizedBox(height: 16)
const Text('Hello')

// 避免（如果可以是 const）
SizedBox(height: 16)
Text('Hello')
```

#### 提取复用的 Widget

```dart
// 不好 - 重复代码
Widget build(BuildContext context) {
  return Column(
    children: [
      Container(
        padding: EdgeInsets.all(16),
        child: Text('Item 1'),
      ),
      Container(
        padding: EdgeInsets.all(16),
        child: Text('Item 2'),
      ),
    ],
  );
}

// 好 - 提取为独立 Widget
Widget build(BuildContext context) {
  return Column(
    children: [
      _ItemWidget(text: 'Item 1'),
      _ItemWidget(text: 'Item 2'),
    ],
  );
}

class _ItemWidget extends StatelessWidget {
  final String text;
  const _ItemWidget({required this.text});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text(text),
    );
  }
}
```

#### 优先使用 StatelessWidget

```dart
// 如果不需要状态，使用 StatelessWidget
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Text('Hello');
  }
}
```

### Provider 使用规范

#### 创建 Provider

```dart
class MyProvider extends ChangeNotifier {
  // 私有状态
  String _value = '';
  
  // 公开 getter
  String get value => _value;
  
  // 更新方法
  void updateValue(String newValue) {
    _value = newValue;
    notifyListeners();  // 通知监听者
  }
  
  // 异步操作
  Future<void> fetchData() async {
    try {
      // 加载数据
      final data = await someApi.getData();
      _value = data;
      notifyListeners();
    } catch (e) {
      // 错误处理
    }
  }
  
  @override
  void dispose() {
    // 清理资源
    super.dispose();
  }
}
```

#### 使用 Provider

```dart
// 读取数据
final value = context.watch<MyProvider>().value;

// 调用方法（不重建）
context.read<MyProvider>().updateValue('new');

// 选择性监听
final value = context.select<MyProvider, String>((p) => p.value);
```

### 错误处理

```dart
// 异步操作的错误处理
Future<void> loadData() async {
  try {
    final data = await api.getData();
    // 处理数据
  } on TimeoutException {
    // 超时处理
  } on HttpException {
    // 网络错误
  } catch (e) {
    // 其他错误
    debugPrint('Error: $e');
  }
}

// 用户友好的错误提示
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
```

## 调试技巧

### 使用 debugPrint

```dart
// 开发时的日志输出
debugPrint('Current track: ${track.title}');
debugPrint('Position: ${position.inSeconds}s');
```

### Flutter DevTools

```bash
# 启动 DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

功能：
- **Inspector**: 查看 Widget 树
- **Performance**: 性能分析
- **Memory**: 内存分析
- **Network**: 网络请求监控

### 断点调试

在 VS Code 中：
1. 设置断点（点击行号左侧）
2. 按 F5 启动调试
3. 当代码执行到断点时暂停
4. 查看变量值、调用栈

### 性能分析

```bash
# Profile 模式运行
flutter run --profile

# 生成性能报告
flutter run --profile --trace-skia
```

### 热重载

开发时利用热重载快速看到改动：
- `r` - 热重载（Hot Reload）
- `R` - 热重启（Hot Restart）
- `q` - 退出

## 常见开发任务

### 添加新的页面

1. 在 `lib/ui/pages/` 创建新页面文件

```dart
// lib/ui/pages/my_new_page.dart
import 'package:flutter/material.dart';

class MyNewPage extends StatelessWidget {
  const MyNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My New Page')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

2. 在 `main_layout.dart` 中添加导航

### 添加新的 Provider

1. 创建 Provider 文件

```dart
// lib/providers/my_provider.dart
import 'package:flutter/foundation.dart';

class MyProvider extends ChangeNotifier {
  // 状态和方法
}
```

2. 在 `app.dart` 中注册

```dart
MultiProvider(
  providers: [
    // 现有 Providers
    ChangeNotifierProvider(create: (_) => MyProvider()),
  ],
  // ...
)
```

### 添加新的依赖

1. 在 `pubspec.yaml` 中添加

```yaml
dependencies:
  new_package: ^1.0.0
```

2. 获取依赖

```bash
flutter pub get
```

3. 导入使用

```dart
import 'package:new_package/new_package.dart';
```

### 添加新的音乐源

1. 修改 `GdMusicApiClient` 或创建新的 API 客户端
2. 更新 `SearchProvider` 支持新源
3. 在 UI 中添加选项

### 添加新的测试

```dart
// test/my_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track.dart';

void main() {
  group('Track', () {
    test('should create track with title', () {
      final track = Track(title: 'Test', path: '/path');
      expect(track.title, 'Test');
    });
  });
}
```

运行测试：
```bash
flutter test test/my_test.dart
```

## 持续集成

### GitHub Actions

项目可以配置 GitHub Actions 自动化：

```yaml
# .github/workflows/flutter.yml
name: Flutter CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.1'
    
    - run: flutter pub get
    - run: flutter analyze
    - run: flutter test
```

## 发布流程

详见 [构建部署](./Build-Deploy.md)。

## 参考资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Dart 语言指南](https://dart.dev/guides)
- [Provider 文档](https://pub.dev/packages/provider)
- [Material Design 3](https://m3.material.io/)

## 相关文档

- [架构设计](./Architecture.md)
- [API 文档](./API-Documentation.md)
- [贡献指南](./Contributing.md)
