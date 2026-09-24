import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'app.dart';

/// 自定义图片磁盘缓存管理器 — 限制封面图缓存上限
class AppCacheManager extends CacheManager with ImageCacheManager {
  AppCacheManager._()
    : super(
        Config(
          _key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200,
        ),
      );
  static const String _key = 'appImageCache';

  static final AppCacheManager instance = AppCacheManager._();
}

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

  // 自定义全局错误展示，避免在 release/开发模式下出现红屏/黑屏
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      _AppErrorWidget(error: details.exception, stack: details.stack);

  runApp(const AppRoot());
}

class _AppErrorWidget extends StatelessWidget {
  const _AppErrorWidget({required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1A1A24),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFFEC4899),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              '界面渲染出错',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB0B0B8), fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一获取封面图 ImageProvider，自动使用 AppCacheManager 并按目标尺寸 resize
ImageProvider coverImageProvider(String url, {int size = 48}) {
  return ResizeImage(
    CachedNetworkImageProvider(url, cacheManager: AppCacheManager.instance),
    width: size,
    height: size,
  );
}
