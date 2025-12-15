# 歌词系统

本文档详细介绍 Music Player 的歌词功能，包括本地歌词、在线歌词、歌词解析和显示。

## 目录

- [LRC 格式](#lrc-格式)
- [本地歌词](#本地歌词)
- [在线歌词](#在线歌词)
- [歌词解析](#歌词解析)
- [歌词显示](#歌词显示)
- [同步算法](#同步算法)

## LRC 格式

### 标准格式

LRC (Lyric) 是一种时间同步歌词格式。

基本格式：
```lrc
[mm:ss.xx]歌词文本
```

示例：
```lrc
[00:12.00]第一句歌词
[00:17.20]第二句歌词
[00:21.10]第三句歌词
[00:24.00]
[00:27.00]空行也会被保留
```

### 元数据标签

```lrc
[ti:歌曲名]
[ar:艺术家]
[al:专辑名]
[by:歌词制作者]
[offset:时间补偿值（毫秒）]

[00:12.00]正式歌词开始
```

### 多时间标签

一行歌词可以有多个时间标签（重复部分）：

```lrc
[00:12.00][01:15.00]副歌部分
[00:17.00][01:20.00]重复的歌词
```

## 本地歌词

### 自动加载

应用会自动搜索与音乐文件同名的 `.lrc` 文件。

文件结构：
```
Music/
├── Song Name.mp3
└── Song Name.lrc
```

加载逻辑：
```dart
Future<String?> _getLocalLrcPath(Track track) async {
  final audioPath = track.path;
  
  // 1. 检查同目录同名 .lrc 文件
  final name = audioPath.replaceAll(RegExp(r"\.[^/.]+$"), '');
  final lrcLocal = '$name.lrc';
  if (await File(lrcLocal).exists()) {
    return lrcLocal;
  }
  
  // 2. 检查应用缓存目录
  final dir = await getApplicationSupportDirectory();
  final cachedPath = '${dir.path}/local_${track.id}.lrc';
  if (await File(cachedPath).exists()) {
    return cachedPath;
  }
  
  return null;
}
```

### 文件编码

推荐使用 **UTF-8** 编码，避免中文乱码。

转换编码（如果是 GBK）：
```bash
# Linux/macOS
iconv -f GBK -t UTF-8 song.lrc > song_utf8.lrc

# Windows (PowerShell)
Get-Content song.lrc -Encoding Default | 
  Set-Content song_utf8.lrc -Encoding UTF8
```

### 手动加载

未来可以添加手动选择歌词文件的功能：

```dart
Future<void> loadLyricFile(Track track) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['lrc'],
  );
  
  if (result != null && result.files.single.path != null) {
    final path = result.files.single.path!;
    
    // 复制到缓存目录
    final dir = await getApplicationSupportDirectory();
    final targetPath = '${dir.path}/local_${track.id}.lrc';
    await File(path).copy(targetPath);
    
    localLyricPaths[track.id] = targetPath;
    lyricRevision++;
    notifyListeners();
  }
}
```

## 在线歌词

### 远程歌曲自动获取

播放远程歌曲时自动获取歌词：

```dart
Future<void> _ensureLyricCachedFor(Track track) async {
  if (!track.isRemote) return;
  
  final source = track.remoteSource;
  final lyricId = track.remoteLyricId;
  final key = track.lyricKey;  // 'gd_netease_1234567'
  
  if (source == null || lyricId == null || key == null) return;
  
  // 检查缓存
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/$key.lrc');
  if (await file.exists()) return;
  
  // 获取歌词
  try {
    final lyric = await _gdApi.getLyric(
      source: source,
      id: lyricId,
    );
    
    if (lyric.lyric.trim().isEmpty) return;
    
    // 缓存到本地
    await file.writeAsString(lyric.lyric);
    lyricRevision++;
    notifyListeners();
  } catch (_) {
    // 忽略错误
  }
}
```

### 本地歌曲搜索在线歌词

为本地歌曲自动搜索并匹配在线歌词：

```dart
Future<String?> fetchOnlineLyricForLocal(
  Track track, {
  String source = 'netease',
  String? searchKeyword,
}) async {
  if (track.isRemote) return null;
  
  // 防止重复搜索
  if (_fetchingLyricIds.contains(track.id)) return null;
  _fetchingLyricIds.add(track.id);
  
  try {
    // 1. 提取搜索关键词
    final keyword = searchKeyword ?? 
                    _extractSearchKeyword(track.title);
    
    // 2. 搜索歌曲
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
    
    if (lyric.lyric.trim().isEmpty) return null;
    
    // 5. 保存到缓存
    final dir = await getApplicationSupportDirectory();
    final filename = 'local_${track.id}.lrc';
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.writeAsString(lyric.lyric);
    
    // 6. 记录并通知
    localLyricPaths[track.id] = path;
    lyricRevision++;
    notifyListeners();
    
    return path;
  } catch (_) {
    return null;
  } finally {
    _fetchingLyricIds.remove(track.id);
  }
}
```

### 关键词提取

```dart
String _extractSearchKeyword(String title) {
  var keyword = title;
  
  // 移除括号内容（如版本、音质标识）
  keyword = keyword.replaceAll(
    RegExp(r'[\(（\[【][^\)）\]】]*[\)）\]】]'),
    '',
  );
  
  // 移除常见音质标识
  keyword = keyword.replaceAll(
    RegExp(
      r'(320k|128k|flac|ape|mp3|wav|hi-?res|无损)',
      caseSensitive: false,
    ),
    '',
  );
  
  // 去除多余空格
  keyword = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  // 关键词太短则使用原标题
  if (keyword.length < 2) return title;
  
  return keyword;
}
```

### 匹配算法

```dart
GdSearchTrack? _findBestLyricMatch(
  List<GdSearchTrack> results,
  String title,
) {
  if (results.isEmpty) return null;
  
  // 只考虑有歌词的结果
  final withLyric = results
      .where((r) => r.lyricId != null && r.lyricId!.isNotEmpty)
      .toList();
  
  if (withLyric.isEmpty) return null;
  
  // 模糊匹配标题
  final titleLower = title.toLowerCase();
  for (final r in withLyric) {
    final nameLower = r.name.toLowerCase();
    if (titleLower.contains(nameLower) || 
        nameLower.contains(titleLower)) {
      return r;
    }
  }
  
  // 返回第一个结果
  return withLyric.first;
}
```

## 歌词解析

### LrcParser

```dart
class LrcParser {
  static List<LrcLine> parse(String content) {
    final lines = <LrcLine>[];
    
    for (final raw in content.split('\n')) {
      // 匹配时间标签：[mm:ss.xx]
      final matches = RegExp(
        r"\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,2}))?\](.*)",
      ).allMatches(raw);
      
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final msStr = m.group(3);
        
        // 处理毫秒（两位数 -> 百分之一秒）
        final ms = msStr == null 
            ? 0 
            : int.parse(msStr.padRight(2, '0')) * 10;
        
        final text = m.group(4)!.trim();
        
        lines.add(
          LrcLine(
            Duration(minutes: min, seconds: sec, milliseconds: ms),
            text,
          ),
        );
      }
    }
    
    // 按时间排序
    lines.sort((a, b) => a.time.compareTo(b.time));
    
    return lines;
  }
}
```

### LrcLine

```dart
class LrcLine {
  final Duration time;  // 时间戳
  final String text;    // 歌词文本
  
  LrcLine(this.time, this.text);
}
```

### 解析示例

输入：
```lrc
[00:12.00]第一句歌词
[00:17.20]第二句歌词
[00:21.10]第三句歌词
```

输出：
```dart
[
  LrcLine(Duration(seconds: 12), '第一句歌词'),
  LrcLine(Duration(seconds: 17, milliseconds: 200), '第二句歌词'),
  LrcLine(Duration(seconds: 21, milliseconds: 100), '第三句歌词'),
]
```

## 歌词显示

### LyricView Widget

歌词显示组件的核心逻辑：

```dart
class LyricView extends StatefulWidget {
  final List<LrcLine> lines;
  final Duration position;
  
  @override
  Widget build(BuildContext context) {
    final currentIndex = _findCurrentLineIndex(lines, position);
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isCurrent = index == currentIndex;
        
        return AnimatedDefaultTextStyle(
          duration: Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: isCurrent ? 18 : 14,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
```

### 当前行查找

```dart
int _findCurrentLineIndex(List<LrcLine> lines, Duration position) {
  if (lines.isEmpty) return -1;
  
  for (int i = lines.length - 1; i >= 0; i--) {
    if (position >= lines[i].time) {
      return i;
    }
  }
  
  return -1;
}
```

逻辑：
- 从后向前遍历
- 找到第一个时间小于等于当前位置的行
- 如果都不满足，返回 -1（还未开始）

### 自动滚动

```dart
void _scrollToCurrentLine(int index) {
  if (index < 0 || index >= lines.length) return;
  
  final offset = index * lineHeight - screenHeight / 2;
  
  _scrollController.animateTo(
    offset.clamp(0, _scrollController.position.maxScrollExtent),
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
}
```

## 同步算法

### 位置匹配

```dart
class LyricSync {
  final List<LrcLine> lines;
  int _lastIndex = -1;
  
  int getCurrentIndex(Duration position) {
    // 优化：如果位置在上一行之后，从上一行开始查找
    final startIndex = _lastIndex >= 0 ? _lastIndex : lines.length - 1;
    
    for (int i = startIndex; i >= 0; i--) {
      if (position >= lines[i].time) {
        _lastIndex = i;
        return i;
      }
    }
    
    _lastIndex = -1;
    return -1;
  }
}
```

### 前瞻显示

显示当前行和接下来的几行：

```dart
List<LrcLine> getVisibleLines(int currentIndex, {int before = 2, int after = 5}) {
  if (currentIndex < 0) {
    return lines.take(after).toList();
  }
  
  final start = (currentIndex - before).clamp(0, lines.length);
  final end = (currentIndex + after + 1).clamp(0, lines.length);
  
  return lines.sublist(start, end);
}
```

### 时间补偿

处理 `[offset:±ms]` 标签：

```dart
List<LrcLine> applyOffset(List<LrcLine> lines, int offsetMs) {
  if (offsetMs == 0) return lines;
  
  final offset = Duration(milliseconds: offsetMs);
  
  return lines.map((line) {
    return LrcLine(
      line.time + offset,
      line.text,
    );
  }).toList();
}
```

## 双语歌词

### 合并原文和翻译

```dart
List<LrcLine> mergeLyrics(List<LrcLine> original, List<LrcLine> translation) {
  final merged = <LrcLine>[];
  
  for (final line in original) {
    // 查找对应的翻译
    final trans = translation.firstWhere(
      (t) => t.time == line.time,
      orElse: () => LrcLine(line.time, ''),
    );
    
    // 合并文本
    final text = trans.text.isEmpty
        ? line.text
        : '${line.text}\n${trans.text}';
    
    merged.add(LrcLine(line.time, text));
  }
  
  return merged;
}
```

### 显示双语

```dart
Widget _buildBilingualLine(LrcLine line) {
  final parts = line.text.split('\n');
  
  return Column(
    children: [
      Text(
        parts[0],  // 原文
        style: TextStyle(fontSize: 18),
      ),
      if (parts.length > 1)
        Text(
          parts[1],  // 翻译
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
    ],
  );
}
```

## 性能优化

### 缓存解析结果

```dart
final Map<String, List<LrcLine>> _parsedLyrics = {};

List<LrcLine> getParsedLyric(String path) {
  if (_parsedLyrics.containsKey(path)) {
    return _parsedLyrics[path]!;
  }
  
  final content = File(path).readAsStringSync();
  final lines = LrcParser.parse(content);
  _parsedLyrics[path] = lines;
  
  return lines;
}
```

### 延迟加载

```dart
Future<List<LrcLine>> loadLyricAsync(String path) async {
  final content = await File(path).readAsString();
  return await compute(LrcParser.parse, content);
}
```

### 限制更新频率

```dart
Duration _lastNotifiedPosition = Duration.zero;

void updatePosition(Duration position) {
  // 只在秒数变化时通知
  if (position.inSeconds != _lastNotifiedPosition.inSeconds) {
    _lastNotifiedPosition = position;
    notifyListeners();
  }
}
```

## 故障排除

### 歌词不显示

检查项：
1. 文件是否存在
2. 文件编码是否为 UTF-8
3. LRC 格式是否正确
4. 文件权限是否可读

### 歌词不同步

原因：
- 时间轴不准确
- 音频文件版本不同

解决：
- 查找更准确的歌词文件
- 使用 `[offset:]` 标签调整

### 中文乱码

```dart
// 尝试不同编码
String readLyricFile(String path) {
  try {
    // 尝试 UTF-8
    return File(path).readAsStringSync(encoding: utf8);
  } catch (_) {
    try {
      // 尝试 GBK
      return File(path).readAsStringSync(encoding: gbk);
    } catch (_) {
      return '';
    }
  }
}
```

## 未来改进

- [ ] 歌词编辑器
- [ ] 时间轴调整工具
- [ ] 逐字同步（karaoke）
- [ ] 罗马音显示
- [ ] 用户上传歌词

## 相关文档

- [在线音乐](./Online-Music.md)
- [播放器核心](./Player-Core.md)
- [API 文档](./API-Documentation.md)
