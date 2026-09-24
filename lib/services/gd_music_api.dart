import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GdMusicApiException implements Exception {
  const GdMusicApiException(this.message, {this.uri});
  final String message;
  final Uri? uri;

  @override
  String toString() => uri == null ? message : '$message (${uri.toString()})';
}

class GdMusicApiHttpException extends GdMusicApiException {
  const GdMusicApiHttpException({required this.statusCode, required Uri uri})
    : super('HTTP $statusCode', uri: uri);
  final int statusCode;
}

class GdMusicApiTimeout extends GdMusicApiException {
  const GdMusicApiTimeout({required Uri uri})
    : super('Request timeout', uri: uri);
}

class GdMusicApiCircuitOpen extends GdMusicApiException {
  const GdMusicApiCircuitOpen() : super('客户端处于熔断状态，稍后重试');
}

class GdSearchTrack {
  const GdSearchTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picId,
    required this.lyricId,
    required this.source,
  });

  factory GdSearchTrack.fromJson(Map<String, dynamic> json) {
    final artistsRaw = json['artist'];
    final artists = <String>[];
    if (artistsRaw is List) {
      for (final a in artistsRaw) {
        final s = a?.toString().trim();
        if (s != null && s.isNotEmpty) artists.add(s);
      }
    } else if (artistsRaw != null) {
      final s = artistsRaw.toString().trim();
      if (s.isNotEmpty) artists.add(s);
    }

    return GdSearchTrack(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      artists: artists,
      album: (json['album'] ?? '').toString(),
      picId: json['pic_id']?.toString(),
      lyricId: json['lyric_id']?.toString(),
      source: (json['source'] ?? '').toString(),
    );
  }
  final String id;
  final String name;
  final List<String> artists;
  final String album;
  final String? picId;
  final String? lyricId;
  final String source;

  String get artistText => artists.join(' / ');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artists,
      'album': album,
      'pic_id': picId,
      'lyric_id': lyricId,
      'source': source,
    };
  }
}

class GdTrackUrl {
  const GdTrackUrl({required this.url, this.br, this.sizeKb});

  factory GdTrackUrl.fromJson(Map<String, dynamic> json) {
    return GdTrackUrl(
      url: (json['url'] ?? '').toString(),
      br: json['br'] is num
          ? (json['br'] as num).toInt()
          : int.tryParse('${json['br']}'),
      sizeKb: json['size'] is num
          ? (json['size'] as num).toInt()
          : int.tryParse('${json['size']}'),
    );
  }
  final String url;
  final int? br;
  final int? sizeKb;

  /// 获取文件大小的友好显示
  String get sizeDisplay {
    if (sizeKb == null) return '未知大小';
    if (sizeKb! < 1024) return '$sizeKb KB';
    final mb = sizeKb! / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// 获取音质的友好显示
  String get qualityDisplay {
    if (br == null) return '未知音质';
    if (br! >= 999) return 'Hi-Res';
    if (br! >= 740) return '无损';
    return '${br}kbps';
  }
}

class GdLyric {
  const GdLyric({required this.lyric, this.tlyric});

  factory GdLyric.fromJson(Map<String, dynamic> json) {
    return GdLyric(
      lyric: (json['lyric'] ?? '').toString(),
      tlyric: json['tlyric']?.toString(),
    );
  }
  final String lyric;
  final String? tlyric;

  /// 是否有翻译歌词
  bool get hasTranslation => tlyric != null && tlyric!.trim().isNotEmpty;
}

class GdPicUrl {
  const GdPicUrl({required this.url});

  factory GdPicUrl.fromJson(Map<String, dynamic> json) {
    return GdPicUrl(url: (json['url'] ?? '').toString());
  }
  final String url;
}

/// 简单的内存缓存（LRU + TTL）
class _ApiCache<K, V> {
  _ApiCache({this.maxSize = 50, this.ttl = const Duration(minutes: 2)});
  final int maxSize;
  final Duration ttl;
  final LinkedHashMap<K, _CacheEntry<V>> _data = LinkedHashMap();

  V? get(K key) {
    final entry = _data[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.time) > ttl) {
      _data.remove(key);
      return null;
    }
    _data.remove(key); // re-insert for LRU ordering
    _data[key] = entry;
    return entry.value;
  }

  void set(K key, V value) {
    _data.remove(key);
    if (_data.length >= maxSize) {
      _data.remove(_data.keys.first);
    }
    _data[key] = _CacheEntry(value, DateTime.now());
  }

