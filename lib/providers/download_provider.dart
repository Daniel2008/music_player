import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/gd_music_api.dart';

/// 下载任务状态
enum DownloadStatus { pending, downloading, completed, failed, cancelled }

/// 下载任务
class DownloadTask {
  final String id;
  final GdSearchTrack track;
  final String quality;
  DownloadStatus status;
  double progress;
  String? savePath;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;
  int? fileSizeBytes;
  int downloadedBytes;
  http.Client? _httpClient;

  DownloadTask({
    required this.id,
    required this.track,
    required this.quality,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.savePath,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    this.fileSizeBytes,
    this.downloadedBytes = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String get trackKey => '${track.source}_${track.id}';

  String get fileName =>
      _sanitizeFileName('${track.name} - ${track.artistText}.mp3');

  String _sanitizeFileName(String name) {
    // 移除或替换不合法的文件名字符
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 获取下载速度的友好显示
  String get progressDisplay {
    if (fileSizeBytes == null || fileSizeBytes == 0) {
      return '${(downloadedBytes / 1024).toStringAsFixed(0)} KB';
    }
    final totalMB = fileSizeBytes! / (1024 * 1024);
    final downloadedMB = downloadedBytes / (1024 * 1024);
    return '${downloadedMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB';
  }

  void cancel() {
    _httpClient?.close();
    _httpClient = null;
    status = DownloadStatus.cancelled;
  }
}

/// 下载管理器
class DownloadProvider extends ChangeNotifier {
  GdMusicApiClient _gdApi;

  // 下载任务列表
  final Map<String, DownloadTask> _tasks = {};

  // 下载队列（等待中的任务 ID）
  final List<String> _queue = [];

  // 当前正在下载的任务数量
  int _activeDownloads = 0;

  // 最大并行下载数
  int maxConcurrentDownloads = 3;

  // 默认下载目录
  String? _defaultDownloadPath;

  // 是否自动开始下载
  bool autoStartDownload = true;

  // 默认音质
  String defaultQuality = '320';

  DownloadProvider({GdMusicApiClient? gdApi})
    : _gdApi = gdApi ?? GdMusicApiClient();

  // Getters
  List<DownloadTask> get allTasks => _tasks.values.toList();

  List<DownloadTask> get pendingTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.pending).toList();

  List<DownloadTask> get downloadingTasks => _tasks.values
      .where((t) => t.status == DownloadStatus.downloading)
      .toList();

  List<DownloadTask> get completedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.failed).toList();

  int get activeDownloadCount => _activeDownloads;

  int get queueLength => _queue.length;

  String? get defaultDownloadPath => _defaultDownloadPath;

  /// 更新 API 客户端
  void updateApiClient(GdMusicApiClient client) {
    _gdApi = client;
  }

  /// 更新 API 基础 URL
  void updateApiBaseUrl(String url) {
    _gdApi.updateBaseUrl(url);
  }

  /// 更新请求超时时间
  void updateTimeout(int seconds) {
    _gdApi.updateTimeoutSeconds(seconds);
  }

  /// 设置默认下载目录
  Future<void> setDefaultDownloadPath(String? path) async {
    _defaultDownloadPath = path;
    notifyListeners();
  }

  /// 选择默认下载目录
  Future<String?> selectDefaultDownloadPath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择默认下载目录',
    );
    if (result != null) {
      _defaultDownloadPath = result;
      notifyListeners();
    }
    return result;
  }

  /// 添加下载任务
  Future<DownloadTask?> addDownload(
    GdSearchTrack track, {
    String? quality,
    String? savePath,
    bool startImmediately = true,
  }) async {
    final trackKey = '${track.source}_${track.id}';

    // 检查是否已存在
    if (_tasks.containsKey(trackKey)) {
      final existing = _tasks[trackKey]!;
      if (existing.status == DownloadStatus.downloading ||
          existing.status == DownloadStatus.pending) {
        return existing; // 已在下载或等待中
      }
      // 如果是失败或取消的任务，移除后重新添加
      if (existing.status == DownloadStatus.failed ||
          existing.status == DownloadStatus.cancelled) {
        _tasks.remove(trackKey);
      }
    }

    final task = DownloadTask(
      id: trackKey,
      track: track,
      quality: quality ?? defaultQuality,
      status: DownloadStatus.pending,
      savePath: savePath,
    );

    _tasks[trackKey] = task;
    _queue.add(trackKey);
    notifyListeners();

    if (startImmediately && autoStartDownload) {
      _processQueue();
    }

    return task;
  }

  /// 批量添加下载任务
  Future<List<DownloadTask>> addDownloads(
    List<GdSearchTrack> tracks, {
    String? quality,
  }) async {
    final tasks = <DownloadTask>[];
    for (final track in tracks) {
      final task = await addDownload(
        track,
        quality: quality,
        startImmediately: false,
      );
      if (task != null) {
        tasks.add(task);
      }
    }
    _processQueue();
    return tasks;
  }

  /// 处理下载队列
  void _processQueue() {
    while (_activeDownloads < maxConcurrentDownloads && _queue.isNotEmpty) {
      final taskId = _queue.removeAt(0);
      final task = _tasks[taskId];
      if (task != null && task.status == DownloadStatus.pending) {
        _startDownload(task);
      }
    }
  }

  /// 开始下载任务
  Future<void> _startDownload(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    _activeDownloads++;
    notifyListeners();

    try {
      // 获取下载链接
      final urlInfo = await _gdApi.getTrackUrl(
        source: task.track.source,
        id: task.track.id,
        br: task.quality,
      );

      if (urlInfo.url.isEmpty) {
        throw Exception('获取下载链接失败：链接为空');
      }

      // 确定保存路径
      String? savePath = task.savePath;
      if (savePath == null) {
        if (_defaultDownloadPath != null) {
          // 使用默认下载目录
          savePath = path.join(_defaultDownloadPath!, task.fileName);
        } else {
          // 弹出保存对话框
          savePath = await FilePicker.platform.saveFile(
            dialogTitle: '保存音乐',
            fileName: task.fileName,
            type: FileType.custom,
            allowedExtensions: ['mp3', 'flac', 'wav', 'm4a'],
          );
        }
      }

      if (savePath == null) {
        task.status = DownloadStatus.cancelled;
        _activeDownloads--;
        notifyListeners();
        _processQueue();
        return;
      }

      task.savePath = savePath;

      // 创建 HTTP 客户端
      task._httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(urlInfo.url));
      final response = await task._httpClient!.send(request);

      if (response.statusCode != 200) {
        throw Exception('下载失败：HTTP ${response.statusCode}');
      }

      task.fileSizeBytes = response.contentLength;
      task.downloadedBytes = 0;

      // 下载文件
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (task.status == DownloadStatus.cancelled) {
          throw Exception('下载已取消');
        }

        bytes.addAll(chunk);
        task.downloadedBytes += chunk.length;

        if (task.fileSizeBytes != null && task.fileSizeBytes! > 0) {
          task.progress = task.downloadedBytes / task.fileSizeBytes!;
        }
        notifyListeners();
      }

      // 保存文件
      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.completedAt = DateTime.now();
    } catch (e) {
      if (task.status != DownloadStatus.cancelled) {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
    } finally {
      task._httpClient?.close();
      task._httpClient = null;
      _activeDownloads--;
      notifyListeners();
      _processQueue();
    }
  }

  /// 暂停/恢复下载（目前实现为取消后重新添加）
  void pauseDownload(String trackKey) {
    final task = _tasks[trackKey];
    if (task != null && task.status == DownloadStatus.downloading) {
      task.cancel();
      notifyListeners();
    }
  }

  /// 取消下载
  void cancelDownload(String source, String id) {
    final trackKey = '${source}_$id';
    final task = _tasks[trackKey];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        task.cancel();
      } else if (task.status == DownloadStatus.pending) {
        task.status = DownloadStatus.cancelled;
        _queue.remove(trackKey);
      }
      notifyListeners();
    }
  }

  /// 重试失败的下载
  Future<void> retryDownload(String trackKey) async {
    final task = _tasks[trackKey];
    if (task != null &&
        (task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled)) {
      task.status = DownloadStatus.pending;
      task.progress = 0.0;
      task.downloadedBytes = 0;
      task.error = null;
      _queue.add(trackKey);
      notifyListeners();
      _processQueue();
    }
  }

  /// 重试所有失败的下载
  Future<void> retryAllFailed() async {
    for (final task in failedTasks) {
      await retryDownload(task.id);
    }
  }

  /// 移除下载任务
  void removeTask(String trackKey) {
    final task = _tasks[trackKey];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        task.cancel();
        _activeDownloads--;
      }
      _queue.remove(trackKey);
      _tasks.remove(trackKey);
      notifyListeners();
    }
  }

  /// 清除已完成的任务
  void clearCompleted() {
    _tasks.removeWhere((key, task) => task.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// 清除所有任务
  void clearAll() {
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading) {
        task.cancel();
      }
    }
    _tasks.clear();
    _queue.clear();
    _activeDownloads = 0;
    notifyListeners();
  }

  // 兼容旧 API
  bool isDownloading(String source, String id) {
    final trackKey = '${source}_$id';
    final task = _tasks[trackKey];
    return task?.status == DownloadStatus.downloading ||
        task?.status == DownloadStatus.pending;
  }

  double getDownloadProgress(String source, String id) {
    final trackKey = '${source}_$id';
    return _tasks[trackKey]?.progress ?? 0.0;
  }

  String? get downloadError {
    final failed = failedTasks;
    return failed.isNotEmpty ? failed.first.error : null;
  }

  /// 兼容旧的下载方法
  Future<String?> downloadTrack(GdSearchTrack item, {String br = '320'}) async {
    final task = await addDownload(item, quality: br);
    if (task == null) return null;

    // 等待下载完成
    while (task.status == DownloadStatus.pending ||
        task.status == DownloadStatus.downloading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (task.status == DownloadStatus.completed) {
      return task.savePath;
    }
    return null;
  }

  /// 获取下载目录（如果未设置则使用系统下载目录）
  Future<String> getDownloadDirectory() async {
    if (_defaultDownloadPath != null) {
      return _defaultDownloadPath!;
    }

    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        return path.join(dir.path, 'Music');
      }
    } catch (_) {}

    // 回退到应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'Downloads', 'Music');
  }

  @override
  void dispose() {
    // 取消所有正在进行的下载
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading) {
        task.cancel();
      }
    }
    _gdApi.close();
    super.dispose();
  }
}
