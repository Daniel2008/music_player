import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 限制 Flutter 图片缓存防止内存膨胀
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 20 << 20; // 20MB


  // 仅在桌面平台初始化窗口管理器
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Music Player',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const AppRoot());
}
