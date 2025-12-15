# 播放器核心

本文档详细介绍 Music Player 的音频播放引擎和核心功能。

## 目录

- [音频引擎](#音频引擎)
- [播放控制](#播放控制)
- [音频数据](#音频数据)
- [本地播放](#本地播放)
- [在线播放](#在线播放)
- [播放队列](#播放队列)

## 音频引擎

### SoLoud 引擎

Music Player 使用 **flutter_soloud** 作为音频播放引擎。

#### 特性

- ✅ **低延迟播放**：亚秒级响应
- ✅ **多格式支持**：MP3、FLAC、WAV、OGG、M4A 等
- ✅ **实时音频数据**：FFT 频谱和波形数据
- ✅ **精确控制**：音量、位置、播放状态
- ✅ **跨平台**：Windows、macOS、Linux 统一接口

#### 初始化

```dart
final SoLoud _soloud = SoLoud.instance;

Future<void> _init() async {
  try {
    await _soloud.init();
    _soloud.setVisualizationEnabled(true);
    _soloud.setFftSmoothing(0.8);
    _initialized = true;
  } catch (e) {
    debugPrint('SoLoud 初始化失败: $e');
  }
}
```

初始化参数：
- `setVisualizationEnabled(true)`: 启用可视化数据采集
- `setFftSmoothing(0.8)`: 设置 FFT 平滑系数（0.0-1.0）

### 资源管理

#### AudioSource

音频源对象，代表已加载的音频文件。

```dart
// 加载本地文件
AudioSource source = await _soloud.loadFile(path);

// 加载网络 URL
AudioSource source = await _soloud.loadUrl(url);
```

#### SoundHandle

声音句柄，代表正在播放的音频实例。

```dart
// 播放音频源
SoundHandle handle = await _soloud.play(source);
```

#### 资源释放

```dart
// 停止播放
await _soloud.stop(handle);

// 释放音频源
await _soloud.disposeSource(source);

// 清理引擎
_soloud.deinit();
```

## 播放控制

### 播放流程

```dart
Future<void> playTrack(Track track) async {
  // 1. 停止当前播放
  await stop();
  
  // 2. 加载音频源
  if (track.isRemote) {
    _currentSource = await _soloud.loadUrl(track.path);
  } else {
    _currentSource = await _soloud.loadFile(track.path);
  }
  
  // 3. 播放
  _currentHandle = await _soloud.play(_currentSource!);
  _soloud.setVolume(_currentHandle!, volume);
  
  // 4. 获取时长
  duration = _soloud.getLength(_currentSource!);
  
  // 5. 启动进度定时器
  _startPositionTimer();
  
  // 6. 更新状态
  isPlaying = true;
  notifyListeners();
}
```

### 基本控制

#### 播放/暂停

```dart
// 播放
Future<void> play() async {
  if (_currentHandle != null) {
    _soloud.setPause(_currentHandle!, false);
    isPlaying = true;
    notifyListeners();
  }
}

// 暂停
Future<void> pause() async {
  if (_currentHandle != null) {
    _soloud.setPause(_currentHandle!, true);
    isPlaying = false;
    notifyListeners();
  }
}
```

#### 停止

```dart
Future<void> stop() async {
  _positionTimer?.cancel();
  
  if (_currentHandle != null) {
    await _soloud.stop(_currentHandle!);
    _currentHandle = null;
  }
  
  if (_currentSource != null) {
    await _soloud.disposeSource(_currentSource!);
    _currentSource = null;
  }
  
  isPlaying = false;
  position = Duration.zero;
  notifyListeners();
}
```

### 进度控制

#### 跳转

```dart
Future<void> seek(Duration d) async {
  if (_currentHandle != null) {
    final clamped = _clampDuration(d, Duration.zero, duration);
    _soloud.seek(_currentHandle!, clamped);
    position = clamped;
    notifyListeners();
  }
}

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) return min;
  if (value > max && max > Duration.zero) return max;
  return value;
}
```

#### 进度更新

```dart
void _startPositionTimer() {
  _positionTimer?.cancel();
  _positionTimer = Timer.periodic(
    const Duration(milliseconds: 50),
    (_) {
      if (_currentHandle != null && isPlaying) {
        // 检查句柄是否有效
        if (!_soloud.getIsValidVoiceHandle(_currentHandle!)) {
          _handleComplete();
          return;
        }
        
        // 更新位置
        position = _soloud.getPosition(_currentHandle!);
        
        // 更新 FFT 数据
        _updateAudioData();
        
        notifyListeners();
      }
    },
  );
}
```

更新频率：50ms（20fps）

### 音量控制

```dart
Future<void> setVolume(double v) async {
  volume = v;  // 0.0 - 1.0
  if (_currentHandle != null) {
    _soloud.setVolume(_currentHandle!, v);
  }
  notifyListeners();
}
```

### 播放完成

```dart
Future<void> _handleComplete() async {
  _positionTimer?.cancel();
  isPlaying = false;
  position = Duration.zero;
  notifyListeners();
  
  // 触发自动下一曲
  onTrackComplete?.call();
}
```

## 音频数据

### FFT 和波形数据

```dart
AudioData? _audioData;
Float32List fftData = Float32List(256);
Float32List waveData = Float32List(256);

void _updateAudioData() {
  if (!_initialized || _audioData == null || !isPlaying) {
    fftData = Float32List(256);
    waveData = Float32List(256);
    return;
  }
  
  try {
    _audioData!.updateSamples();
    final samples = _audioData!.getAudioData();
    
    if (samples.length >= 512) {
      fftData = samples.sublist(0, 256);   // 频谱数据
      waveData = samples.sublist(256, 512); // 波形数据
    }
  } catch (e) {
    // 忽略错误
  }
}
```

数据说明：
- `fftData`: 256 个频谱点，范围 0.0-1.0
- `waveData`: 256 个波形采样点，范围 -1.0 到 1.0

## 本地播放

### 支持格式

| 格式 | 扩展名 | 说明 |
|------|--------|------|
| MP3 | `.mp3` | 常见压缩格式 |
| FLAC | `.flac` | 无损压缩 |
| WAV | `.wav` | 无压缩 PCM |
| OGG | `.ogg` | Vorbis 编码 |
| M4A | `.m4a` | AAC 编码 |

### 文件加载

```dart
final path = track.path;  // 本地文件路径
final source = await _soloud.loadFile(path);
```

注意事项：
- 路径必须是绝对路径
- 文件必须存在且可读
- 文件格式必须支持

### 错误处理

```dart
try {
  final source = await _soloud.loadFile(path);
  _currentHandle = await _soloud.play(source);
} catch (e) {
  playError = '播放失败: $e';
  isPlaying = false;
  notifyListeners();
}
```

## 在线播放

### URL 解析流程

```dart
Future<bool> resolveAndPlayTrackUrl(
  GdSearchTrack item, {
  String br = '999',
}) async {
  isResolvingUrl = true;
  playError = null;
  notifyListeners();
  
  try {
    // 1. 获取播放 URL
    final url = await _gdApi.getTrackUrl(
      source: item.source,
      id: item.id,
      br: br,
    );
    
    // 2. 创建 Track 对象
    final track = Track(
      id: Track.generateRemoteId(item.source, item.id),
      title: '${item.name} - ${item.artistText}',
      path: url.url,  // 播放 URL
      kind: TrackKind.remote,
      remoteSource: item.source,
      remoteTrackId: item.id,
      remoteLyricId: item.lyricId ?? item.id,
    );
    
    // 3. 播放
    await playTrack(track);
    return true;
  } catch (e) {
    playError = _friendlyPlayError(e, source: item.source, br: br);
    return false;
  } finally {
    isResolvingUrl = false;
    notifyListeners();
  }
}
```

### URL 加载

```dart
final source = await _soloud.loadUrl(url);
_currentHandle = await _soloud.play(source);
```

### 网络错误处理

```dart
String _friendlyPlayError(Object e, {
  required String source,
  required String br,
}) {
  if (e is GdMusicApiTimeout) {
    return '获取播放链接超时，请稍后重试';
  }
  if (e is GdMusicApiHttpException) {
    return '服务返回 ${e.statusCode}，请稍后重试';
  }
  if (e is FormatException) {
    return '服务响应解析失败';
  }
  return '播放失败：${e.toString()}';
}
```

## 播放队列

### 自动下一曲

```dart
// PlayerProvider 中的回调
VoidCallback? onTrackComplete;

// 在 app.dart 中注册
playerProvider.onTrackComplete = () {
  playlistProvider.next();
  if (playlistProvider.current != null) {
    playerProvider.playTrack(playlistProvider.current!);
  }
};
```

### 播放模式

由 `PlaylistProvider` 管理：

- **顺序播放**：按列表顺序
- **列表循环**：播放到末尾回到开头
- **随机播放**：随机选择下一首
- **单曲循环**：重复播放当前歌曲

## 性能优化

### 资源释放

```dart
@override
void dispose() {
  _positionTimer?.cancel();
  _audioData?.dispose();
  
  if (_currentSource != null) {
    _soloud.disposeSource(_currentSource!);
  }
  
  _soloud.deinit();
  super.dispose();
}
```

### 定时器优化

- 使用 50ms 间隔平衡性能和流畅度
- 仅在播放时更新
- 及时取消定时器

### 数据更新优化

```dart
// 避免过于频繁的 notifyListeners
if (position.inSeconds != _lastNotifiedSecond) {
  _lastNotifiedSecond = position.inSeconds;
  notifyListeners();
}
```

## 调试

### 日志输出

```dart
debugPrint('播放曲目: ${track.title}');
debugPrint('时长: ${duration.inSeconds}s');
debugPrint('当前位置: ${position.inSeconds}s');
```

### 状态检查

```dart
// 检查句柄有效性
bool isValid = _soloud.getIsValidVoiceHandle(handle);

// 检查播放状态
bool isPaused = _soloud.getPause(handle);

// 获取音量
double vol = _soloud.getVolume(handle);
```

## 常见问题

### 播放卡顿

**原因**：
- 网络不稳定（在线播放）
- CPU 占用高
- 磁盘 I/O 慢

**解决**：
- 降低 FFT 更新频率
- 优化 UI 渲染
- 使用更快的存储设备

### 音频无输出

**检查**：
- 音量是否为 0
- 系统音量设置
- 音频设备是否正常
- 句柄是否有效

### 播放延迟

**优化**：
- 预加载音频源
- 减少初始化时间
- 使用缓存

## 相关文档

- [架构设计](./Architecture.md)
- [API 文档](./API-Documentation.md)
- [可视化](./Visualizer.md)
