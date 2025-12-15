import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FfmpegTranscoder {
  /// 使用系统 ffmpeg 命令行工具转码
  /// 需要确保系统已安装 ffmpeg 并在 PATH 中
  Future<File> transcodeToWav(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/transcoded_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    final args = <String>[
      '-y',
      '-i',
      inputPath,
      '-vn',
      '-acodec',
      'pcm_s16le',
      '-ar',
      '44100',
      '-ac',
      '2',
      out.path,
    ];

    try {
      final result = await Process.run('ffmpeg', args);
      if (result.exitCode != 0) {
        throw Exception('FFmpeg 转码失败: ${result.stderr}');
      }
    } catch (e) {
      if (e.toString().contains('ProcessException')) {
        throw Exception('FFmpeg 未安装或不在 PATH 中。');
      }
      rethrow;
    }

    return out;
  }
}
