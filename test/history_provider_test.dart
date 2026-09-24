import 'package:music_player/services/storage_service.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/providers/history_provider.dart';

Track _t(String id) => Track(id: id, title: 'Track $id', path: '/tmp/$id.mp3');

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
  group('HistoryProvider - 内存操作', () {
    test('addTrack 添加到列表头', () async {
      final provider = HistoryProvider();
      await provider.ready;

      provider.addTrack(_t('1'));
      provider.addTrack(_t('2'));
      expect(provider.history.first.id, '2');
      expect(provider.history[1].id, '1');
    });

    test('addTrack 重复 ID 时上浮到顶部', () async {
      final provider = HistoryProvider();
      await provider.ready;

      provider.addTrack(_t('1'));
      provider.addTrack(_t('2'));
      provider.addTrack(_t('1'));
      expect(provider.history.first.id, '1');
      expect(provider.history.length, 2);
    });

    test('超过 _maxHistoryItems 时丢弃最旧', () async {
      final provider = HistoryProvider();
      await provider.ready;

      for (var i = 0; i < 105; i++) {
        provider.addTrack(_t('$i'));
      }
      expect(provider.history.length, 100);
    });

    test('removeTrack 移除指定索引', () async {
      final provider = HistoryProvider();
      await provider.ready;

      provider.addTrack(_t('1'));
      provider.addTrack(_t('2'));
      provider.removeTrack(0);
      expect(provider.history.length, 1);
      expect(provider.history[0].id, '1');
    });

    test('clear 清空所有', () async {
      final provider = HistoryProvider();
      await provider.ready;

      provider.addTrack(_t('1'));
      provider.addTrack(_t('2'));
      provider.clear();
      expect(provider.history, isEmpty);
    });

    test('contains 检查存在', () async {
      final provider = HistoryProvider();
      await provider.ready;

      provider.addTrack(_t('1'));
      expect(provider.contains('1'), isTrue);
      expect(provider.contains('2'), isFalse);
    });
  });
}
