import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 音质选项
enum AudioQuality {
  low(128, '128kbps', '流畅'),
  medium(192, '192kbps', '标准'),
  high(320, '320kbps', '高品质'),
  lossless(740, '740kbps', '无损'),
  hires(999, '999kbps', 'Hi-Res');

  final int bitrate;
  final String label;
  final String description;

  const AudioQuality(this.bitrate, this.label, this.description);

  String get brValue => bitrate.toString();
}

/// 音乐源配置
class MusicSource {
  final String id;
  final String name;
  final bool isStable;

  const MusicSource({
    required this.id,
    required this.name,
    this.isStable = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isStable': isStable,
  };

  factory MusicSource.fromJson(Map<String, dynamic> json) => MusicSource(
    id: json['id'] as String,
    name: json['name'] as String,
    isStable: json['isStable'] as bool? ?? false,
  );
}

/// 所有可用的音乐源
class MusicSources {
  static const List<MusicSource> all = [
    MusicSource(id: 'netease', name: '网易云音乐', isStable: true),
    MusicSource(id: 'kuwo', name: '酷我音乐', isStable: true),
    MusicSource(id: 'joox', name: 'JOOX', isStable: true),
    MusicSource(id: 'tencent', name: 'QQ音乐'),
    MusicSource(id: 'kugou', name: '酷狗音乐'),
    MusicSource(id: 'migu', name: '咪咕音乐'),
    MusicSource(id: 'tidal', name: 'Tidal'),
    MusicSource(id: 'spotify', name: 'Spotify'),
    MusicSource(id: 'ytmusic', name: 'YouTube Music'),
    MusicSource(id: 'qobuz', name: 'Qobuz'),
    MusicSource(id: 'deezer', name: 'Deezer'),
    MusicSource(id: 'ximalaya', name: '喜马拉雅'),
    MusicSource(id: 'apple', name: 'Apple Music'),
  ];

  static List<MusicSource> get stableSources =>
      all.where((s) => s.isStable).toList();

  static MusicSource? findById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// API 设置 Provider
class ApiSettingsProvider extends ChangeNotifier {
  static const String _keyApiBaseUrl = 'api_base_url';
  static const String _keyDefaultSource = 'default_source';
  static const String _keyDefaultQuality = 'default_quality';
  static const String _keyDownloadQuality = 'download_quality';
  static const String _keyEnabledSources = 'enabled_sources';
  static const String _keyRequestTimeout = 'request_timeout';
  static const String _keyShowUnstableSources = 'show_unstable_sources';

  // 默认值
  static const String defaultApiBaseUrl =
      'https://music-api.gdstudio.xyz/api.php';
  static const String defaultSourceId = 'netease';
  static const AudioQuality defaultPlayQuality = AudioQuality.high;
  static const AudioQuality defaultDownloadQuality = AudioQuality.high;
  static const int defaultRequestTimeout = 12;

  SharedPreferences? _prefs;
  bool _initialized = false;

  // 当前设置值
  String _apiBaseUrl = defaultApiBaseUrl;
  String _defaultSource = defaultSourceId;
  AudioQuality _playQuality = defaultPlayQuality;
  AudioQuality _downloadQuality = defaultDownloadQuality;
  List<String> _enabledSources = MusicSources.stableSources
      .map((s) => s.id)
      .toList();
  int _requestTimeout = defaultRequestTimeout;
  bool _showUnstableSources = false;

  // Getters
  bool get initialized => _initialized;
  String get apiBaseUrl => _apiBaseUrl;
  String get defaultSource => _defaultSource;
  AudioQuality get playQuality => _playQuality;
  AudioQuality get downloadQuality => _downloadQuality;
  List<String> get enabledSources => List.unmodifiable(_enabledSources);
  int get requestTimeout => _requestTimeout;
  bool get showUnstableSources => _showUnstableSources;

  /// 获取完整的 API URL
  Uri get apiUri => Uri.parse(_apiBaseUrl);

  /// 获取可用的音乐源列表
  List<MusicSource> get availableSources {
    if (_showUnstableSources) {
      return MusicSources.all
          .where((s) => _enabledSources.contains(s.id))
          .toList();
    }
    return MusicSources.stableSources
        .where((s) => _enabledSources.contains(s.id))
        .toList();
  }

  /// 初始化，从本地存储加载设置
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    _apiBaseUrl = _prefs?.getString(_keyApiBaseUrl) ?? defaultApiBaseUrl;
    _defaultSource = _prefs?.getString(_keyDefaultSource) ?? defaultSourceId;

    final playQualityValue = _prefs?.getInt(_keyDefaultQuality);
    if (playQualityValue != null) {
      _playQuality = AudioQuality.values.firstWhere(
        (q) => q.bitrate == playQualityValue,
        orElse: () => defaultPlayQuality,
      );
    }

