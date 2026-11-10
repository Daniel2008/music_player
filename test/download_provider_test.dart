import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_player/services/storage_service.dart';
import 'package:music_player/providers/download_provider.dart';
import 'package:music_player/services/gd_music_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUp(() async => (await StorageService.instance.prefs).clear());

  test('下载目录、并发数与自动开始设置在新实例中恢复并通知界面', () async {
    final first = DownloadProvider();
    await first.ready;
    var notifications = 0;
    first.addListener(() => notifications++);
    await first.setDefaultDownloadPath('/fixture/downloads');
    first.maxConcurrentDownloads = 5;
    first.autoStartDownload = false;
    await first.flushSettings();
    final restored = DownloadProvider();
    await restored.ready;
    expect(restored.defaultDownloadPath, '/fixture/downloads');
    expect(restored.maxConcurrentDownloads, 5);
    expect(restored.autoStartDownload, isFalse);
    expect(notifications, greaterThanOrEqualTo(3));
    first.dispose();
    restored.dispose();
  });
  test(
    '同名并发下载保留已有文件并分别保存完整内容',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final directory = await Directory.systemTemp.createTemp(
        'download_safety_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.write('audio-${request.uri.pathSegments.last}');
        await request.response.close();
      });
      final api = GdMusicApiClient(
        client: MockClient(
          (request) async => http.Response(
            '{"url":"http://127.0.0.1:${server.port}/${request.url.queryParameters['id']}"}',
            200,
          ),
        ),
      );
      final provider = DownloadProvider(gdApi: api);
      addTearDown(() async {
        provider.dispose();
        api.close();
        await server.close(force: true);
        await directory.delete(recursive: true);
      });
      await provider.setDefaultDownloadPath(directory.path);
      final existing = File('${directory.path}/Same - Artist.mp3');
      await existing.writeAsString('original-user-audio');
      GdSearchTrack track(String id) => GdSearchTrack(
        id: id,
        name: 'Same',
        artists: const ['Artist'],
        album: '',
        source: 'netease',
        picId: null,
        lyricId: null,
      );
      final paths = await Future.wait([
        provider.downloadTrack(track('1')),
        provider.downloadTrack(track('2')),
      ]).timeout(const Duration(seconds: 10));
      expect(await existing.readAsString(), 'original-user-audio');
      expect(
        paths,
        everyElement(isNotNull),
        reason: provider.failedTasks.map((t) => t.error).join('\n'),
      );
      expect(paths.toSet(), hasLength(2));
      expect(await File(paths[0]!).readAsString(), 'audio-1');
      expect(await File(paths[1]!).readAsString(), 'audio-2');
      expect(await directory.list().where((f) => f is Directory).length, 0);
    }, _LocalHttpOverrides()),
  );

  GdSearchTrack makeTrack(String id, {String source = 'netease'}) =>
      GdSearchTrack(
        id: id,
        name: 'Track $id',
        artists: const ['Artist'],
        album: 'Album',
        picId: 'p$id',
        lyricId: 'l$id',
        source: source,
      );

  group('DownloadProvider - 队列与状态机', () {
    test('addDownload 创建新任务并入队', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      final task = await provider.addDownload(
        makeTrack('1'),
        startImmediately: false,
      );
      expect(task, isNotNull);
      expect(task!.status, DownloadStatus.pending);
      expect(provider.queueLength, 1);
    });

    test('addDownload 重复的 downloading/pending 任务返回已存在', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      final first = await provider.addDownload(
        makeTrack('1'),
        startImmediately: false,
      );
      final second = await provider.addDownload(
        makeTrack('1'),
        startImmediately: false,
      );
      expect(identical(first, second), isTrue);
      expect(provider.queueLength, 1);
    });

    test('cancelDownload 把 pending 任务标记为 cancelled 并出队', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      await provider.addDownload(makeTrack('1'), startImmediately: false);
      provider.cancelDownload('netease', '1');
      expect(provider.queueLength, 0);
      expect(provider.allTasks.first.status, DownloadStatus.cancelled);
    });

    test('clearCompleted 仅清除已完成任务', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      final t = await provider.addDownload(
        makeTrack('1'),
        startImmediately: false,
      );
      t!.status = DownloadStatus.completed;
      provider.notifyListeners();
      provider.clearCompleted();
      expect(provider.allTasks, isEmpty);
    });

    test('clearAll 取消正在下载的任务', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      final t = await provider.addDownload(
        makeTrack('1'),
        startImmediately: false,
      );
      t!.status = DownloadStatus.downloading;
      t.cancel();
      provider.clearAll();
      expect(provider.allTasks, isEmpty);
      expect(provider.activeDownloadCount, 0);
    });

    test('removeTask 不提前释放正在运行的并发槽位', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      final task = await provider.addDownload(
        makeTrack('running'),
        startImmediately: false,
      );
      task!.status = DownloadStatus.downloading;
      provider.debugSetActiveDownloads(1);

      provider.removeTask(task.id);

      expect(provider.activeDownloadCount, 1);
      expect(provider.allTasks, isEmpty);
      provider.debugSetActiveDownloads(0);
      provider.dispose();
    });

    test('clearAll 由下载协程统一释放并发槽位', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      final task = await provider.addDownload(
        makeTrack('running'),
        startImmediately: false,
      );
      task!.status = DownloadStatus.downloading;
      provider.debugSetActiveDownloads(1);

      provider.clearAll();

      expect(provider.activeDownloadCount, 1);
      expect(provider.allTasks, isEmpty);
      provider.debugSetActiveDownloads(0);
      provider.dispose();
    });

    test('_pruneTasks 在超过上限时清理最旧已完成任务', () async {
      final provider = DownloadProvider(gdApi: GdMusicApiClient());
      // 注入 205 个 completed 任务（超过 _maxTaskCount=200）
      for (var i = 0; i < 205; i++) {
        final t = await provider.addDownload(
          makeTrack('$i'),
          startImmediately: false,
        );
        t!.status = DownloadStatus.completed;
      }
      // 触发 prune
      await provider.addDownload(
        makeTrack('overflow'),
        startImmediately: false,
      );
      expect(provider.allTasks.length, lessThanOrEqualTo(200));
    });
  });
}

class _LocalHttpOverrides extends HttpOverrides {}
