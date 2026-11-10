import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'app.dart';
import 'ui/theme/app_design.dart';

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
    final isDark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0B1017)
        : const Color(0xFFF6F8FC);
    final card = isDark ? const Color(0xFF17212C) : const Color(0xFFFFFFFF);
    final foreground = isDark
        ? const Color(0xFFEFF3F8)
        : const Color(0xFF16202C);
    final muted = isDark ? const Color(0xFFA7B4C4) : const Color(0xFF5D6B7D);
    const accent = Color(0xFFF43F5E);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: muted.withValues(alpha: 0.22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '界面渲染出错',
                      style: TextStyle(
                        color: foreground,
                        fontSize: AppTypeScale.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppTypeScale.caption,
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