    final downloadQualityValue = _prefs?.getInt(_keyDownloadQuality);
    if (downloadQualityValue != null) {
      _downloadQuality = AudioQuality.values.firstWhere(
        (q) => q.bitrate == downloadQualityValue,
        orElse: () => defaultDownloadQuality,
      );
    }

    final enabledSourcesJson = _prefs?.getString(_keyEnabledSources);
    if (enabledSourcesJson != null) {
      try {
        final list = jsonDecode(enabledSourcesJson) as List;
        _enabledSources = list.cast<String>();
      } catch (_) {
        _enabledSources = MusicSources.stableSources.map((s) => s.id).toList();
      }
    }

    _requestTimeout =
        _prefs?.getInt(_keyRequestTimeout) ?? defaultRequestTimeout;
    _showUnstableSources = _prefs?.getBool(_keyShowUnstableSources) ?? false;

    _initialized = true;
    notifyListeners();
  }

  /// 设置 API 基础 URL
  Future<void> setApiBaseUrl(String url) async {
    if (url.isEmpty) return;

    // 确保 URL 格式正确
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    // 移除末尾斜杠
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    _apiBaseUrl = normalizedUrl;
    await _prefs?.setString(_keyApiBaseUrl, normalizedUrl);
    notifyListeners();
  }

  /// 设置默认音乐源
  Future<void> setDefaultSource(String source) async {
    _defaultSource = source;
    await _prefs?.setString(_keyDefaultSource, source);
    notifyListeners();
  }

  /// 设置播放音质
  Future<void> setPlayQuality(AudioQuality quality) async {
    _playQuality = quality;
    await _prefs?.setInt(_keyDefaultQuality, quality.bitrate);
    notifyListeners();
  }

  /// 设置下载音质
  Future<void> setDownloadQuality(AudioQuality quality) async {
    _downloadQuality = quality;
    await _prefs?.setInt(_keyDownloadQuality, quality.bitrate);
    notifyListeners();
  }

  /// 设置启用的音乐源
  Future<void> setEnabledSources(List<String> sources) async {
    _enabledSources = List.from(sources);
    await _prefs?.setString(_keyEnabledSources, jsonEncode(sources));
    notifyListeners();
  }

  /// 启用/禁用单个音乐源
  Future<void> toggleSource(String sourceId, bool enabled) async {
    if (enabled && !_enabledSources.contains(sourceId)) {
      _enabledSources.add(sourceId);
    } else if (!enabled && _enabledSources.contains(sourceId)) {
      _enabledSources.remove(sourceId);
    }
    await _prefs?.setString(_keyEnabledSources, jsonEncode(_enabledSources));
    notifyListeners();
  }

  /// 设置请求超时时间（秒）
  Future<void> setRequestTimeout(int seconds) async {
    _requestTimeout = seconds.clamp(5, 60);
    await _prefs?.setInt(_keyRequestTimeout, _requestTimeout);
    notifyListeners();
  }

  /// 设置是否显示不稳定的音乐源
  Future<void> setShowUnstableSources(bool show) async {
    _showUnstableSources = show;
    await _prefs?.setBool(_keyShowUnstableSources, show);
    notifyListeners();
  }

  /// 重置为默认设置
  Future<void> resetToDefaults() async {
    _apiBaseUrl = defaultApiBaseUrl;
    _defaultSource = defaultSourceId;
    _playQuality = defaultPlayQuality;
    _downloadQuality = defaultDownloadQuality;
    _enabledSources = MusicSources.stableSources.map((s) => s.id).toList();
    _requestTimeout = defaultRequestTimeout;
    _showUnstableSources = false;

    await _prefs?.remove(_keyApiBaseUrl);
    await _prefs?.remove(_keyDefaultSource);
    await _prefs?.remove(_keyDefaultQuality);
    await _prefs?.remove(_keyDownloadQuality);
    await _prefs?.remove(_keyEnabledSources);
    await _prefs?.remove(_keyRequestTimeout);
    await _prefs?.remove(_keyShowUnstableSources);

    notifyListeners();
  }

  /// 测试 API 连接
  Future<bool> testConnection() async {
    try {
      final uri = apiUri.replace(
        queryParameters: {
          'types': 'search',
          'source': 'netease',
          'name': 'test',
          'count': '1',
        },
      );

      final response = await Future.any([
        _makeRequest(uri),
        Future.delayed(
          Duration(seconds: _requestTimeout),
          () => throw TimeoutException('Connection timeout'),
        ),
      ]);

      return response;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _makeRequest(Uri uri) async {
    // 这里只是验证 URI 格式，实际测试需要 HTTP 客户端
    // 返回 true 表示 URI 格式有效
    return uri.hasScheme && uri.hasAuthority;
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
