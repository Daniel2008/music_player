import 'dart:io';
// Widget tests for Music Player
//
// 完整的 AppRoot 测试需要 SoLoud 等原生绑定，所以这里测试纯 Flutter 组件
// （独立、不依赖 Provider/平台绑定）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/playlist.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/providers/playlist_provider.dart';
import 'package:music_player/services/gd_music_api.dart';
import 'package:music_player/ui/widgets/visualizer/visualizer_style.dart';
import 'package:music_player/services/storage_service.dart';
import 'package:provider/provider.dart';

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
  group('VisualizerStyle', () {
    test('所有 style 都有 displayName', () {
      for (final s in VisualizerStyle.values) {
        expect(s.displayName, isNotEmpty);
      }
    });

    test('所有 style 都有 icon', () {
      for (final s in VisualizerStyle.values) {
        expect(s.icon, isNotNull);
      }
    });

    test('所有 style 都有合理的性能配置', () {
      for (final style in VisualizerStyle.values) {
        expect(style.recommendedBarCount(1920), inInclusiveRange(20, 64));
        if (style.isHeavy) {
          expect(style.recommendedBarCount(1920), lessThanOrEqualTo(48));
        }
      }
    });
  });

  testWidgets('PlaylistProvider 集成到 widget', (tester) async {
    final provider = PlaylistProvider();
    provider.addTrack(Track(id: 'a', title: 'A', path: '/a.mp3'));
    provider.addTrack(Track(id: 'b', title: 'B', path: '/b.mp3'));

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: Scaffold(
            body: Consumer<PlaylistProvider>(
              builder: (ctx, p, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('count:${p.tracks.length}'),
                  Text('current:${p.current?.title ?? "none"}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('count:2'), findsOneWidget);
    // Playlist.currentIndex 默认 0，所以 current 是 tracks[0]
    expect(find.text('current:A'), findsOneWidget);

    // 清理：释放 debounce timer 以避免 testWidgets 报错
    provider.dispose();
  });

  test('GdSearchTrack JSON round-trip', () {
    const t = GdSearchTrack(
      id: 'x',
      name: 'X',
      artists: ['A1', 'A2'],
      album: 'Al',
      picId: 'p',
      lyricId: 'l',
      source: 'netease',
    );
    final json = t.toJson();
    final restored = GdSearchTrack.fromJson(json);
    expect(restored.id, t.id);
    expect(restored.name, t.name);
    expect(restored.artists, t.artists);
    expect(restored.album, t.album);
  });

  test('Playlist tracks 不会超过 _maxTracks', () {
    final provider = PlaylistProvider();
    for (var i = 0; i < 510; i++) {
      provider.addTrack(Track(id: '$i', title: 'T$i', path: '/$i.mp3'));
    }
    expect(provider.tracks.length, 500);
  });
}

// Suppress unused warning for Playlist import (used in test context)
// ignore: unused_element
void _ensureImported() => Playlist(name: 'x');
