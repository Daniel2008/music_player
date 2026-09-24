import 'package:music_player/services/storage_service.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/providers/favorites_provider.dart';
import 'package:music_player/services/gd_music_api.dart';

GdSearchTrack _t(String id) => GdSearchTrack(
  id: id,
  name: 'Track $id',
  artists: const ['A'],
  album: 'Album',
  picId: 'p$id',
  lyricId: 'l$id',
  source: 'netease',
);

GdSearchTrack _sourceTrack(String source) => GdSearchTrack(
  id: 'same-id',
  name: source,
  artists: const ['A'],
  album: 'Album',
  picId: null,
  lyricId: 'same-lyric',
  source: source,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testStorageDirectory;

  setUp(() async {
    testStorageDirectory = await Directory.systemTemp.createTemp(
      'music_player_test_',
    );
    StorageService.instance.setTestDirectory(testStorageDirectory);
  });

  tearDown(() async {
    StorageService.instance.setTestDirectory(null);
    if (await testStorageDirectory.exists()) {
      await testStorageDirectory.delete(recursive: true);
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FavoritesProvider - 内存操作', () {
    test('toggleFavorite 添加与移除', () async {
      final provider = FavoritesProvider();
      await provider.ready;

      final t = _t('1');
      await provider.toggleFavorite(t);
      expect(provider.favorites.length, 1);
      expect(provider.isFavorite(t), isTrue);

      await provider.toggleFavorite(t);
      expect(provider.favorites, isEmpty);
      expect(provider.isFavorite(t), isFalse);
    });

    test('toggleFavorite 重复切换：第二次会移除', () async {
      final provider = FavoritesProvider();
      await provider.ready;

      final t = _t('1');
      await provider.toggleFavorite(t);
      expect(provider.favorites.length, 1);
      await provider.toggleFavorite(t);
      expect(provider.favorites.length, 0);
    });

    test('isFavorite O(1) 查询', () async {
      final provider = FavoritesProvider();
      await provider.ready;

      final t1 = _t('1');
      final t2 = _t('2');
      await provider.toggleFavorite(t1);
      expect(provider.isFavorite(t1), isTrue);
      expect(provider.isFavorite(t2), isFalse);
    });

    test('不同音乐源的同 ID 曲目可以同时收藏', () async {
      final provider = FavoritesProvider();
      await provider.ready;
      await provider.toggleFavorite(_sourceTrack('netease'));
      await provider.toggleFavorite(_sourceTrack('kuwo'));

      expect(provider.favorites, hasLength(2));
      expect(provider.isFavorite(_sourceTrack('netease')), isTrue);
      expect(provider.isFavorite(_sourceTrack('kuwo')), isTrue);
    });
  });
}