  void clear() => _data.clear();
}

class _CacheEntry<V> {
  const _CacheEntry(this.value, this.time);
  final V value;
  final DateTime time;
}

/// GD 音乐台 API 客户端
///
/// 支持配置 API 地址、超时时间等参数
class GdMusicApiClient {
  GdMusicApiClient({
    String? baseUrl,
    http.Client? client,
    Duration? timeout,
    bool Function()? isCircuitBroken,
  }) : _baseUri = Uri.parse(baseUrl ?? defaultBaseUrl),
       _client = client ?? http.Client(),
       _timeout = timeout ?? defaultTimeout,
       _isCircuitBroken = isCircuitBroken;
  Uri _baseUri;
  final http.Client _client;
  Duration _timeout;
  bool Function()? _isCircuitBroken;

  // 内存缓存
  final _searchCache = _ApiCache<String, List<GdSearchTrack>>(
    maxSize: 15,
    ttl: const Duration(minutes: 2),
  );
  final _urlCache = _ApiCache<String, GdTrackUrl>(
    maxSize: 50,
    ttl: const Duration(minutes: 5),
  );
  final _lyricCache = _ApiCache<String, GdLyric>(
    maxSize: 50,
    ttl: const Duration(minutes: 5),
  );

  /// 默认 API 地址
  static const String defaultBaseUrl = 'https://music-api.gdstudio.xyz/api.php';

  /// 默认超时时间
  static const Duration defaultTimeout = Duration(seconds: 12);

  /// 获取当前 API 基础地址
  Uri get baseUri => _baseUri;

  /// 获取当前超时时间
  Duration get timeout => _timeout;

  /// 绑定应用级网络熔断状态。
  void setCircuitBreaker(bool Function()? callback) {
    _isCircuitBroken = callback;
  }

  /// 更新 API 基础地址
  void updateBaseUrl(String url) {
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    _baseUri = Uri.parse(normalizedUrl);
    _searchCache.clear();
    _urlCache.clear();
    _lyricCache.clear();
  }

  /// 更新超时时间
  void updateTimeout(Duration timeout) {
    _timeout = timeout;
  }

  /// 更新超时时间（秒）
  void updateTimeoutSeconds(int seconds) {
    _timeout = Duration(seconds: seconds.clamp(5, 60));
  }

  /// 构建封面图片 URL
  ///
  /// 根据 [picId] 和 [source] 返回最佳的封面图片 URL
  /// [size] 可选 300（小图）或 500（大图）
  String? buildCoverUrl(String? picId, String source, {int size = 300}) {
    if (picId == null || picId.isEmpty) return null;

    // 使用 API 的图片接口
    return _baseUri
        .replace(
          queryParameters: {
            'types': 'pic',
            'source': source,
            'id': picId,
            'size': size.toString(),
          },
        )
        .toString();
  }

