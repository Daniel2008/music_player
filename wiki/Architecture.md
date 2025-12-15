# 架构设计

本文档详细介绍 Music Player 的系统架构、技术选型和设计决策。

## 整体架构

Music Player 采用经典的分层架构，结合 Flutter 的响应式编程范式。

```
┌─────────────────────────────────────────────┐
│              UI Layer (界面层)                │
│  ┌──────────┬──────────┬──────────────────┐ │
│  │  Pages   │ Widgets  │  Platform UI     │ │
│  └──────────┴──────────┴──────────────────┘ │
└─────────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────────┐
│         State Management (状态管理层)         │
│  ┌──────────────────────────────────────┐   │
│  │        Provider (Notifier)           │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────────┐
│          Business Logic (业务逻辑层)          │
│  ┌──────────┬──────────┬──────────────────┐ │
│  │ Services │  Models  │     Utils        │ │
│  └──────────┴──────────┴──────────────────┘ │
└─────────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────────┐
│         Platform Layer (平台层)               │
│  ┌──────────┬──────────┬──────────────────┐ │
│  │  Audio   │  File    │    System        │ │
│  │  Engine  │  System  │    APIs          │ │
│  └──────────┴──────────┴──────────────────┘ │
└─────────────────────────────────────────────┘
```

## 核心模块

### 1. UI Layer（界面层）

负责用户界面的展示和交互。

#### Pages（页面）
- `MainLayout` - 主布局，包含导航和页面容器
- `PlayerPage` - 播放器主页面
- `SearchPage` - 搜索页面
- `FavoritesPage` - 收藏页面
- `SettingsPage` - 设置页面
- `VisualizerFullscreenPage` - 全屏可视化页面

#### Widgets（组件）
- `MiniPlayer` - 迷你播放器控制栏
- `Controls` - 播放控制组件
- `PlaylistPanel` - 播放列表面板
- `LyricView` - 歌词显示组件
- `VisualizerView` - 可视化组件
- `EqualizerPanel` - 均衡器面板（已移除）
- `HotkeyBinder` - 快捷键绑定组件

### 2. State Management（状态管理层）

使用 Provider 模式进行状态管理。

#### Provider 列表

| Provider | 职责 | 主要状态 |
|----------|------|---------|
| `PlayerProvider` | 播放器核心控制 | 播放状态、进度、音量、FFT 数据 |
| `PlaylistProvider` | 播放列表管理 | 播放列表、当前曲目、播放模式 |
| `SearchProvider` | 搜索功能 | 搜索结果、搜索状态 |
| `ThemeProvider` | 主题管理 | 主题模式、皮肤配置 |
| `FavoritesProvider` | 收藏管理 | 收藏列表 |
| `HistoryProvider` | 历史记录 | 播放历史 |
| `DownloadProvider` | 下载管理 | 下载队列、下载进度 |
| `ApiSettingsProvider` | API 配置 | API 地址、超时、音质设置 |

#### 状态流转示例

```dart
User Action → Widget → Provider.method()
                           ↓
                    State Update
                           ↓
                  notifyListeners()
                           ↓
               Consumer/Selector rebuild
                           ↓
                    UI Update
```

### 3. Business Logic（业务逻辑层）

#### Models（数据模型）

**Track（曲目）**
```dart
class Track {
  final String id;           // 唯一标识
  final String title;        // 标题
  final String path;         // 本地路径或 URL
  final String? artist;      // 艺术家
  final String? artUri;      // 封面 URI
  final Duration? duration;  // 时长
  final TrackKind kind;      // local/remote
  // 远程曲目专用字段
  final String? remoteSource;
  final String? remoteTrackId;
  final String? remoteLyricId;
  final String? lyricKey;
}
```

**Playlist（播放列表）**
```dart
class Playlist {
  final String name;         // 列表名称
  final List<Track> tracks;  // 曲目列表
  int currentIndex;          // 当前索引
}
```

#### Services（服务）

**GdMusicApiClient（音乐 API 客户端）**
- 职责：与 GD 音乐台 API 交互
- 功能：
  - 搜索歌曲
  - 获取播放 URL
  - 获取歌词
  - 获取封面图片
- 支持的音乐源：
  - 网易云音乐（netease）
  - QQ 音乐（tencent）
  - 酷狗音乐（kugou）
  - 酷我音乐（kuwo）

**FavoritesService（收藏服务）**
- 职责：管理收藏数据的持久化
- 使用 SharedPreferences 存储

#### Utils（工具类）

**LrcParser（歌词解析器）**
```dart
class LrcParser {
  static List<LrcLine> parse(String content);
}

class LrcLine {
  final Duration time;
  final String text;
}
```

### 4. Platform Layer（平台层）

#### Audio Engine（音频引擎）

使用 **flutter_soloud** 作为音频播放引擎。

**特性**：
- 低延迟播放
- 支持多种音频格式
- 实时 FFT 数据获取
- 音量和播放控制

**核心操作**：
```dart
// 初始化
await _soloud.init();

// 加载音频
AudioSource source = await _soloud.loadFile(path);

// 播放
SoundHandle handle = await _soloud.play(source);

// 控制
_soloud.setPause(handle, true/false);
_soloud.seek(handle, duration);
_soloud.setVolume(handle, volume);

// FFT 数据
_audioData.updateSamples();
Float32List samples = _audioData.getAudioData();
```

