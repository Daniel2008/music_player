# 在线音乐

本文档详细介绍 Music Player 的在线音乐功能，包括搜索、播放、下载等。

## 目录

- [GD 音乐台 API](#gd-音乐台-api)
- [音乐源](#音乐源)
- [搜索功能](#搜索功能)
- [播放在线音乐](#播放在线音乐)
- [歌词获取](#歌词获取)
- [下载管理](#下载管理)

## GD 音乐台 API

### 简介

Music Player 使用 **GD 音乐台 API** 作为在线音乐服务的统一接口。

- **API 地址**：`https://music-api.gdstudio.xyz/api.php`
- **协议**：HTTP/HTTPS
- **格式**：JSON

### 特性

- ✅ 多音乐源聚合（网易云、QQ 音乐、酷狗、酷我等）
- ✅ 统一接口规范
- ✅ 支持搜索、播放链接、歌词、封面等功能
- ✅ 多音质选择

### 客户端初始化

```dart
final GdMusicApiClient _gdApi = GdMusicApiClient(
  baseUrl: 'https://music-api.gdstudio.xyz/api.php',
  timeout: Duration(seconds: 12),
);
```

配置项：
- `baseUrl`: API 服务地址（可自定义）
- `timeout`: 请求超时时间（默认 12 秒）
- `client`: HTTP 客户端（可自定义）

## 音乐源

### 支持的源

| 源代码 | 名称 | 说明 |
|--------|------|------|
| `netease` | 网易云音乐 | 曲库丰富，歌词准确 |
| `tencent` | QQ 音乐 | 版权音乐多 |
| `kugou` | 酷狗音乐 | 流行音乐为主 |
| `kuwo` | 酷我音乐 | 综合音乐平台 |

### 选择音乐源

```dart
// 在搜索时指定
await searchProvider.search(
  keyword: '歌曲名',
  source: 'netease',  // 选择网易云
);
```

建议：
- 优先使用 `netease`，曲库和歌词质量较好
- 如果找不到，尝试其他源
- 不同源的音质和可用性可能不同

## 搜索功能

### 基本搜索

```dart
final results = await _gdApi.search(
  keyword: '周杰伦 稻香',
  source: 'netease',
  count: 20,
  page: 1,
);
```

参数：
- `keyword`: 搜索关键词（歌曲名、歌手名、专辑名）
- `source`: 音乐源
- `count`: 结果数量（建议 10-50）
- `page`: 页码（从 1 开始）

返回：
- `List<GdSearchTrack>`: 搜索结果列表

### 搜索结果

```dart
class GdSearchTrack {
  final String id;           // 歌曲 ID
  final String name;         // 歌曲名
  final List<String> artists; // 艺术家列表
  final String album;        // 专辑名
  final String? picId;       // 封面 ID
  final String? lyricId;     // 歌词 ID
  final String source;       // 音乐源
}
```

### 专辑搜索

```dart
final albumResults = await _gdApi.searchAlbum(
  keyword: '专辑名或专辑 ID',
  source: 'netease',
  count: 50,
);
```

说明：
- 返回专辑中的所有歌曲
- 源代码自动添加 `_album` 后缀（如 `netease_album`）

### 搜索优化

#### 关键词提取

```dart
String _extractSearchKeyword(String title) {
  var keyword = title;
  
  // 移除括号内容
  keyword = keyword.replaceAll(
    RegExp(r'[\(（\[【][^\)）\]】]*[\)）\]】]'),
    '',
  );
  
  // 移除音质标识
  keyword = keyword.replaceAll(
    RegExp(r'(320k|128k|flac|ape|mp3|wav|hi-?res|无损)', 
           caseSensitive: false),
    '',
  );
  
  // 去除多余空格
  keyword = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  return keyword.length < 2 ? title : keyword;
}
```

#### 结果过滤

```dart
final validResults = results
    .where((t) => t.id.isNotEmpty && t.name.isNotEmpty)
    .toList();
```

## 播放在线音乐

### 获取播放 URL

```dart
final trackUrl = await _gdApi.getTrackUrl(
  source: 'netease',
  id: '歌曲 ID',
  br: '999',  // 音质
);
```

音质选项（`br` 参数）：
- `128`: 128kbps MP3
- `320`: 320kbps MP3
- `740`: 无损 FLAC
- `999`: Hi-Res（如果可用）

返回：
```dart
class GdTrackUrl {
  final String url;      // 播放 URL
  final int? br;         // 实际比特率
  final int? sizeKb;     // 文件大小（KB）
}
```

### 播放流程

```dart
// 1. 搜索歌曲
final results = await _gdApi.search(
  keyword: '歌曲名',
  source: 'netease',
);

// 2. 选择结果
final item = results.first;

// 3. 获取播放 URL
final trackUrl = await _gdApi.getTrackUrl(
  source: item.source,
  id: item.id,
  br: '999',
);

// 4. 创建 Track 并播放
final track = Track(
  id: Track.generateRemoteId(item.source, item.id),
  title: '${item.name} - ${item.artistText}',
  path: trackUrl.url,
  kind: TrackKind.remote,
  remoteSource: item.source,
  remoteTrackId: item.id,
);

await playerProvider.playTrack(track);
```

### 快捷方法

PlayerProvider 提供了简化的方法：

```dart
// 直接从搜索结果播放
await playerProvider.resolveAndPlayTrackUrl(
  item,
  br: '999',
  playlistProvider: playlistProvider,
);
```

内部自动完成：
1. 获取播放 URL
2. 创建 Track
3. 更新播放列表
4. 开始播放
5. 异步获取歌词

## 歌词获取

### 获取在线歌词

```dart
final lyric = await _gdApi.getLyric(
  source: 'netease',
  id: '歌词 ID',
);
```

返回：
```dart
class GdLyric {
  final String lyric;    // 原文歌词（LRC 格式）
  final String? tlyric;  // 翻译歌词（LRC 格式）
}
```

### 歌词缓存

远程歌词会自动缓存到本地：

```dart
Future<void> _ensureLyricCachedFor(Track track) async {
  if (!track.isRemote) return;
  
  final key = track.lyricKey;  // 如 'gd_netease_1234567'
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/$key.lrc');
  
  // 已缓存，直接返回
  if (await file.exists()) return;
  
  // 获取并缓存
  try {
    final lyric = await _gdApi.getLyric(
      source: track.remoteSource!,
      id: track.remoteLyricId!,
    );
    
    if (lyric.lyric.trim().isNotEmpty) {
      await file.writeAsString(lyric.lyric);
      lyricRevision++;  // 触发歌词更新
      notifyListeners();
    }
  } catch (_) {
    // 忽略错误
  }
}
```

### 本地歌曲搜索在线歌词

```dart
Future<String?> fetchOnlineLyricForLocal(
  Track track, {
  String source = 'netease',
  String? searchKeyword,
}) async {
  // 1. 提取搜索关键词
  final keyword = searchKeyword ?? _extractSearchKeyword(track.title);
  
  // 2. 搜索
  final results = await _gdApi.search(
    keyword: keyword,
    source: source,
    count: 10,
  );
  
  // 3. 匹配最佳结果
  final match = _findBestLyricMatch(results, track.title);
  if (match == null) return null;
  
  // 4. 获取歌词
  final lyric = await _gdApi.getLyric(
    source: match.source,
    id: match.lyricId!,
  );
  
  // 5. 缓存到本地
  final dir = await getApplicationSupportDirectory();
  final path = '${dir.path}/local_${track.id}.lrc';
  await File(path).writeAsString(lyric.lyric);
  
  return path;
}
```

#### 匹配算法

```dart
GdSearchTrack? _findBestLyricMatch(
  List<GdSearchTrack> results,
  String title,
) {
  // 过滤出有歌词的结果
  final withLyric = results
      .where((r) => r.lyricId != null && r.lyricId!.isNotEmpty)
      .toList();
  
  if (withLyric.isEmpty) return null;
  
  // 查找标题匹配的
  final titleLower = title.toLowerCase();
  for (final r in withLyric) {
    final nameLower = r.name.toLowerCase();
    if (titleLower.contains(nameLower) || 
        nameLower.contains(titleLower)) {
      return r;
    }
  }
  
  // 返回第一个
  return withLyric.first;
}
```

## 封面图片

### 构建封面 URL

```dart
final coverUrl = _gdApi.buildCoverUrl(
  item.picId,
  item.source,
  size: 300,  // 或 500
);
```

尺寸选项：
- `300`: 小图，适合列表
- `500`: 大图，适合播放器页面

### 使用封面

```dart
// 使用 cached_network_image 缓存
CachedNetworkImage(
  imageUrl: coverUrl ?? '',
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.music_note),
)
```

## 下载管理

### 下载歌曲

```dart
// DownloadProvider
Future<void> downloadTrack(
  GdSearchTrack item, {
  String br = '999',
}) async {
  // 1. 获取播放 URL
  final trackUrl = await _gdApi.getTrackUrl(
    source: item.source,
    id: item.id,
    br: br,
  );
  
  // 2. 下载文件
  final response = await http.get(Uri.parse(trackUrl.url));
  
  // 3. 保存到本地
  final dir = await getDownloadsDirectory();
  final filename = '${item.name} - ${item.artistText}.mp3';
  final file = File('${dir!.path}/$filename');
  await file.writeAsBytes(response.bodyBytes);
  
  // 4. 添加到播放列表
  final track = Track(
    title: item.name,
    path: file.path,
    artist: item.artistText,
    kind: TrackKind.local,
  );
  
  playlistProvider.addTrack(track);
}
```

### 下载进度

```dart
// 使用流式下载
final request = http.Request('GET', Uri.parse(url));
final response = await client.send(request);

final total = response.contentLength ?? 0;
var downloaded = 0;

final file = File(path);
final sink = file.openWrite();

await for (final chunk in response.stream) {
  sink.add(chunk);
  downloaded += chunk.length;
  
  // 更新进度
  progress = downloaded / total;
  notifyListeners();
}

await sink.close();
```

## 错误处理

### API 异常

```dart
try {
  final results = await _gdApi.search(keyword: '歌曲');
} on GdMusicApiTimeout {
  // 请求超时
  showError('请求超时，请检查网络连接');
} on GdMusicApiHttpException catch (e) {
  // HTTP 错误
  showError('服务错误: ${e.statusCode}');
} on FormatException {
  // 响应格式错误
  showError('数据解析失败');
} catch (e) {
  // 其他错误
  showError('未知错误: $e');
}
```

### 网络检查

```dart
// 测试 API 连接
final connected = await _gdApi.testConnection();
if (!connected) {
  showError('无法连接到音乐服务');
}
```

## 配置管理

### API 设置

```dart
class ApiSettingsProvider extends ChangeNotifier {
  String apiBaseUrl = GdMusicApiClient.defaultBaseUrl;
  int requestTimeout = 12;  // 秒
  String downloadQuality = '999';
  bool autoFetchLyric = true;
  
  // 更新配置
  void updateApiBaseUrl(String url) {
    apiBaseUrl = url;
    _gdApi.updateBaseUrl(url);
    _saveSettings();
    notifyListeners();
  }
  
  void updateTimeout(int seconds) {
    requestTimeout = seconds;
    _gdApi.updateTimeoutSeconds(seconds);
    _saveSettings();
    notifyListeners();
  }
}
```

### 持久化

```dart
Future<void> _saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('api_base_url', apiBaseUrl);
  await prefs.setInt('request_timeout', requestTimeout);
}

Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  apiBaseUrl = prefs.getString('api_base_url') ?? 
               GdMusicApiClient.defaultBaseUrl;
  requestTimeout = prefs.getInt('request_timeout') ?? 12;
}
```

## 最佳实践

### 1. 音质选择

- 移动网络：128k
- Wi-Fi：320k 或 740k
- 高音质需求：999k

### 2. 缓存策略

- 歌词自动缓存，避免重复请求
- 封面使用 cached_network_image
- 播放 URL 有时效性，不宜长期缓存

### 3. 错误重试

```dart
Future<T> retryRequest<T>(
  Future<T> Function() request, {
  int maxRetries = 3,
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await request();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 1 << i));
    }
  }
  throw Exception('Max retries exceeded');
}
```

### 4. 超时设置

- 搜索：5-10 秒
- 获取 URL：10-15 秒
- 下载：根据文件大小动态调整

## 相关文档

- [播放器核心](./Player-Core.md)
- [歌词系统](./Lyrics-System.md)
- [API 文档](./API-Documentation.md)
