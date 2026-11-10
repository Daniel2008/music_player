import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/services/gd_music_api.dart';
import 'package:music_player/services/lyric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('清理磁盘缓存并更新歌词版本，同时保留用户同目录歌词', () async {
    final dir = await Directory.systemTemp.createTemp('lyric_cache_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
    final api = GdMusicApiClient();
    final service = LyricService(api);
    addTearDown(() async {
      api.close();
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      await dir.delete(recursive: true);
    });
    await File('${dir.path}/local_123.lrc').writeAsString('cached');
    await File('${dir.path}/gd_netease_456.lrc').writeAsString('remote');
    final original = File('${dir.path}/song.lrc');
    await original.writeAsString('user lyric');
    service.localLyricPaths['123'] = '${dir.path}/local_123.lrc';
    var notifications = 0;
    service.onLyricChanged = () => notifications++;
    await service.clearCachedLyrics();
    expect(await File('${dir.path}/local_123.lrc').exists(), isFalse);
    expect(await File('${dir.path}/gd_netease_456.lrc').exists(), isFalse);
    expect(await original.readAsString(), 'user lyric');
    expect(service.localLyricPaths, isEmpty);
    expect(service.lyricRevision, 1);
    expect(notifications, 1);
    expect(
      await service.findExistingLyricPath(
        Track(id: '123', title: 'song', path: '${dir.path}/song.mp3'),
      ),
      original.path,
    );
  });
}
