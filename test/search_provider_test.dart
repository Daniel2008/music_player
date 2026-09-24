import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/providers/search_provider.dart';
import 'package:music_player/services/gd_music_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SearchProvider', () {
    test('初始状态为空', () {
      final provider = SearchProvider(gdApi: GdMusicApiClient());
      expect(provider.searchResults, isEmpty);
      expect(provider.isSearching, isFalse);
      expect(provider.searchError, isNull);
    });

    test('空关键词不发起搜索', () async {
      final provider = SearchProvider(gdApi: GdMusicApiClient());
      await provider.searchOnline('   ');
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults, isEmpty);
    });

    test('clearSearch 重置状态', () {
      final provider = SearchProvider(gdApi: GdMusicApiClient());
      provider.clearSearch();
      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNull);
      expect(provider.isSearching, isFalse);
    });

    test('clearSearch 会使旧请求结果失效', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          '[{"id":"1","name":"old","artist":["A"],"source":"netease"}]',
          200,
        );
      });
      final provider = SearchProvider(gdApi: GdMusicApiClient(client: client));

      final pending = provider.searchOnline('old');
      provider.clearSearch();
      await pending;

      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNull);
      expect(provider.isSearching, isFalse);
    });

    test('直接搜索空关键词也会使旧请求结果失效', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          '[{"id":"1","name":"old","artist":["A"],"source":"netease"}]',
          200,
        );
      });
      final provider = SearchProvider(gdApi: GdMusicApiClient(client: client));

      final pending = provider.searchOnline('old');
      await provider.searchOnline('   ');
      await pending;

      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNull);
      expect(provider.isSearching, isFalse);
    });
  });
}
