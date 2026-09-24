import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/providers/download_provider.dart';
import 'package:music_player/services/gd_music_api.dart';

void main() {
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
