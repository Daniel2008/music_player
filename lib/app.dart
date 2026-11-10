import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'providers/visualizer_settings_provider.dart';
import 'services/gd_music_api.dart';
import 'services/connectivity_service.dart';
import 'services/smtc_service.dart';
import 'services/storage_service.dart';
import 'ui/widgets/window_close_guard.dart';
import 'platform/hotkeys.dart';
import 'ui/theme/app_design.dart';
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
        ChangeNotifierProvider(create: (_) => VisualizerSettingsProvider()),
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
          if (!kIsWeb && Platform.isWindows) {
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
  late final Future<void> Function() _saveOnClose;
  late final Future<void> _initialization;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    StorageService.instance.writeError.addListener(_onStorageError);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initialization = _initializeApp();
    // 渐入动画
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  void dispose() {
    StorageService.instance.writeError.removeListener(_onStorageError);
    _pulseController.dispose();
    unawaited(_smtcService?.dispose());
    super.dispose();
  }

  void _onStorageError() {
    if (!mounted ||
        !_initialized ||
        StorageService.instance.writeError.value == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本地数据保存失败，请检查磁盘空间和目录权限。关闭前会再次尝试保存。')),
    );
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
    _saveOnClose = () async {
      await _initialization;
      _closing = true;
      await Hotkeys.unregisterAll();
      await _smtcService?.dispose();
      try {
        await playerProvider.stop();
        await Future.wait([
          playlistProvider.flush(),
          historyProvider.flush(),
          favoritesProvider.flush(),
          downloadProvider.flushSettings(),
        ]);
      } catch (_) {
        _closing = false;
        await _smtcService?.initialize();
        await Hotkeys.register(playerProvider, playlistProvider);
        rethrow;
      }
    };

    if (!apiSettings.initialized) {
      await apiSettings.init();
    }
    await Future.wait([
      playlistProvider.ready,
      historyProvider.ready,
      favoritesProvider.ready,
      downloadProvider.ready,
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
      if (_closing) return;
      if (previousComplete != null) {
        await previousComplete();
      }
      if (_closing) return;
      // 记录到播放历史
      final current = playlistProvider.current;
      if (current != null) historyProvider.addTrack(current);

      // 单曲循环：重新播放当前
      if (playlistProvider.playMode == PlayMode.single && current != null) {
        await playerProvider.playTrackSmart(
          current,
          playlistProvider: playlistProvider,
        );
        return;
      }

      // 顺序模式到达末尾：停止
      if (playlistProvider.playMode == PlayMode.sequence &&
          playlistProvider.currentIndex >= playlistProvider.tracks.length - 1) {
        return;
      }

      // 其他模式：自动切换下一首。
      // 遇到无法播放的曲目时继续往后找，避免整个队列被一个坏文件卡住；
      // 重试次数以列表长度封顶，全部失败时不会陷入死循环。
      final trackCount = playlistProvider.tracks.length;
      final maxAttempts = trackCount <= 1
          ? 1
          : (trackCount > 20 ? 20 : trackCount);
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final indexBefore = playlistProvider.currentIndex;
        playlistProvider.next();
        // 顺序模式已到末尾时 next() 不会移动索引，避免重复试同一首。
        if (attempt > 0 && playlistProvider.currentIndex == indexBefore) {
          break;
        }
        final next = playlistProvider.current;
        if (next == null) break;
        final pending = playerProvider.playTrackSmart(
          next,
          playlistProvider: playlistProvider,
        );
        final generation = playerProvider.requestGeneration;
        final selectedIndex = playlistProvider.currentIndex;
        final played = await pending;
        if (_closing ||
            playerProvider.requestGeneration != generation ||
            playlistProvider.currentIndex != selectedIndex ||
            playlistProvider.current?.id != next.id) {
          return;
        }
        if (played) break;
      }
    };

    _pulseController.stop();
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) =>
      WindowCloseGuard(onSave: _saveOnClose, child: _buildContent(context));

  Widget _buildContent(BuildContext context) {
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
                      // 带呼吸缩放的品牌标识
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + 0.06 * _pulseController.value;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                scheme.primary,
                                Color.lerp(
                                  scheme.primary,
                                  scheme.tertiary,
                                  0.55,
                                )!,
                              ],
                            ),
                            borderRadius: AppRadius.xlAll,
                            boxShadow: AppShadows.glow(
                              scheme.primary,
                              alpha: 0.28,
                            ),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 40,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      Text(
                        'Music Player',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.primary,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '正在加载...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.5,
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
