import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/download_provider.dart';
import 'providers/history_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/api_settings_provider.dart';
import 'services/gd_music_api.dart';
import 'ui/pages/main_layout.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final apiSettings = ApiSettingsProvider();
            apiSettings.init(); // 异步初始化
            return apiSettings;
          },
        ),
        // 共享 API 客户端实例 — 所有 Provider 复用同一连接
        Provider<GdMusicApiClient>(
          create: (_) => GdMusicApiClient(),
          dispose: (_, client) => client.close(),
        ),
        ChangeNotifierProxyProvider<GdMusicApiClient, PlayerProvider>(
          create: (ctx) => PlayerProvider(gdApi: ctx.read<GdMusicApiClient>()),
          update: (_, client, provider) => provider!..updateApiClient(client),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final playlistProvider = PlaylistProvider();
            playlistProvider.init(); // 异步加载保存的播放列表
            return playlistProvider;
          },
        ),
        ChangeNotifierProxyProvider<GdMusicApiClient, SearchProvider>(
          create: (ctx) => SearchProvider(gdApi: ctx.read<GdMusicApiClient>()),
          update: (_, client, provider) => provider!,
        ),
        ChangeNotifierProxyProvider<GdMusicApiClient, DownloadProvider>(
          create: (ctx) => DownloadProvider(gdApi: ctx.read<GdMusicApiClient>()),
          update: (_, client, provider) => provider!,
        ),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          Widget app = MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Flutter Desktop Music Player',
            themeMode: theme.mode,
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            home: const _AppInitializer(),
          );

          // Windows 平台禁用无障碍语义树，防止 AXTree 引擎崩溃
          // （已知的 Flutter Windows 引擎 bug，快速重建 widget 树时会触发）
          if (Platform.isWindows) {
            app = ExcludeSemantics(child: app);
          }

          return app;
        },
      ),
    );
  }
}

/// 应用初始化器，确保 API 设置加载完成后再显示主界面
class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer>
    with SingleTickerProviderStateMixin {
  bool _initialized = false;
  double _opacity = 0.0;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initializeApp();
    // 渐入动画
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    final apiSettings = context.read<ApiSettingsProvider>();
    final gdApi = context.read<GdMusicApiClient>();
    final downloadProvider = context.read<DownloadProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    // 等待 API 设置初始化完成
    if (!apiSettings.initialized) {
      await apiSettings.init();
    }

    if (!mounted) return;

    // 一次性同步 API 配置到共享客户端
    gdApi.updateBaseUrl(apiSettings.apiBaseUrl);
    gdApi.updateTimeoutSeconds(apiSettings.requestTimeout);

    // 仅同步非 API 相关的设置
    downloadProvider.defaultQuality = apiSettings.downloadQuality.brValue;

    // 同步歌词自动搜索设置
    playerProvider.autoFetchLyricForLocal = apiSettings.autoFetchLyric;

    // 注册自动下一曲回调
    playerProvider.onTrackComplete = () {
      playlistProvider.next();
      if (playlistProvider.current != null) {
        playerProvider.playTrackSmart(
          playlistProvider.current!,
          playlistProvider: playlistProvider,
        );
      }
    };

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _initialized
          ? const MainLayout(key: ValueKey('main'))
          : Scaffold(
              key: const ValueKey('loading'),
              body: Center(
                child: AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 脉冲缩放动画图标
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale =
                              1.0 + 0.08 * _pulseController.value;
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.primary,
                                scheme.primary.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Music Player',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '正在加载...',
                        style: TextStyle(
                          color: scheme.outline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
