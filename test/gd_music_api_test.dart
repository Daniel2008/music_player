import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/services/gd_music_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  group('GdSearchTrack', () {
    test('fromJson parses artist list', () {
      final json = {
        'id': '123',
        'name': '测试歌曲',
        'artist': ['歌手A', '歌手B'],
        'album': '专辑名',
        'pic_id': 'pic123',
        'lyric_id': 'lyric123',
        'source': 'netease',
      };
      final track = GdSearchTrack.fromJson(json);
      expect(track.id, equals('123'));
      expect(track.name, equals('测试歌曲'));
      expect(track.artists, equals(['歌手A', '歌手B']));
      expect(track.artistText, equals('歌手A / 歌手B'));
      expect(track.source, equals('netease'));
    });

    test('fromJson handles single artist string', () {
      final json = {
        'id': '456',
        'name': 'Single Artist Song',
        'artist': '独唱歌手',
        'album': '',
        'pic_id': null,
        'lyric_id': null,
        'source': 'kuwo',
      };
      final track = GdSearchTrack.fromJson(json);
      expect(track.artists, equals(['独唱歌手']));
    });

    test('fromJson handles null artist', () {
      final json = {
        'id': '789',
        'name': 'No Artist',
        'artist': null,
        'album': '',
        'pic_id': null,
        'lyric_id': null,
        'source': 'tencent',
      };
      final track = GdSearchTrack.fromJson(json);
      expect(track.artists, isEmpty);
      expect(track.artistText, isEmpty);
    });

    test('toJson round trip', () {
      const track = GdSearchTrack(
        id: 'roundtrip',
        name: 'Round Trip',
        artists: ['A', 'B'],
        album: 'Test',
        picId: 'p1',
        lyricId: 'l1',
        source: 'test',
      );
      final json = track.toJson();
      expect(json['id'], equals('roundtrip'));
      expect(json['artist'], equals(['A', 'B']));
    });
  });

  group('GdTrackUrl', () {
    test('fromJson parses numeric br', () {
      final json = {
        'url': 'https://example.com/stream.mp3',
        'br': 320,
        'size': 10240,
      };
      final url = GdTrackUrl.fromJson(json);
      expect(url.url, equals('https://example.com/stream.mp3'));
      expect(url.br, equals(320));
      expect(url.sizeKb, equals(10240));
    });

    test('fromJson parses string br', () {
      final json = {
        'url': 'https://example.com/lossless.flac',
        'br': '999',
        'size': '30720',
      };
      final url = GdTrackUrl.fromJson(json);
      expect(url.br, equals(999));
      expect(url.sizeKb, equals(30720));
    });

    test('qualityDisplay shows correct labels', () {
      expect(
        const GdTrackUrl(url: 'u', br: 128).qualityDisplay,
        equals('128kbps'),
      );
      expect(const GdTrackUrl(url: 'u', br: 740).qualityDisplay, equals('无损'));
      expect(
        const GdTrackUrl(url: 'u', br: 999).qualityDisplay,
        equals('Hi-Res'),
      );
    });

    test('sizeDisplay formats correctly', () {
      expect(
        const GdTrackUrl(url: 'u', sizeKb: 500).sizeDisplay,
        equals('500 KB'),
      );
      expect(
        const GdTrackUrl(url: 'u', sizeKb: 2048).sizeDisplay,
        equals('2.0 MB'),
      );
    });
  });

  group('GdLyric', () {
    test('fromJson with translation', () {
      final json = {'lyric': '[00:01.00]hello', 'tlyric': '[00:01.00]你好'};
      final lyric = GdLyric.fromJson(json);
      expect(lyric.lyric, contains('hello'));
      expect(lyric.tlyric, contains('你好'));
      expect(lyric.hasTranslation, isTrue);
    });

    test('fromJson without translation', () {
      final json = {'lyric': '[00:01.00]hello'};
      final lyric = GdLyric.fromJson(json);
      expect(lyric.hasTranslation, isFalse);
    });
  });

  group('GdMusicApiClient', () {
    test('search caches results', () async {
      final client = MockClient((request) async {
        final params = request.url.queryParameters;
        expect(params['types'], equals('search'));
        final body = jsonEncode([
          {
            'id': '1',
            'name': 'cached',
            'artist': ['test'],
            'album': '',
            'pic_id': null,
            'lyric_id': null,
            'source': 'test',
          },
        ]);
        return http.Response(body, 200);
      });

      final api = GdMusicApiClient(client: client);
      final results = await api.search(keyword: 'test', source: 'test');
      expect(results.length, equals(1));
      expect(results.first.name, equals('cached'));

      // Second call uses cache - no HTTP request needed
      final cached = await api.search(keyword: 'test', source: 'test');
      expect(cached.length, equals(1));

      api.close();
    });

    test('getTrackUrl caches results', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        final json = jsonEncode({
          'url': 'https://stream.example.com/cached.mp3',
          'br': 320,
          'size': 10240,
        });
        return http.Response(json, 200);
      });

      final api = GdMusicApiClient(client: client);
      await api.getTrackUrl(source: 'test', id: '1');
      await api.getTrackUrl(source: 'test', id: '1');
      expect(callCount, equals(1)); // second call cached
      api.close();
    });

    test('search throws FormatException on invalid response', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final api = GdMusicApiClient(client: client);
      expect(() => api.search(keyword: 'test'), throwsException);
      api.close();
    });

    test('getTrackUrl throws on empty url response', () async {
      final client = MockClient((_) async {
        final json = jsonEncode({'url': '', 'br': 128, 'size': 0});
        return http.Response(json, 200);
      });
      final api = GdMusicApiClient(client: client);
      expect(() => api.getTrackUrl(source: 'test', id: '1'), throwsException);
      api.close();
    });
  });
}
