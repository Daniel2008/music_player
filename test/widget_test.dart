import 'dart:io';
import 'dart:ui' as ui;
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
import 'package:music_player/ui/widgets/visualizer/spectrum_painter.dart';
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

  test('SpectrumPainter can paint every visualizer style', () {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final repaint = ValueNotifier<int>(0);
    final levels = List<double>.generate(48, (index) {
      final phase = index / 47;
      return 0.16 + (1 - (phase - 0.48).abs()) * 0.62;
    });
    final peaks = List<double>.filled(48, 0.7);
    final history = List<List<double>>.generate(
      5,
      (layer) => List<double>.filled(48, 0.22 + layer * 0.06),
    );

    for (final style in VisualizerStyle.values) {
      SpectrumPainter(
        repaint: repaint,
        levels: levels,
        peaks: peaks,
        barCount: levels.length,
        style: style,
        color: const Color(0xFF2F7D73),
        secondaryColor: const Color(0xFF3B82F6),
        tertiaryColor: const Color(0xFFF59E0B),
        surfaceColor: const Color(0xFFF7F9FC),
        faintColor: const Color(0x332F7D73),
        particles: const [],
        history: history,
        historyHead: 0,
        beatIntensity: 0.42,
        enableGlow: true,
        showGuides: true,
      ).paint(canvas, const Size(640, 240));
    }

    recorder.endRecording().dispose();
    repaint.dispose();
  });

  test('SpectrumPainter keeps low-energy bars visibly filled', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final repaint = ValueNotifier<int>(0);

    SpectrumPainter(
      repaint: repaint,
      levels: const [0.04],
      peaks: const [0.0],
      barCount: 1,
      style: VisualizerStyle.bars,
      color: const Color(0xFF2F7D73),
      secondaryColor: const Color(0xFF3B82F6),
      tertiaryColor: const Color(0xFFF59E0B),
      surfaceColor: const Color(0xFFF7F9FC),
      faintColor: const Color(0x332F7D73),
      particles: const [],
      history: const [],
      historyHead: 0,
      beatIntensity: 0,
      enableGlow: false,
      showGuides: false,
    ).paint(canvas, const Size(640, 240));

    final picture = recorder.endRecording();
    final image = await picture.toImage(640, 240);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = byteData!.buffer.asUint8List();
    var visibleRows = 0;
    for (var y = 0; y < 240; y++) {
      final alpha = pixels[(y * 640 + 320) * 4 + 3];
      if (alpha >= 120) visibleRows++;
    }

    expect(visibleRows, greaterThan(20));
    image.dispose();
    picture.dispose();
    repaint.dispose();
  });

  test(
    'SpectrumPainter fills both sides of a wide fullscreen canvas',
    () async {
      const width = 1600;
      const height = 500;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final repaint = ValueNotifier<int>(0);

      SpectrumPainter(
        repaint: repaint,
        levels: List<double>.filled(48, 0.72),
        peaks: List<double>.filled(48, 0),
        barCount: 48,
        style: VisualizerStyle.flame,
        color: const Color(0xFF5B6ABF),
        secondaryColor: const Color(0xFF5B6ABF),
        tertiaryColor: const Color(0xFF5B6ABF),
        surfaceColor: const Color(0xFF0D1117),
        faintColor: const Color(0x335B6ABF),
        particles: const [],
        history: const [],
        historyHead: 0,
        beatIntensity: 0.3,
        enableGlow: true,
        showGuides: false,
      ).paint(canvas, Size(width.toDouble(), height.toDouble()));

      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final pixels = byteData!.buffer.asUint8List();
      var leftVisiblePixels = 0;
      var rightVisiblePixels = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < 80; x++) {
          if (pixels[(y * width + x) * 4 + 3] >= 40) {
            leftVisiblePixels++;
          }
        }
        for (var x = width - 80; x < width; x++) {
          if (pixels[(y * width + x) * 4 + 3] >= 40) {
            rightVisiblePixels++;
          }
        }
      }

      expect(leftVisiblePixels, greaterThan(1000));
      expect(rightVisiblePixels, greaterThan(1000));
      image.dispose();
      picture.dispose();
      repaint.dispose();
    },
  );

  test('SpectrumPainter leaves headroom for full-level bars', () async {
    const width = 320;
    const height = 240;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final repaint = ValueNotifier<int>(0);

    SpectrumPainter(
      repaint: repaint,
      levels: List<double>.filled(32, 1),
      peaks: List<double>.filled(32, 0),
      barCount: 32,
      style: VisualizerStyle.bars,
      color: const Color(0xFF5B6ABF),
      secondaryColor: const Color(0xFF4B8FC7),
      tertiaryColor: const Color(0xFF8C63C7),
      surfaceColor: const Color(0xFF0D1117),
      faintColor: const Color(0x335B6ABF),
      particles: const [],
      history: const [],
      historyHead: 0,
      beatIntensity: 0,
      enableGlow: false,
      showGuides: false,
    ).paint(canvas, Size(width.toDouble(), height.toDouble()));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = byteData!.buffer.asUint8List();
    int alphaAt(int x, int y) => pixels[(y * width + x) * 4 + 3];

    expect(alphaAt(4, 48), lessThan(10));
    expect(alphaAt(4, 96), greaterThan(120));
    image.dispose();
    picture.dispose();
    repaint.dispose();
  });

  test('SpectrumPainter uses distinct colors across frequency bands', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final repaint = ValueNotifier<int>(0);

    SpectrumPainter(
      repaint: repaint,
      levels: const [0.75, 0.75, 0.75],
      peaks: const [0, 0, 0],
      barCount: 3,
      style: VisualizerStyle.bars,
      color: const Color(0xFF5B6ABF),
      secondaryColor: const Color(0xFF5B6ABF),
      tertiaryColor: const Color(0xFF5B6ABF),
      surfaceColor: const Color(0xFFF7F9FC),
      faintColor: const Color(0x335B6ABF),
      particles: const [],
      history: const [],
      historyHead: 0,
      beatIntensity: 0,
      enableGlow: false,
      showGuides: false,
    ).paint(canvas, const Size(640, 240));

    final picture = recorder.endRecording();
    final image = await picture.toImage(640, 240);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = byteData!.buffer.asUint8List();

    int colorDistance(int firstX, int secondX) {
      final firstOffset = (120 * 640 + firstX) * 4;
      final secondOffset = (120 * 640 + secondX) * 4;
      final red = pixels[firstOffset] - pixels[secondOffset];
      final green = pixels[firstOffset + 1] - pixels[secondOffset + 1];
      final blue = pixels[firstOffset + 2] - pixels[secondOffset + 2];
      return red * red + green * green + blue * blue;
    }

    expect(colorDistance(300, 320), greaterThan(6000));
    expect(colorDistance(320, 340), greaterThan(6000));
    expect(colorDistance(300, 340), greaterThan(6000));
    image.dispose();
    picture.dispose();
    repaint.dispose();
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
