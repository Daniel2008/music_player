import 'package:flutter/material.dart';

import '../../providers/api_settings_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import 'download_manager_sheet.dart';
import 'settings_widgets.dart';

class MusicSourceSettingsSection extends StatelessWidget {
  const MusicSourceSettingsSection({super.key, required this.apiSettings});

  final ApiSettingsProvider apiSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedSource =
        MusicSources.findById(apiSettings.defaultSource)?.name ??
        apiSettings.defaultSource;

    return SettingsSection(
      title: '音乐源',
      icon: Icons.library_music_outlined,
      children: [
        SettingsTile(
          title: '默认音乐源',
          subtitle: selectedSource,
          trailing: PopupMenuButton<String>(
            initialValue: apiSettings.defaultSource,
            onSelected: apiSettings.setDefaultSource,
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
                Text(selectedSource, style: TextStyle(color: scheme.primary)),
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
                            style: TextStyle(color: Colors.green, fontSize: 12),
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
    );
  }
}

class AudioQualitySettingsSection extends StatelessWidget {
  const AudioQualitySettingsSection({
    super.key,
    required this.apiSettings,
    required this.downloadProvider,
    required this.playerProvider,
  });

  final ApiSettingsProvider apiSettings;
  final DownloadProvider downloadProvider;
  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: '音质',
      icon: Icons.high_quality_outlined,
      children: [
        SettingsTile(
          title: '在线播放音质',
          subtitle: apiSettings.playQuality.description,
          trailing: _QualitySelector(
            currentQuality: apiSettings.playQuality,
            onSelected: (quality) async {
              await apiSettings.setPlayQuality(quality);
              playerProvider.playQuality = quality.brValue;
            },
          ),
        ),
        const Divider(height: 1),
        SettingsTile(
          title: '下载音质',
          subtitle: apiSettings.downloadQuality.description,
          trailing: _QualitySelector(
            currentQuality: apiSettings.downloadQuality,
            onSelected: (quality) {
              apiSettings.setDownloadQuality(quality);
              downloadProvider.defaultQuality = quality.brValue;
            },
          ),
        ),
      ],
    );
  }
}

class DownloadSettingsSection extends StatelessWidget {
  const DownloadSettingsSection({super.key, required this.downloadProvider});

  final DownloadProvider downloadProvider;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: '下载',
      icon: Icons.download_outlined,
      children: [
        SettingsTile(
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
                onPressed: downloadProvider.selectDefaultDownloadPath,
                child: const Text('选择'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SettingsTile(
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
        SettingsTile(
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
        SettingsTile(
          title: '下载任务',
          subtitle:
              '${downloadProvider.completedTasks.length} 已完成，${downloadProvider.downloadingTasks.length} 下载中',
          trailing: TextButton(
            onPressed: downloadProvider.allTasks.isEmpty
                ? null
                : () => showDownloadManagerSheet(context),
            child: const Text('管理'),
          ),
        ),
      ],
    );
  }
}

class LyricSettingsSection extends StatelessWidget {
  const LyricSettingsSection({
    super.key,
    required this.apiSettings,
    required this.playerProvider,
  });

  final ApiSettingsProvider apiSettings;
  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: '歌词',
      icon: Icons.lyrics_outlined,
      children: [
        SettingsTile(
          title: '自动搜索本地歌曲歌词',
          subtitle: '播放本地音乐时自动从网络搜索歌词',
          trailing: Switch(
            value: apiSettings.autoFetchLyric,
            onChanged: apiSettings.setAutoFetchLyric,
          ),
        ),
        const Divider(height: 1),
        SettingsTile(
          title: '歌词缓存',
          subtitle:
              '已缓存 ${playerProvider.lyricService.localLyricPaths.length} 首本地歌曲歌词',
          trailing: TextButton(
            onPressed: playerProvider.lyricService.localLyricPaths.isEmpty
                ? null
                : () => _confirmClearLyricCache(context),
            child: const Text('清除'),
          ),
        ),
      ],
    );
  }

  void _confirmClearLyricCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除歌词缓存'),
        content: Text(
          '确定要清除所有已缓存的本地歌曲歌词吗？（共 ${playerProvider.lyricService.localLyricPaths.length} 首）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              playerProvider.lyricService.localLyricPaths.clear();
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
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({
    required this.currentQuality,
    required this.onSelected,
  });

  final AudioQuality currentQuality;
  final ValueChanged<AudioQuality> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currentQuality.label, style: TextStyle(color: scheme.primary)),
          Icon(Icons.arrow_drop_down, color: scheme.primary),
        ],
      ),
    );
  }
}