#### File System（文件系统）

使用 **file_picker** 和 **path_provider**。

- `file_picker`: 选择本地音乐文件
- `path_provider`: 获取系统目录（缓存、应用支持目录）

#### System APIs（系统 API）

**Window Manager**
- `window_manager`: 窗口管理（最小化、最大化、关闭）
- 自定义标题栏

**Hotkey Manager**
- `hotkey_manager`: 全局快捷键注册
- 系统级媒体控制

## 数据流

### 本地音乐播放流程

```
1. User 选择文件 (file_picker)
       ↓
2. PlaylistProvider 添加 Track
       ↓
3. User 点击播放
       ↓
4. PlayerProvider.playTrack(track)
       ↓
5. SoLoud 加载并播放文件
       ↓
6. 定时器更新播放进度
       ↓
7. UI 通过 Consumer 监听更新
```

### 在线音乐播放流程

```
1. User 在 SearchPage 输入关键词
       ↓
2. SearchProvider 调用 GdMusicApiClient.search()
       ↓
3. 显示搜索结果
       ↓
4. User 点击播放
       ↓
5. PlayerProvider.resolveAndPlayTrackUrl()
       ↓
6. GdMusicApiClient.getTrackUrl() 获取播放链接
       ↓
7. 创建 Track 并播放
       ↓
8. 异步获取歌词并缓存
```

### 歌词显示流程

```
┌─ 本地歌词 ─┐         ┌─ 在线歌词 ─┐
│            │         │            │
│ 检查同名   │         │ 调用 API   │
│ .lrc 文件  │         │ 获取歌词   │
│            │         │            │
└─────┬──────┘         └──────┬─────┘
      │                       │
      └───────────┬───────────┘
                  ↓
          LrcParser.parse()
                  ↓
        List<LrcLine> 歌词行列表
                  ↓
      根据播放进度匹配当前行
                  ↓
           LyricView 显示
```

## 技术选型

### 核心框架
- **Flutter 3.10.1+**: 跨平台 UI 框架
- **Dart SDK**: 编程语言

### 状态管理
- **Provider 6.1.2**: 轻量级状态管理

### 音频处理
- **flutter_soloud 3.4.6**: 高性能音频引擎
- ~~audioplayers~~: 已替换为 SoLoud
- ~~ffmpeg_kit_flutter~~: 已移除

### 网络与 API
- **http 1.2.2**: HTTP 客户端
- **cached_network_image 3.2.3**: 图片缓存

### 平台集成
- **window_manager 0.4.2**: 窗口管理
- **hotkey_manager 0.2.3**: 全局快捷键
- **file_picker 8.0.0**: 文件选择
- **path_provider 2.1.4**: 路径获取

### 持久化
- **shared_preferences 2.3.2**: 简单键值存储

### 工具库
- **uuid 4.5.1**: UUID 生成
- **path 1.9.0**: 路径处理

## 设计模式

### 1. Provider Pattern（提供者模式）
用于状态管理和依赖注入。

### 2. Repository Pattern（仓库模式）
`GdMusicApiClient` 封装数据访问逻辑。

### 3. Observer Pattern（观察者模式）
Provider 的 `notifyListeners()` 机制。

### 4. Singleton Pattern（单例模式）
`SoLoud.instance` 全局唯一实例。

### 5. Builder Pattern（构建器模式）
Widget 树的构建。

## 性能优化

### 1. 异步加载
- 使用 `async/await` 处理耗时操作
- 避免阻塞 UI 线程

### 2. 状态更新优化
- 使用 `Selector` 代替 `Consumer` 减少重建
- 合理划分 Provider 粒度

### 3. 资源管理
- 及时释放 AudioSource 和 SoundHandle
- 使用缓存减少重复请求

### 4. UI 渲染优化
- FFT 数据降采样
- 使用 `const` 构造函数
- 避免过度嵌套

## 安全性考虑

### 1. API 请求
- 超时设置（默认 12 秒）
- 异常处理和用户友好提示

### 2. 文件访问
- 校验文件路径合法性
- 处理文件不存在的情况

### 3. 用户数据
- 本地存储，不上传隐私数据
- 收藏和历史记录仅保存必要信息

## 可扩展性

### 添加新的音乐源
1. 在 `GdMusicApiClient` 中添加新源的参数
2. 或创建新的 API 客户端服务
3. 更新 `SearchProvider` 支持新源

### 添加新的播放模式
1. 在 `PlaylistProvider` 中定义新模式
2. 实现切换逻辑
3. 更新 UI 显示

### 添加新的可视化效果
1. 创建新的可视化 Widget
2. 使用 `PlayerProvider.fftData` 和 `waveData`
3. 在 `VisualizerView` 中集成

## 未来改进方向

- [ ] 支持更多音频格式（如 APE、DSD）
- [ ] 添加音频效果器（如均衡器）
- [ ] 支持播放列表导入/导出
- [ ] 添加迷你模式窗口
- [ ] 支持歌词编辑和时间轴调整
- [ ] 支持播客和电台
- [ ] 云同步功能

## 相关文档

- [开发指南](./Development-Guide.md)
- [API 文档](./API-Documentation.md)
- [状态管理](./State-Management.md)
