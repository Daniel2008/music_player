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
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final playlistProvider = PlaylistProvider();
            playlistProvider.init(); // 异步加载保存的播放列表
            return playlistProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Flutter Desktop Music Player',
            themeMode: theme.mode,
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            home: const _AppInitializer(),
          );
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

class _AppInitializerState extends State<_AppInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    final apiSettings = context.read<ApiSettingsProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    // 等待 API 设置初始化完成
    if (!apiSettings.initialized) {
      await apiSettings.init();
    }

    if (!mounted) return;

    // 将 API 设置同步到下载管理器
    downloadProvider.updateApiBaseUrl(apiSettings.apiBaseUrl);
    downloadProvider.updateTimeout(apiSettings.requestTimeout);
    downloadProvider.defaultQuality = apiSettings.downloadQuality.brValue;

    // 同步歌词自动搜索设置
    playerProvider.autoFetchLyricForLocal = apiSettings.autoFetchLyric;

    // 注册自动下一曲回调
    playerProvider.onTrackComplete = () {
      playlistProvider.next();
      if (playlistProvider.current != null) {
        playerProvider.playTrack(playlistProvider.current!);
      }
    };

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // 显示加载画面
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在加载...',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return const MainLayout();
  }
}