  /// 获取封面图片直接链接
  Future<String?> getCoverUrl({
    required String source,
    required String picId,
    int size = 300,
  }) async {
    try {
      final json = await _getJson(
        _baseUri.replace(
          queryParameters: {
            'types': 'pic',
            'source': source,
            'id': picId,
            'size': size.toString(),
          },
        ),
      );

      if (json is Map<String, dynamic>) {
        final picUrl = GdPicUrl.fromJson(json);
        return picUrl.url.isNotEmpty ? picUrl.url : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 搜索歌曲
  ///
  /// [keyword] 搜索关键词，可以是歌曲名、歌手名或专辑名
  /// [source] 音乐源，默认为 netease
  /// [count] 每页结果数量，默认为 20
  /// [page] 页码，默认为 1
  Future<List<GdSearchTrack>> search({
    required String keyword,
    String source = 'netease',
    int count = 20,
    int page = 1,
  }) async {
    final cacheKey = '$keyword|$source|$count|$page';
    final cached = _searchCache.get(cacheKey);
    if (cached != null) return cached;

    final json = await _getJson(
      _baseUri.replace(
        queryParameters: {
          'types': 'search',
          'source': source,
          'name': keyword,
          'count': '$count',
          'pages': '$page',
        },
      ),
    );

    if (json is List) {
      final result = json
          .whereType<Map>()
          .map((e) => GdSearchTrack.fromJson(e.cast<String, dynamic>()))
          .where((t) => t.id.isNotEmpty && t.name.isNotEmpty)
          .toList(growable: false);
      _searchCache.set(cacheKey, result);
      return result;
    }

    throw const FormatException('Unexpected search response');
  }

  /// 搜索专辑中的歌曲
  ///
  /// [keyword] 专辑名或专辑 ID
  /// [source] 音乐源，会自动添加 _album 后缀
  Future<List<GdSearchTrack>> searchAlbum({
    required String keyword,
    String source = 'netease',
    int count = 50,
  }) async {
    return search(
      keyword: keyword,
      source: '${source}_album',
      count: count,
      page: 1,
    );
  }

  /// 获取歌曲播放链接
  ///
  /// [source] 音乐源
  /// [id] 歌曲 ID
  /// [br] 音质：128、192、320、740（无损）、999（Hi-Res），默认为 999
  Future<GdTrackUrl> getTrackUrl({
    required String source,
    required String id,
    String br = '999',
  }) async {
    final cacheKey = '$source|$id|$br';
    final cached = _urlCache.get(cacheKey);
    if (cached != null) return cached;

    final json = await _getJson(
      _baseUri.replace(
        queryParameters: {'types': 'url', 'source': source, 'id': id, 'br': br},
      ),
    );

    if (json is Map<String, dynamic>) {
      final url = GdTrackUrl.fromJson(json);
      if (url.url.isEmpty) {
        throw const FormatException('Empty url in response');
      }
      _urlCache.set(cacheKey, url);
      return url;
    }

    throw const FormatException('Unexpected url response');
  }

  /// 获取歌词
  ///
  /// [source] 音乐源
  /// [id] 歌词 ID（通常与歌曲 ID 相同）
  Future<GdLyric> getLyric({required String source, required String id}) async {
    final cacheKey = '$source|$id';
    final cached = _lyricCache.get(cacheKey);
    if (cached != null) return cached;

    final json = await _getJson(
      _baseUri.replace(
        queryParameters: {'types': 'lyric', 'source': source, 'id': id},
      ),
    );

    if (json is Map<String, dynamic>) {
      final lyric = GdLyric.fromJson(json);
      _lyricCache.set(cacheKey, lyric);
      return lyric;
    }

    throw const FormatException('Unexpected lyric response');
  }

  /// 测试 API 连接
  ///
  /// 返回 true 表示连接成功
  Future<bool> testConnection() async {
    try {
      final results = await search(
        keyword: 'test',
        source: 'netease',
        count: 1,
      );
      return results.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 获取 API 状态信息
  Future<Map<String, dynamic>> getApiInfo() async {
    return {
      'baseUrl': _baseUri.toString(),
      'timeout': _timeout.inSeconds,
      'connected': await testConnection(),
    };
  }

  Future<dynamic> _getJson(Uri uri, {int maxRetries = 2}) async {
    if (_isCircuitBroken?.call() ?? false) {
      throw const GdMusicApiCircuitOpen();
    }
    int attempt = 0;
    while (true) {
      try {
        http.Response resp;
        try {
          resp = await _client.get(uri).timeout(_timeout);
        } on TimeoutException {
          throw GdMusicApiTimeout(uri: uri);
        } on http.ClientException catch (e) {
          throw GdMusicApiException(e.message, uri: uri);
        }

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw GdMusicApiHttpException(statusCode: resp.statusCode, uri: uri);
        }

        final body = resp.body.trim();
        try {
          final decoded = jsonDecode(body);
          onRequestSuccess?.call();
          return decoded;
        } catch (_) {
          // 格式解析错误不重试（服务器返回了非 JSON，重试也没用）
          throw FormatException(
            'Response is not JSON: ${body.substring(0, body.length > 200 ? 200 : body.length)}',
          );
        }
      } on FormatException {
        rethrow; // 格式错误直接抛出
      } catch (e) {
        if (!_isRetryable(e)) rethrow;
        attempt++;
        onRequestFailed?.call();
        if (attempt > maxRetries) rethrow;
        // 指数退避：第1次等 500ms，第2次等 1000ms
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  bool _isRetryable(Object error) {
    if (error is GdMusicApiCircuitOpen) return false;
    if (error is GdMusicApiHttpException) {
      return error.statusCode >= 500;
    }
    return error is GdMusicApiTimeout || error is GdMusicApiException;
  }

  void close() {
    _client.close();
  }

  /// 通知调用方请求失败（用于熔断）
  void Function()? onRequestFailed;
  void Function()? onRequestSuccess;
}
