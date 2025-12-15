import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/gd_music_api.dart';

class DownloadProvider extends ChangeNotifier {
  final GdMusicApiClient _gdApi;

  Map<String, double> downloadProgress = {};
  Set<String> downloadingIds = {};
  String? downloadError;

  DownloadProvider({GdMusicApiClient? gdApi})
    : _gdApi = gdApi ?? GdMusicApiClient();

  Future<String?> downloadTrack(GdSearchTrack item, {String br = '320'}) async {
    final trackKey = '${item.source}_${item.id}';
    if (downloadingIds.contains(trackKey)) return null;

    downloadingIds.add(trackKey);
    downloadProgress[trackKey] = 0.0;
    downloadError = null;
    notifyListeners();

    try {
      // 获取下载链接
      final urlInfo = await _gdApi.getTrackUrl(
        source: item.source,
        id: item.id,
        br: br,
      );

      // 选择保存目录
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存音乐',
        fileName: '${item.name} - ${item.artistText}.mp3',
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (savePath == null) {
        downloadingIds.remove(trackKey);
        downloadProgress.remove(trackKey);
        notifyListeners();
        return null;
      }

      // 下载文件
      final request = http.Request('GET', Uri.parse(urlInfo.url));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          downloadProgress[trackKey] = received / contentLength;
          notifyListeners();
        }
      }

      // 保存文件
      final file = File(savePath);
      await file.writeAsBytes(bytes);

      downloadProgress[trackKey] = 1.0;
      notifyListeners();

      // 延迟后清理状态
      Future.delayed(const Duration(seconds: 2), () {
        downloadingIds.remove(trackKey);
        downloadProgress.remove(trackKey);
        notifyListeners();
      });

      return savePath;
    } catch (e) {
      downloadingIds.remove(trackKey);
      downloadProgress.remove(trackKey);
      downloadError = e.toString();
      notifyListeners();
      return null;
    }
  }

  bool isDownloading(String source, String id) {
    return downloadingIds.contains('${source}_$id');
  }

  double getDownloadProgress(String source, String id) {
    return downloadProgress['${source}_$id'] ?? 0.0;
  }

  void cancelDownload(String source, String id) {
    final trackKey = '${source}_$id';
    downloadingIds.remove(trackKey);
    downloadProgress.remove(trackKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _gdApi.close();
    super.dispose();
  }
}
