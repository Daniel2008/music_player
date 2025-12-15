import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/api_settings_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiUrlController = TextEditingController();
  bool _isTestingConnection = false;
  bool? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiSettings = context.read<ApiSettingsProvider>();
      _apiUrlController.text = apiSettings.apiBaseUrl;
    });
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final apiSettings = context.watch<ApiSettingsProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '设置',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // API 设置
        _buildSection(
          context,
          title: 'API 配置',
          icon: Icons.api_outlined,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API 地址',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiUrlController,
                          decoration: InputDecoration(
                            hintText: ApiSettingsProvider.defaultApiBaseUrl,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTestButton(apiSettings),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () async {
                          await apiSettings.setApiBaseUrl(
                            _apiUrlController.text,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('API 地址已保存')),
                            );
                          }
                        },
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                  if (_connectionTestResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            _connectionTestResult!
                                ? Icons.check_circle
                                : Icons.error,
                            size: 16,
                            color: _connectionTestResult!
                                ? Colors.green
                                : scheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _connectionTestResult! ? '连接成功' : '连接失败',
                            style: TextStyle(
                              fontSize: 12,
                              color: _connectionTestResult!
                                  ? Colors.green
                                  : scheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '请求超时',
              subtitle: '${apiSettings.requestTimeout} 秒',
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: apiSettings.requestTimeout.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 25,
                  label: '${apiSettings.requestTimeout}秒',
                  onChanged: (value) {
                    apiSettings.setRequestTimeout(value.round());
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '显示不稳定音乐源',
              subtitle: '部分源可能无法使用',
              trailing: Switch(
                value: apiSettings.showUnstableSources,
                onChanged: (value) {
                  apiSettings.setShowUnstableSources(value);
                },
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '重置为默认设置',
              subtitle: '恢复所有 API 相关设置',
              trailing: TextButton(
                onPressed: () => _confirmResetApiSettings(context, apiSettings),
                child: const Text('重置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 音乐源设置
        _buildSection(
          context,
          title: '音乐源',
          icon: Icons.library_music_outlined,
          children: [
            _buildTile(
              context,
              title: '默认音乐源',
              subtitle:
                  MusicSources.findById(apiSettings.defaultSource)?.name ??
                  apiSettings.defaultSource,
              trailing: PopupMenuButton<String>(
                initialValue: apiSettings.defaultSource,
                onSelected: (value) {
                  apiSettings.setDefaultSource(value);
                },
                itemBuilder: (context) => apiSettings.availableSources
                    .map(
                      (source) => PopupMenuItem(
                        value: source.id,
                        child: Row(
                          children: [
                            Text(source.name),
                            if (source.isStable) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '稳定',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      MusicSources.findById(apiSettings.defaultSource)?.name ??
                          apiSettings.defaultSource,
                      style: TextStyle(color: scheme.primary),
                    ),
                    Icon(Icons.arrow_drop_down, color: scheme.primary),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            ExpansionTile(
              title: const Text('启用的音乐源'),
              subtitle: Text('已启用 ${apiSettings.enabledSources.length} 个'),
              children: [
                ...MusicSources.all
                    .where((s) => s.isStable || apiSettings.showUnstableSources)
                    .map(
                      (source) => CheckboxListTile(
                        title: Text(source.name),
                        subtitle: source.isStable
                            ? const Text(
                                '稳定',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              )
                            : const Text(
                                '可能不稳定',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                        value: apiSettings.enabledSources.contains(source.id),
                        onChanged: (value) {
                          apiSettings.toggleSource(source.id, value ?? false);
                        },
                        dense: true,
                      ),
                    ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 音质设置
        _buildSection(
          context,
          title: '音质',
          icon: Icons.high_quality_outlined,
          children: [
            _buildTile(
              context,
              title: '在线播放音质',
              subtitle: apiSettings.playQuality.description,
              trailing: _buildQualitySelector(
                context,
                currentQuality: apiSettings.playQuality,
                onSelected: (quality) {
                  apiSettings.setPlayQuality(quality);
                },
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '下载音质',
              subtitle: apiSettings.downloadQuality.description,
              trailing: _buildQualitySelector(
                context,
                currentQuality: apiSettings.downloadQuality,
                onSelected: (quality) {
                  apiSettings.setDownloadQuality(quality);
                  downloadProvider.defaultQuality = quality.brValue;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 下载设置
        _buildSection(
          context,
          title: '下载',
          icon: Icons.download_outlined,
          children: [
            _buildTile(
              context,
              title: '默认下载目录',
              subtitle: downloadProvider.defaultDownloadPath ?? '未设置（每次询问）',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (downloadProvider.defaultDownloadPath != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        downloadProvider.setDefaultDownloadPath(null);
                      },
                      tooltip: '清除',
                    ),
                  FilledButton.tonal(
                    onPressed: () async {
                      await downloadProvider.selectDefaultDownloadPath();
                    },
                    child: const Text('选择'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '最大并行下载数',
              subtitle: '${downloadProvider.maxConcurrentDownloads} 个',
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: downloadProvider.maxConcurrentDownloads.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '${downloadProvider.maxConcurrentDownloads}',
                  onChanged: (value) {
                    downloadProvider.maxConcurrentDownloads = value.round();
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '自动开始下载',
              subtitle: '添加任务后自动开始',
              trailing: Switch(
                value: downloadProvider.autoStartDownload,
                onChanged: (value) {
                  downloadProvider.autoStartDownload = value;
                },
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '下载任务',
              subtitle:
                  '${downloadProvider.completedTasks.length} 已完成，${downloadProvider.downloadingTasks.length} 下载中',
              trailing: TextButton(
                onPressed: downloadProvider.allTasks.isEmpty
                    ? null
                    : () => _showDownloadManager(context),
                child: const Text('管理'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 歌词设置
        _buildSection(
          context,
          title: '歌词',
          icon: Icons.lyrics_outlined,
          children: [
            _buildTile(
              context,
              title: '自动搜索本地歌曲歌词',
              subtitle: '播放本地音乐时自动从网络搜索歌词',
              trailing: Switch(
                value: apiSettings.autoFetchLyric,
                onChanged: (value) {
                  apiSettings.setAutoFetchLyric(value);
                  playerProvider.autoFetchLyricForLocal = value;
                },
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '歌词缓存',
              subtitle: '已缓存 ${playerProvider.localLyricPaths.length} 首本地歌曲歌词',
              trailing: TextButton(
                onPressed: playerProvider.localLyricPaths.isEmpty
                    ? null
                    : () => _confirmClearLyricCache(context, playerProvider),
                child: const Text('清除'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 外观设置
        _buildSection(
          context,
          title: '外观',
          icon: Icons.palette_outlined,
          children: [
            _buildTile(
              context,
              title: '主题模式',
              subtitle: _themeModeText(theme.mode),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {theme.mode},
                onSelectionChanged: (s) => theme.setMode(s.first),
              ),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '主题皮肤',
              subtitle: '选择预设皮肤或自定义',
              onTap: () => _showSkinPicker(context, theme),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 快捷键
        _buildSection(
          context,
          title: '快捷键',
          icon: Icons.keyboard_outlined,
          children: [
            _buildTile(
              context,
              title: '播放/暂停',
              trailing: _buildShortcut('Ctrl+Alt+P'),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '上一首',
              trailing: _buildShortcut('Ctrl+Alt+←'),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '下一首',
              trailing: _buildShortcut('Ctrl+Alt+→'),
            ),
            const Divider(height: 1),
            _buildTile(context, title: '全屏频谱', trailing: _buildShortcut('F11')),
          ],
        ),
        const SizedBox(height: 16),

        // 关于
        _buildSection(
          context,
          title: '关于',
          icon: Icons.info_outline,
          children: [
            _buildTile(
              context,
              title: '版本',
              trailing: Text('v1.0.0', style: TextStyle(color: scheme.outline)),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '音乐 API',
              subtitle: 'GD 音乐台 (music.gdstudio.xyz)',
              trailing: Icon(
                Icons.open_in_new,
                color: scheme.outline,
                size: 20,
              ),
              onTap: () {
                // TODO: 打开链接
              },
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '免责声明',
              subtitle: '本应用仅供学习交流使用',
              onTap: () => _showDisclaimer(context),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTestButton(ApiSettingsProvider apiSettings) {
    return FilledButton.tonal(
      onPressed: _isTestingConnection
          ? null
          : () async {
              setState(() {
                _isTestingConnection = true;
                _connectionTestResult = null;
              });

              // 临时更新 URL 进行测试
              final originalUrl = apiSettings.apiBaseUrl;
              await apiSettings.setApiBaseUrl(_apiUrlController.text);

              final result = await apiSettings.testConnection();

              // 如果测试失败，恢复原来的 URL
              if (!result) {
                await apiSettings.setApiBaseUrl(originalUrl);
              }

              setState(() {
                _isTestingConnection = false;
                _connectionTestResult = result;
              });
            },
      child: _isTestingConnection
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('测试'),
    );
  }

  Widget _buildQualitySelector(
    BuildContext context, {
    required AudioQuality currentQuality,
    required ValueChanged<AudioQuality> onSelected,
  }) {
    return PopupMenuButton<AudioQuality>(
      initialValue: currentQuality,
      onSelected: onSelected,
      itemBuilder: (context) => AudioQuality.values
          .map(
            (quality) => PopupMenuItem(
              value: quality,
              child: Row(
                children: [
                  Text(quality.label),
                  const SizedBox(width: 8),
                  Text(
                    quality.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentQuality.label,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  void _confirmResetApiSettings(
    BuildContext context,
    ApiSettingsProvider apiSettings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置 API 设置'),
        content: const Text('确定要将所有 API 相关设置恢复为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              apiSettings.resetToDefaults();
              _apiUrlController.text = ApiSettingsProvider.defaultApiBaseUrl;
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已重置为默认设置')));
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _showDownloadManager(BuildContext context) {
    final downloadProvider = context.read<DownloadProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('下载管理', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (downloadProvider.failedTasks.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => downloadProvider.retryAllFailed(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重试全部'),
                    ),
                  if (downloadProvider.completedTasks.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => downloadProvider.clearCompleted(),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('清除已完成'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: downloadProvider.allTasks.isEmpty
                  ? const Center(child: Text('暂无下载任务'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: downloadProvider.allTasks.length,
                      itemBuilder: (context, index) {
                        final task = downloadProvider.allTasks[index];
                        return _buildDownloadTaskTile(context, task);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadTaskTile(BuildContext context, DownloadTask task) {
    final scheme = Theme.of(context).colorScheme;

    IconData statusIcon;
    Color statusColor;
    switch (task.status) {
      case DownloadStatus.pending:
        statusIcon = Icons.schedule;
        statusColor = scheme.outline;
        break;
      case DownloadStatus.downloading:
        statusIcon = Icons.downloading;
        statusColor = scheme.primary;
        break;
      case DownloadStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case DownloadStatus.failed:
        statusIcon = Icons.error;
        statusColor = scheme.error;
        break;
      case DownloadStatus.cancelled:
        statusIcon = Icons.cancel;
        statusColor = scheme.outline;
        break;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(
        task.track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.track.artistText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          if (task.status == DownloadStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: task.progress,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.progressDisplay,
                    style: TextStyle(fontSize: 10, color: scheme.outline),
                  ),
                ],
              ),
            ),
          if (task.status == DownloadStatus.failed && task.error != null)
            Text(
              task.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: scheme.error),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.status == DownloadStatus.failed ||
              task.status == DownloadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () =>
                  context.read<DownloadProvider>().retryDownload(task.id),
              tooltip: '重试',
            ),
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.pending)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => context.read<DownloadProvider>().cancelDownload(
                task.track.source,
                task.track.id,
              ),
              tooltip: '取消',
            ),
          if (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () =>
                  context.read<DownloadProvider>().removeTask(task.id),
              tooltip: '移除',
            ),
        ],
      ),
    );
  }

  void _confirmClearLyricCache(
    BuildContext context,
    PlayerProvider playerProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除歌词缓存'),
        content: Text(
          '确定要清除所有已缓存的本地歌曲歌词吗？（共 ${playerProvider.localLyricPaths.length} 首）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              playerProvider.localLyricPaths.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('歌词缓存已清除')));
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('免责声明'),
        content: const SingleChildScrollView(
          child: Text(
            '本应用仅供学习和研究使用，不得用于商业用途。\n\n'
            '本应用使用的音乐资源来自网络，版权归原作者所有。如有侵权，请联系我们删除。\n\n'
            '使用本应用即表示您同意以上条款。',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  String _themeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  void _showSkinPicker(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择皮肤', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _skinOption(context, theme, '默认', Colors.blue, null),
                _skinOption(
                  context,
                  theme,
                  '经典蓝',
                  Colors.indigo,
                  'classic_blue',
                ),
                _skinOption(context, theme, '森林暗色', Colors.teal, 'forest_dark'),
                _skinOption(context, theme, '玫瑰粉', Colors.pink, 'rose_pink'),
                _skinOption(
                  context,
                  theme,
                  '日落橙',
                  Colors.orange,
                  'sunset_orange',
                ),
                _skinOption(context, theme, '薰衣草', Colors.purple, 'lavender'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _skinOption(
    BuildContext context,
    ThemeProvider theme,
    String name,
    Color color,
    String? skinFile,
  ) {
    return InkWell(
      onTap: () {
        if (skinFile != null) {
          theme.loadSkin('assets/skins/$skinFile.json');
        }
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            CircleAvatar(backgroundColor: color, radius: 20),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildShortcut(String keys) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keys,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
