// Profile-only measurement entry point; production code and user data stay intact.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_player/main.dart' as production;
import 'package:music_player/models/track.dart';
import 'package:music_player/providers/player_provider.dart';
import 'package:music_player/providers/visualizer_settings_provider.dart';
import 'package:music_player/services/storage_service.dart';
import 'package:music_player/ui/pages/main_layout.dart';
import 'package:music_player/ui/widgets/visualizer_view.dart';

final _output = Directory(
  const String.fromEnvironment(
    'PERF_OUTPUT',
    defaultValue: 'F:/ai/music_player/build/verification/performance',
  ),
);
final _frames = <ui.FrameTiming>[];
final _results = <Map<String, Object?>>[];
bool _collect = false;
late BuildContext _context;

Future<void> main() async {
  if (!kProfileMode) throw StateError('Run this entry point in profile mode.');
  WidgetsFlutterBinding.ensureInitialized();
  await _output.create(recursive: true);
  final storage = Directory('${_output.path}/fixture');
  await storage.create(recursive: true);
  // Test storage hooks keep the measurement out of the user's application data.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'auto_fetch_lyric': false});
  // ignore: invalid_use_of_visible_for_testing_member
  StorageService.instance.setTestDirectory(storage);
  final audio = File('${storage.path}/probe.wav');
  await _createAudio(audio);
  await File('${storage.path}/probe.lrc').writeAsString(
    List.generate(300, (i) {
      final seconds = i * 2;
      final minute = (seconds ~/ 60).toString().padLeft(2, '0');
      final second = (seconds % 60).toString().padLeft(2, '0');
      return '[$minute:$second.00]Performance fixture lyric ${i + 1}';
    }).join('\n'),
  );
  await StorageService.instance.writeJsonFile(
    fileName: 'saved_playlist',
    currentSchemaVersion: 1,
    encode: () => {
      'name': 'Isolated performance fixture',
      'currentIndex': 0,
      'tracks': List.generate(
        500,
        (i) => Track(
          id: 'probe-$i',
          title: 'Performance track ${i + 1}',
          path: audio.path,
          artist: 'Local generated PCM fixture',
        ).toJson(),
      ),
    },
  );
  WidgetsBinding.instance.addTimingsCallback((timings) {
    if (_collect) _frames.addAll(timings);
  });
  final errors = <String>[];
  final previousErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    previousErrorHandler?.call(details);
  };
  production.main();
  final service = await developer.Service.getInfo();
  if (service.serverUri != null) {
    await File(
      '${_output.path}/vm-service.json',
    ).writeAsString(jsonEncode({'uri': service.serverUri.toString()}));
  }
  try {
    for (var i = 0; i < 150; i++) {
      final element = _find((widget) => widget is MainLayout);
      if (element != null) {
        _context = element;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (i == 149) throw StateError('MainLayout did not initialize.');
    }
    if (!_context.mounted) throw StateError('MainLayout was unmounted.');
    final player = _context.read<PlayerProvider>();
    final settings = _context.read<VisualizerSettingsProvider>();
    const quick = bool.fromEnvironment('PERF_QUICK');
    settings.setMaxFps(30);
    await _phase('idle_before', 15);
    final track = Track(
      id: 'probe-0',
      title: 'Performance track 1',
      path: audio.path,
    );
    // Quiet audible output keeps the real mixer/FFT path active.
    await player.setVolume(0.08);
    if (!await player.playTrack(track)) throw StateError(player.playError!);
    _navigate('设置');
    await _phase('audio_visualizer_hidden', 15);
    _navigate('播放');
    for (final style in VisualizerStyle.values.where(
      (style) =>
          !quick ||
          style == VisualizerStyle.bars ||
          style == VisualizerStyle.waterfall,
    )) {
      _selectStyle(style);
      await _phase('workspace_${style.name}_30fps', 12);
    }
    if (!quick) {
      _selectStyle(VisualizerStyle.bars);
      settings.setMaxFps(60);
      await _phase('workspace_bars_60fps', 15);
      settings.setMaxFps(30);
      _selectStyle(VisualizerStyle.waterfall);
      await _phase('waterfall_soak_30fps', 60);
    }
    _selectStyle(VisualizerStyle.bars);
    final fullscreen =
        _find(
              (widget) => widget is IconButton && widget.tooltip == '全屏频谱',
            )?.widget
            as IconButton?;
    if (fullscreen?.onPressed == null) {
      throw StateError('Fullscreen button missing.');
    }
    fullscreen!.onPressed!();
    await _phase('fullscreen_bars_30fps', 15);
    final fullscreenElement = _find(
      (widget) => widget.runtimeType.toString() == 'VisualizerFullscreenPage',
    );
    if (fullscreenElement == null) {
      throw StateError('Fullscreen route missing.');
    }
    Navigator.of(fullscreenElement).pop();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!quick) {
      var destination = 0;
      final switchTimer = Timer.periodic(const Duration(milliseconds: 500), (
        _,
      ) {
        _navigate(['设置', '历史', '收藏', '播放'][destination++ % 4]);
      });
      try {
        await _phase('page_switching_500ms', 15);
      } finally {
        switchTimer.cancel();
      }
    }
    _navigate('播放');
    await player.pause();
    await _phase('paused_after', 15);
    await player.stop();
    await _phase('idle_after', 15);
    final valid = _results.every(
      (row) => (row['samples_seconds'] as num) >= 10,
    );
    if (!valid || errors.isNotEmpty) {
      throw StateError('Measurement invalid: durations=$valid, errors=$errors');
    }
    await File('${_output.path}/results.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'mode': 'profile',
        'pid': pid,
        'fixture': '600s mono PCM16 44100Hz; 500 queue entries; local lyrics',
        'audio_volume': 0.08,
        'user_data': 'isolated SharedPreferences mock and workspace storage',
        'phases': _results,
        'flutter_errors': errors,
      }),
    );
    await _status('done');
  } catch (error, stack) {
    await File('${_output.path}/error.txt').writeAsString('$error\n$stack');
    await _status('failed');
    rethrow;
  }
}

