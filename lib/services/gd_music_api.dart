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
}

class GdMusicApiClient {
  final Uri baseUri;
  final http.Client _client;

  GdMusicApiClient({Uri? baseUri, http.Client? client})
    : baseUri = baseUri ?? Uri.parse('https://music-api.gdstudio.xyz/api.php'),
      _client = client ?? http.Client();

  Future<List<GdSearchTrack>> search({
    required String keyword,
    String source = 'netease',
    int count = 20,
    int page = 1,
  }) async {
    final json = await _getJson(
      baseUri.replace(
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

  Future<GdTrackUrl> getTrackUrl({
    required String source,
    required String id,
    String br = '999',
  }) async {
    final json = await _getJson(
      baseUri.replace(
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

  Future<GdLyric> getLyric({required String source, required String id}) async {
    final json = await _getJson(
      baseUri.replace(
        queryParameters: {'types': 'lyric', 'source': source, 'id': id},
      ),
    );

    if (json is Map<String, dynamic>) {
      return GdLyric.fromJson(json);
    }

    throw const FormatException('Unexpected lyric response');
  }

  Future<dynamic> _getJson(Uri uri) async {
    http.Response resp;
    try {
      resp = await _client.get(uri).timeout(const Duration(seconds: 12));
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
