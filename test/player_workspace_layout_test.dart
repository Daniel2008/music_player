import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/models/playlist.dart';
import 'package:music_player/providers/player_provider.dart';
import 'package:music_player/providers/playlist_provider.dart';
import 'package:music_player/providers/theme_provider.dart';
import 'package:music_player/services/gd_music_api.dart';
import 'package:music_player/services/lyric_service.dart';
import 'package:music_player/services/storage_service.dart';
import 'package:music_player/ui/pages/player_workspace_page_v3.dart';
import 'package:music_player/ui/widgets/mini_player_v2.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late Directory testStorageDirectory;

  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\msyh.ttc');
    if (await font.exists()) {
      final loader = FontLoader('Microsoft YaHei UI')
        ..addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });

  setUp(() async {
    testStorageDirectory = await Directory.systemTemp.createTemp(
      'music_player_layout_test_',
    );
    StorageService.instance.setTestDirectory(testStorageDirectory);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => testStorageDirectory.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    StorageService.instance.setTestDirectory(null);
    if (await testStorageDirectory.exists()) {
      await testStorageDirectory.delete(recursive: true);
    }
  });

  testWidgets(
    'player workspace keeps spectrum, lyrics, and controls vertical',
    (tester) async {
      tester.view.reset();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.reset);

      final theme = ThemeProvider(useGoogleFonts: false);
      final player = _FakePlayerProvider();
      final playlist = PlaylistProvider(
        initialPlaylist: Playlist(
          name: '布局测试',
          tracks: [
            Track(
              id: 'layout-test',
              title: '界面布局验证',
              artist: 'Music Player',
              path: r'C:\Music\layout-test.mp3',
            ),
          ],
        ),
      );

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlayerProvider>.value(value: player),
            ChangeNotifierProvider<PlaylistProvider>.value(value: playlist),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.lightTheme,
            home: RepaintBoundary(
              key: boundaryKey,
              child: const Scaffold(
                body: Column(
                  children: [
                    Expanded(child: PlayerWorkspacePage()),
                    MiniPlayer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('实时频谱'), findsOneWidget);
      expect(find.text('同步歌词'), findsOneWidget);
      final miniTitle = find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.text('界面布局验证'),
      );
      expect(miniTitle, findsOneWidget);
      expect(find.byTooltip('列表循环'), findsOneWidget);
      await tester.tap(find.byTooltip('列表循环'));
      await tester.pump();
      expect(playlist.playMode, PlayMode.single);
      expect(find.byTooltip('单曲循环'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final spectrumY = tester.getTopLeft(find.text('实时频谱')).dy;
      final lyricsY = tester.getTopLeft(find.text('同步歌词')).dy;
      final controlsY = tester.getTopLeft(miniTitle).dy;
      expect(spectrumY, lessThan(lyricsY));
      expect(lyricsY, lessThan(controlsY));
      expect(
        tester.getBottomRight(find.byType(MiniPlayer)).dy,
        lessThanOrEqualTo(1000),
      );

      await tester.pumpWidget(const SizedBox());
      player.dispose();
      playlist.dispose();
      theme.dispose();
    },
  );
}

class _FakePlayerProvider extends ChangeNotifier implements PlayerProvider {
  @override
  bool isPlaying = false;

  @override
  final Float32List fftData = Float32List(128);

  @override
  final ValueNotifier<double> volumeNotifier = ValueNotifier(1);

  @override
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);

  @override
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);

  @override
  late final Listenable timelineListenable = Listenable.merge([
    positionNotifier,
    durationNotifier,
  ]);

  @override
  final LyricService lyricService = LyricService(GdMusicApiClient());

  @override
  double get volume => volumeNotifier.value;

  @override
  Duration get position => positionNotifier.value;

  @override
  Duration get duration => durationNotifier.value;

  @override
  void setVisualizationConsumerActive(Object consumer, bool active) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
