import 'dart:async';
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
import 'services/connectivity_service.dart';
import 'services/smtc_service.dart';
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
          create: (ctx) => PlayerProvider(
            gdApi: ctx.read<GdMusicApiClient>(),
            shouldAutoFetchLocalLyric: () =>
                ctx.read<ApiSettingsProvider>().autoFetchLyric,
          ),
          update: (_, client, provider) => provider!..updateApiClient(client),
        ),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProxyProvider<GdMusicApiClient, SearchProvider>(
          create: (ctx) => SearchProvider(gdApi: ctx.read<GdMusicApiClient>()),
          update: (_, client, provider) => provider!,
        ),
        ChangeNotifierProxyProvider<GdMusicApiClient, DownloadProvider>(
          create: (ctx) =>
              DownloadProvider(gdApi: ctx.read<GdMusicApiClient>()),
          update: (_, client, provider) => provider!,
        ),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
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

          // 当前 Windows Flutter 引擎在页面频繁 Offstage/动画切换时可能生成
          // 不一致的 AXTree 增量更新，并持续输出 accessibility_bridge 错误。
          // 仅在 Windows 禁用应用级语义树，避免日志风暴和潜在引擎崩溃；
          // macOS/Linux 保留完整无障碍语义。升级 Flutter 后应重新验证并移除。
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
  SmtcService? _smtcService;

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
    unawaited(_smtcService?.dispose());
    final playlist = context.read<PlaylistProvider>();
    final history = context.read<HistoryProvider>();
    final favorites = context.read<FavoritesProvider>();
    unawaited(
      Future.wait([playlist.flush(), history.flush(), favorites.flush()]),
    );
    super.dispose();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    final apiSettings = context.read<ApiSettingsProvider>();
    final gdApi = context.read<GdMusicApiClient>();
    final downloadProvider = context.read<DownloadProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    final historyProvider = context.read<HistoryProvider>();
    final connectivity = context.read<ConnectivityService>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (!apiSettings.initialized) {
      await apiSettings.init();
    }
    await Future.wait([
      playlistProvider.ready,
      historyProvider.ready,
      favoritesProvider.ready,
    ]);

    if (!mounted) return;

    gdApi.updateBaseUrl(apiSettings.apiBaseUrl);
    gdApi.updateTimeoutSeconds(apiSettings.requestTimeout);
    downloadProvider.defaultQuality = apiSettings.downloadQuality.brValue;
    playerProvider.playQuality = apiSettings.playQuality.brValue;

    // 把网络熔断器接入 API 客户端
    connectivity.bindToApiClient(gdApi);

    // 初始化 Windows SMTC（仅 Windows 生效）
    _smtcService = SmtcService(playerProvider, playlistProvider);
    await _smtcService!.initialize();

    // 注册自动下一曲回调
    final previousComplete = playerProvider.onTrackComplete;
    playerProvider.onTrackComplete = () async {
      previousComplete?.call();
      // 记录到播放历史
      final current = playlistProvider.current;
      if (current != null) historyProvider.addTrack(current);

      // 单曲循环：重新播放当前
      if (playlistProvider.playMode == PlayMode.single && current != null) {
        await playerProvider.playTrack(current);
        return;
      }

      // 顺序模式到达末尾：停止
      if (playlistProvider.playMode == PlayMode.sequence &&
          playlistProvider.currentIndex >= playlistProvider.tracks.length - 1) {
        return;
      }

      // 其他模式：自动切换下一首
      playlistProvider.next();
      final next = playlistProvider.current;
      if (next != null) {
        await playerProvider.playTrackSmart(
          next,
          playlistProvider: playlistProvider,
        );
      }
    };

    _pulseController.stop();
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
                          final scale = 1.0 + 0.08 * _pulseController.value;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
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
                          letterSpacing: 0,
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
                        style: TextStyle(color: scheme.outline, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
