import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GdMusicApiException implements Exception {
  final String message;
  final Uri? uri;

  const GdMusicApiException(this.message, {this.uri});

  @override
  String toString() => uri == null ? message : '$message (${uri.toString()})';
}

class GdMusicApiHttpException extends GdMusicApiException {
  final int statusCode;

  const GdMusicApiHttpException({required this.statusCode, required Uri uri})
    : super('HTTP $statusCode', uri: uri);
}

class GdMusicApiTimeout extends GdMusicApiException {
  const GdMusicApiTimeout({required Uri uri})
    : super('Request timeout', uri: uri);
}

class GdSearchTrack {
  final String id;
  final String name;
  final List<String> artists;
  final String album;
  final String? picId;
  final String? lyricId;
  final String source;

  const GdSearchTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picId,
    required this.lyricId,
    required this.source,
  });

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
}

class GdTrackUrl {
  final String url;
  final int? br;
  final int? sizeKb;

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
  final String lyric;
  final String? tlyric;

  const GdLyric({required this.lyric, this.tlyric});

  factory GdLyric.fromJson(Map<String, dynamic> json) {
    return GdLyric(
      lyric: (json['lyric'] ?? '').toString(),
      tlyric: json['tlyric']?.toString(),
    );
  }

  /// 是否有翻译歌词
  bool get hasTranslation => tlyric != null && tlyric!.trim().isNotEmpty;
}

class GdPicUrl {
  final String url;

  const GdPicUrl({required this.url});

  factory GdPicUrl.fromJson(Map<String, dynamic> json) {
    return GdPicUrl(url: (json['url'] ?? '').toString());
  }
}

/// GD 音乐台 API 客户端
///
/// 支持配置 API 地址、超时时间等参数
class GdMusicApiClient {
  Uri _baseUri;
  final http.Client _client;
  Duration _timeout;

  /// 默认 API 地址
  static const String defaultBaseUrl = 'https://music-api.gdstudio.xyz/api.php';

  /// 默认超时时间
  static const Duration defaultTimeout = Duration(seconds: 12);

  GdMusicApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : _baseUri = Uri.parse(baseUrl ?? defaultBaseUrl),
      _client = client ?? http.Client(),
      _timeout = timeout ?? defaultTimeout;

  /// 获取当前 API 基础地址
  Uri get baseUri => _baseUri;

  /// 获取当前超时时间
  Duration get timeout => _timeout;

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
      return json
          .whereType<Map>()
          .map((e) => GdSearchTrack.fromJson(e.cast<String, dynamic>()))
          .where((t) => t.id.isNotEmpty && t.name.isNotEmpty)
          .toList(growable: false);
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
      return url;
    }

    throw const FormatException('Unexpected url response');
  }

  /// 获取歌词
  ///
  /// [source] 音乐源
  /// [id] 歌词 ID（通常与歌曲 ID 相同）
  Future<GdLyric> getLyric({required String source, required String id}) async {
    final json = await _getJson(
      _baseUri.replace(
        queryParameters: {'types': 'lyric', 'source': source, 'id': id},
      ),
    );

    if (json is Map<String, dynamic>) {
      return GdLyric.fromJson(json);
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

  Future<dynamic> _getJson(Uri uri) async {
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
      return jsonDecode(body);
    } catch (_) {
      throw FormatException(
        'Response is not JSON: ${body.substring(0, body.length > 200 ? 200 : body.length)}',
      );
    }
  }

  void close() {
    _client.close();
  }
}