Element? _find(bool Function(Widget) matches) {
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    if (matches(element.widget)) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

void _navigate(String label) {
  final text = _find((widget) => widget is Text && widget.data == label);
  VoidCallback? tap;
  text?.visitAncestorElements((element) {
    if (element.widget case InkWell(:final onTap)) {
      tap = onTap;
      return false;
    }
    return true;
  });
  if (tap == null) throw StateError('Navigation not found: $label');
  tap!();
}

void _selectStyle(VisualizerStyle style) {
  final menu =
      _find((widget) => widget is PopupMenuButton<VisualizerStyle>)?.widget
          as PopupMenuButton<VisualizerStyle>?;
  if (menu?.onSelected == null) throw StateError('Style selector missing.');
  menu!.onSelected!(style);
}

Future<void> _status(String phase) =>
    File('${_output.path}/phase.json').writeAsString(
      jsonEncode({
        'pid': pid,
        'phase': phase,
        'utc': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );

Future<void> _phase(String name, int seconds) async {
  _collect = false;
  await _status('warmup_$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  _frames.clear();
  await _status(name);
  final watch = Stopwatch()..start();
  _collect = true;
  await Future<void>.delayed(Duration(seconds: seconds));
  _collect = false;
  watch.stop();
  final builds =
      _frames.map((frame) => frame.buildDuration.inMicroseconds / 1000).toList()
        ..sort();
  final rasters =
      _frames
          .map((frame) => frame.rasterDuration.inMicroseconds / 1000)
          .toList()
        ..sort();
  double percentile(List<double> values, double fraction) =>
      values.isEmpty ? 0 : values[((values.length - 1) * fraction).ceil()];
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  _results.add({
    'name': name,
    'samples_seconds': watch.elapsedMicroseconds / 1000000,
    'frames': _frames.length,
    'frames_per_second': _frames.length * 1000000 / watch.elapsedMicroseconds,
    'build_p50_ms': percentile(builds, 0.5),
    'build_p95_ms': percentile(builds, 0.95),
    'build_max_ms': percentile(builds, 1),
    'raster_p50_ms': percentile(rasters, 0.5),
    'raster_p95_ms': percentile(rasters, 0.95),
    'raster_max_ms': percentile(rasters, 1),
    'frames_over_16_67ms': _frames
        .where(
          (frame) =>
              math.max(
                frame.buildDuration.inMicroseconds,
                frame.rasterDuration.inMicroseconds,
              ) >
              16667,
        )
        .length,
    'rss_mib': ProcessInfo.currentRss / (1024 * 1024),
    'physical_width': view.physicalSize.width,
    'physical_height': view.physicalSize.height,
    'device_pixel_ratio': view.devicePixelRatio,
  });
  await File(
    '${_output.path}/partial.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(_results));
}

Future<void> _createAudio(File file) async {
  const sampleRate = 44100;
  const count = sampleRate * 600;
  const byteCount = count * 2;
  if (await file.exists() && await file.length() == byteCount + 44) return;
  final bytes = ByteData(byteCount + 44);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, byteCount + 36, Endian.little);
  text(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, byteCount, Endian.little);
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    final envelope =
        0.35 + 0.65 * math.pow(math.max(0, math.sin(t * math.pi * 4)), 4);
    final wave =
        math.sin(t * math.pi * 2 * 110) +
        math.sin(t * math.pi * 2 * 440) * 0.6 +
        math.sin(t * math.pi * 2 * 1800) * 0.3 +
        math.sin(t * math.pi * 2 * 6000) * 0.15;
    bytes.setInt16(44 + i * 2, (wave * envelope * 6000).round(), Endian.little);
  }
  if (bytes.getUint32(40, Endian.little) != byteCount) {
    throw StateError('Invalid PCM fixture header.');
  }
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
}
