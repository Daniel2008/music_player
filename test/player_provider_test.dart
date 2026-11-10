import 'dart:async';
import 'dart:io';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/providers/player_provider.dart';
import 'package:music_player/services/gd_music_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('player_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });
  for (final failOld in [false, true]) {
    test('新的 URL 解析使旧原生加载失效（旧加载失败=$failOld）', () async {
      final oldLoad = Completer<AudioSource>();
      final response = Completer<http.Response>();
      final requested = Completer<void>();
      final engine = _Engine()
        ..pendingLoads['https://old.invalid/audio'] = oldLoad;
      final api = GdMusicApiClient(
        client: MockClient((request) {
          if (!requested.isCompleted) requested.complete();
          return response.future;
        }),
      );
      final player = PlayerProvider(soloud: engine, gdApi: api);
      addTearDown(() {
        player.dispose();
        api.close();
      });
      final old = player.playTrackSmart(
        Track(
          title: 'Old',
          path: 'https://old.invalid/audio',
          kind: TrackKind.remote,
          remoteSource: 'netease',
          remoteTrackId: 'old',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final latest = player.playTrackSmart(
        Track(
          title: 'Latest',
          path: '',
          kind: TrackKind.remote,
          remoteSource: 'netease',
          remoteTrackId: 'latest',
        ),
      );
      await requested.future;
      if (failOld) {
        oldLoad.completeError(StateError('old failed'));
      } else {
        oldLoad.complete(engine.sourceFor('https://old.invalid/audio'));
      }
      await Future<void>.delayed(Duration.zero);
      expect(engine.played, isEmpty);
      response.complete(
        http.Response('{"url":"https://latest.invalid/audio"}', 200),
      );
      expect(await old, isFalse);
      expect(await latest, isTrue);
      expect(engine.played, ['https://latest.invalid/audio']);
    });
  }
  test('已有本地路径且未加载时，统一播放入口会加载曲目', () async {
    final engine = _Engine();
    final player = PlayerProvider(
      soloud: engine,
      shouldAutoFetchLocalLyric: () => false,
    );
    addTearDown(player.dispose);
    await IOOverrides.runZoned(() async {
      expect(
        await player.playOrResume(Track(title: 'Local', path: '/ready.wav')),
        isTrue,
      );
      expect(engine.played, ['/ready.wav']);
      await player.pause();
      expect(
        await player.playOrResume(Track(title: 'Local', path: '/ready.wav')),
        isTrue,
      );
      expect(engine.played, hasLength(1));
    }, createFile: (path) => _CheckedFile(path, Future.value(true)));
  });

  test('旧远程链接播放失败时刷新链接后继续播放', () async {
    final engine = _Engine()..badUrl = 'https://expired.invalid/audio';
    var requests = 0;
    final api = GdMusicApiClient(
      client: MockClient(
        (request) async => http.Response(
          '{"url":"${++requests == 1 ? engine.badUrl : 'https://fresh.invalid/audio'}"}',
          200,
        ),
      ),
    );
    await api.getTrackUrl(source: 'netease', id: '1', br: '320');
    final player = PlayerProvider(soloud: engine, gdApi: api);
    addTearDown(() {
      player.dispose();
      api.close();
    });
    expect(
      await player.playOrResume(
        Track(
          title: 'Remote',
          path: engine.badUrl!,
          kind: TrackKind.remote,
          remoteSource: 'netease',
          remoteTrackId: '1',
        ),
      ),
      isTrue,
    );
    expect(engine.played, ['https://fresh.invalid/audio']);
  });
  test('较早的文件检查延迟返回时不能覆盖后选择的曲目', () async {
    final slowExists = Completer<bool>();
    final engine = _Engine();
    final player = PlayerProvider(
      soloud: engine,
      shouldAutoFetchLocalLyric: () => false,
    );
    addTearDown(player.dispose);
    await IOOverrides.runZoned(
      () async {
        final slow = player.playTrack(Track(title: 'Slow', path: '/slow.wav'));
        await Future<void>.delayed(Duration.zero);
        expect(
          await player.playTrack(Track(title: 'Latest', path: '/latest.wav')),
          isTrue,
        );
        slowExists.complete(true);
        expect(await slow, isFalse);
        expect(engine.played, ['/latest.wav']);
        expect(player.isPlaying, isTrue);
      },
      createFile: (path) => _CheckedFile(
        path,
        path == '/slow.wav' ? slowExists.future : Future.value(true),
      ),
    );
  });

  test('停止后到达的文件检查不得重新开始播放', () async {
    final exists = Completer<bool>();
    final engine = _Engine();
    final player = PlayerProvider(
      soloud: engine,
      shouldAutoFetchLocalLyric: () => false,
    );
    addTearDown(player.dispose);
    await IOOverrides.runZoned(() async {
      final pending = player.playTrack(
        Track(title: 'Pending', path: '/pending.wav'),
      );
      await Future<void>.delayed(Duration.zero);
      await player.stop();
      exists.complete(true);
      expect(await pending, isFalse);
      expect(engine.played, isEmpty);
    }, createFile: (path) => _CheckedFile(path, exists.future));
  });
}

class _CheckedFile implements File {
  _CheckedFile(this.path, this.result);
  @override
  final String path;
  final Future<bool> result;
  @override
  Future<bool> exists() => result;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Engine implements SoLoud {
  final pendingLoads = <String, Completer<AudioSource>>{};
  String? badUrl;
  final played = <String>[];
  final paths = <AudioSource, String>{};
  AudioSource sourceFor(String path) {
    // ignore: invalid_use_of_internal_member
    final source = AudioSource(SoundHash(paths.length + 1));
    paths[source] = path;
    return source;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #init:
      case #stop:
      case #disposeSource:
        return Future<void>.value();
      case #loadFile:
      case #loadUrl:
        final path = invocation.positionalArguments.first as String;
        if (pendingLoads[path] case final pending?) return pending.future;
        if (invocation.positionalArguments.first == badUrl) {
          return Future<AudioSource>.error(StateError('expired URL'));
        }
        return Future<AudioSource>.value(sourceFor(path));
      case #play:
        played.add(paths[invocation.positionalArguments.first]!);
        return SoundHandle(played.length);
      case #getLength:
        return const Duration(minutes: 10);
      case #getIsValidVoiceHandle:
        return true;
      case #getPosition:
        return Duration.zero;
      default:
        return null;
    }
  }
}
