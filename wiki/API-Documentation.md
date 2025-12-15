# API 文档

本文档详细介绍 Music Player 的核心 API 和接口。

## 目录

- [Provider API](#provider-api)
- [Model API](#model-api)
- [Service API](#service-api)
- [Utils API](#utils-api)

## Provider API

### PlayerProvider

播放器核心控制 Provider。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `volume` | `double` | 音量（0.0 - 1.0）|
| `isPlaying` | `bool` | 是否正在播放 |
| `position` | `Duration` | 当前播放位置 |
| `duration` | `Duration` | 总时长 |
| `isResolvingUrl` | `bool` | 是否正在解析 URL |
| `playError` | `String?` | 播放错误信息 |
| `lyricRevision` | `int` | 歌词版本号（用于触发更新）|
| `fftData` | `Float32List` | FFT 频谱数据 |
| `waveData` | `Float32List` | 波形数据 |
| `autoFetchLyricForLocal` | `bool` | 是否自动为本地歌曲搜索歌词 |

#### 方法

**playTrack(Track track)**
```dart
Future<void> playTrack(Track track)
```
播放指定曲目。

参数：
- `track`: 要播放的曲目

示例：
```dart
final player = context.read<PlayerProvider>();
await player.playTrack(track);
```

---

**play()**
```dart
Future<void> play()
```
恢复播放（从暂停状态）。

---

**pause()**
```dart
Future<void> pause()
```
暂停播放。

---

**stop()**
```dart
Future<void> stop()
```
停止播放并释放资源。

---

**seek(Duration d)**
```dart
Future<void> seek(Duration d)
```
跳转到指定位置。

参数：
- `d`: 目标位置

示例：
```dart
// 跳转到 30 秒位置
player.seek(Duration(seconds: 30));
```

---

**setVolume(double v)**
```dart
Future<void> setVolume(double v)
```
设置音量。

参数：
- `v`: 音量值（0.0 - 1.0）

---

**resolveAndPlayTrackUrl()**
```dart
Future<bool> resolveAndPlayTrackUrl(
  GdSearchTrack item, {
  String br = '999',
  PlaylistProvider? playlistProvider,
})
```
解析并播放在线曲目。

参数：
- `item`: 搜索结果项
- `br`: 音质（128/320/740/999）
- `playlistProvider`: 播放列表 Provider（可选）

返回：
- `true` - 成功
- `false` - 失败

---

**fetchOnlineLyricForLocal()**
```dart
Future<String?> fetchOnlineLyricForLocal(
  Track track, {
  String source = 'netease',
  String? searchKeyword,
})
```
为本地歌曲搜索在线歌词。

参数：
- `track`: 本地曲目
- `source`: 搜索源（默认 'netease'）
- `searchKeyword`: 自定义搜索关键词

返回：
- 歌词文件路径，失败返回 `null`

---

### PlaylistProvider

播放列表管理 Provider。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `tracks` | `List<Track>` | 曲目列表 |
| `currentIndex` | `int` | 当前索引 |
| `current` | `Track?` | 当前曲目 |
| `playMode` | `PlayMode` | 播放模式 |

#### 方法

**addTrack(Track track)**
```dart
void addTrack(Track track)
```
添加单个曲目。

---

**addTracks(List<Track> tracks)**
```dart
void addTracks(List<Track> tracks)
```
批量添加曲目。

---

**removeAt(int index)**
```dart
void removeAt(int index)
```
删除指定位置的曲目。

---

**clear()**
```dart
void clear()
```
清空播放列表。

---

**next()**
```dart
void next()
```
切换到下一曲。

---

**previous()**
```dart
void previous()
```
切换到上一曲。

---

**jumpTo(int index)**
```dart
void jumpTo(int index)
```
跳转到指定曲目。

---

**setPlayMode(PlayMode mode)**
```dart
void setPlayMode(PlayMode mode)
```
设置播放模式。

模式：
- `PlayMode.sequence` - 顺序播放
- `PlayMode.loop` - 列表循环
- `PlayMode.shuffle` - 随机播放
- `PlayMode.single` - 单曲循环

---

### SearchProvider

搜索功能 Provider。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `results` | `List<GdSearchTrack>` | 搜索结果 |
| `isSearching` | `bool` | 是否正在搜索 |
| `searchError` | `String?` | 搜索错误信息 |

#### 方法

**search()**
```dart
Future<void> search({
  required String keyword,
  String source = 'netease',
  int count = 20,
})
```
搜索歌曲。

参数：
- `keyword`: 搜索关键词
- `source`: 音乐源
- `count`: 结果数量

---

### ThemeProvider

主题管理 Provider。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `mode` | `ThemeMode` | 主题模式 |
| `lightTheme` | `ThemeData` | 浅色主题 |
| `darkTheme` | `ThemeData` | 深色主题 |

#### 方法

**setMode(ThemeMode newMode)**
```dart
Future<void> setMode(ThemeMode newMode)
```
设置主题模式。

---

**loadSkin(String assetPath)**
```dart
Future<void> loadSkin(String assetPath)
```
加载皮肤配置。

参数：
- `assetPath`: 皮肤 JSON 文件路径

---

### FavoritesProvider

收藏管理 Provider。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `favorites` | `List<Track>` | 收藏列表 |

#### 方法

**addFavorite(Track track)**
```dart
Future<void> addFavorite(Track track)
```
添加到收藏。

---

**removeFavorite(String trackId)**
```dart
Future<void> removeFavorite(String trackId)
```
取消收藏。

---

**isFavorite(String trackId)**
```dart
bool isFavorite(String trackId)
```
检查是否已收藏。

---

## Model API

### Track

曲目数据模型。

#### 构造函数

```dart
Track({
  String? id,
  required String title,
  required String path,
  String? artist,
  String? artUri,
  Duration? duration,
  TrackKind kind = TrackKind.local,
  String? remoteSource,
  String? remoteTrackId,
  String? remoteLyricId,
  String? lyricKey,
})
```

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 唯一标识（自动生成）|
| `title` | `String` | 标题 |
| `path` | `String` | 本地路径或 URL |
| `artist` | `String?` | 艺术家 |
| `artUri` | `String?` | 封面 URI |
| `duration` | `Duration?` | 时长 |
| `kind` | `TrackKind` | 类型（local/remote）|
| `remoteSource` | `String?` | 远程源 |
| `remoteTrackId` | `String?` | 远程曲目 ID |
| `remoteLyricId` | `String?` | 远程歌词 ID |
| `lyricKey` | `String?` | 歌词缓存键 |

#### Getter

**isRemote**
```dart
bool get isRemote
```
是否为远程曲目。

#### 静态方法

**generateRemoteId()**
```dart
static String generateRemoteId(String source, String trackId)
```
为远程曲目生成确定性 ID。

#### 实例方法

**copyWith()**
```dart
Track copyWith({
  String? id,
  String? title,
  String? path,
  // ... 其他字段
})
```
创建副本并覆盖指定字段。

---

### Playlist

播放列表模型。

#### 构造函数

```dart
Playlist({
  required String name,
  List<Track>? tracks,
  int currentIndex = 0,
})
```

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `name` | `String` | 列表名称 |
| `tracks` | `List<Track>` | 曲目列表 |
| `currentIndex` | `int` | 当前索引 |

#### Getter

**current**
```dart
Track? get current
```
获取当前曲目。

**isEmpty**
```dart
bool get isEmpty
```
列表是否为空。

#### 方法

**addAll(List<Track> items)**
```dart
void addAll(List<Track> items)
```
批量添加曲目。

**next()**
```dart
void next()
```
切换到下一曲（循环）。

**previous()**
```dart
void previous()
```
切换到上一曲（循环）。

---

## Service API

### GdMusicApiClient

GD 音乐台 API 客户端。

#### 构造函数

```dart
GdMusicApiClient({
  String? baseUrl,
  http.Client? client,
  Duration? timeout,
})
```

#### 常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `defaultBaseUrl` | `'https://music-api.gdstudio.xyz/api.php'` | 默认 API 地址 |
| `defaultTimeout` | `Duration(seconds: 12)` | 默认超时时间 |

#### 属性

**baseUri**
```dart
Uri get baseUri
```
当前 API 基础地址。

**timeout**
```dart
Duration get timeout
```
当前超时时间。

#### 方法

**updateBaseUrl(String url)**
```dart
void updateBaseUrl(String url)
```
更新 API 基础地址。

---

**updateTimeout(Duration timeout)**
```dart
void updateTimeout(Duration timeout)
```
更新超时时间。

---

**search()**
```dart
Future<List<GdSearchTrack>> search({
  required String keyword,
  String source = 'netease',
  int count = 20,
  int page = 1,
})
```
搜索歌曲。

参数：
- `keyword`: 搜索关键词
- `source`: 音乐源（netease/tencent/kugou/kuwo）
- `count`: 每页结果数量
- `page`: 页码

返回：
- 搜索结果列表

抛出：
- `GdMusicApiException` - API 异常
- `GdMusicApiTimeout` - 超时
- `GdMusicApiHttpException` - HTTP 错误

---

**getTrackUrl()**
```dart
Future<GdTrackUrl> getTrackUrl({
  required String source,
  required String id,
  String br = '999',
})
```
获取歌曲播放链接。

参数：
- `source`: 音乐源
- `id`: 歌曲 ID
- `br`: 音质（128/320/740/999）

返回：
- `GdTrackUrl` 对象，包含 URL、音质、大小等信息

---

**getLyric()**
```dart
Future<GdLyric> getLyric({
  required String source,
  required String id,
})
```
获取歌词。

参数：
- `source`: 音乐源
- `id`: 歌词 ID

返回：
- `GdLyric` 对象，包含歌词和翻译

---

**buildCoverUrl()**
```dart
String? buildCoverUrl(
  String? picId,
  String source, {
  int size = 300,
})
```
构建封面图片 URL。

参数：
- `picId`: 图片 ID
- `source`: 音乐源
- `size`: 图片尺寸（300/500）

返回：
- 封面图片 URL，失败返回 `null`

---

**testConnection()**
```dart
Future<bool> testConnection()
```
测试 API 连接。

返回：
- `true` - 连接成功
- `false` - 连接失败

---

### GdSearchTrack

搜索结果项模型。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 歌曲 ID |
| `name` | `String` | 歌曲名 |
| `artists` | `List<String>` | 艺术家列表 |
| `album` | `String` | 专辑名 |
| `picId` | `String?` | 封面 ID |
| `lyricId` | `String?` | 歌词 ID |
| `source` | `String` | 音乐源 |

#### Getter

**artistText**
```dart
String get artistText
```
艺术家文本（多个艺术家用 " / " 连接）。

#### 方法

**toJson()**
```dart
Map<String, dynamic> toJson()
```
转换为 JSON。

**fromJson()**
```dart
factory GdSearchTrack.fromJson(Map<String, dynamic> json)
```
从 JSON 创建实例。

---

### GdTrackUrl

播放 URL 信息。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `url` | `String` | 播放 URL |
| `br` | `int?` | 比特率 |
| `sizeKb` | `int?` | 文件大小（KB）|

#### Getter

**sizeDisplay**
```dart
String get sizeDisplay
```
文件大小的友好显示（如 "3.5 MB"）。

**qualityDisplay**
```dart
String get qualityDisplay
```
音质的友好显示（如 "Hi-Res"、"无损"）。

---

### GdLyric

歌词信息。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `lyric` | `String` | 原文歌词 |
| `tlyric` | `String?` | 翻译歌词 |

#### Getter

**hasTranslation**
```dart
bool get hasTranslation
```
是否有翻译歌词。

---

## Utils API

### LrcParser

歌词解析器。

#### 静态方法

**parse(String content)**
```dart
static List<LrcLine> parse(String content)
```
解析 LRC 格式歌词。

参数：
- `content`: LRC 文件内容

返回：
- 歌词行列表，按时间排序

示例：
```dart
final content = '''
[00:12.00]第一句歌词
[00:17.20]第二句歌词
''';

final lines = LrcParser.parse(content);
for (final line in lines) {
  print('${line.time}: ${line.text}');
}
```

---

### LrcLine

歌词行模型。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `time` | `Duration` | 时间戳 |
| `text` | `String` | 歌词文本 |

---

## 异常类型

### GdMusicApiException

API 异常基类。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `message` | `String` | 错误信息 |
| `uri` | `Uri?` | 请求 URI |

---

### GdMusicApiHttpException

HTTP 错误异常。

#### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `statusCode` | `int` | HTTP 状态码 |

---

### GdMusicApiTimeout

请求超时异常。

---

## 使用示例

### 完整播放流程

```dart
// 1. 获取 Providers
final player = context.read<PlayerProvider>();
final playlist = context.read<PlaylistProvider>();

// 2. 添加曲目
final track = Track(
  title: 'My Song',
  path: '/path/to/song.mp3',
  artist: 'Artist Name',
);
playlist.addTrack(track);

// 3. 播放
await player.playTrack(track);

// 4. 监听状态
context.select<PlayerProvider, bool>((p) => p.isPlaying);
```

### 搜索和播放在线音乐

```dart
// 1. 搜索
final searchProvider = context.read<SearchProvider>();
await searchProvider.search(
  keyword: '歌曲名',
  source: 'netease',
);

// 2. 播放搜索结果
final item = searchProvider.results.first;
final player = context.read<PlayerProvider>();
await player.resolveAndPlayTrackUrl(item);
```

## 相关文档

- [架构设计](./Architecture.md)
- [开发指南](./Development-Guide.md)
- [状态管理](./State-Management.md)
