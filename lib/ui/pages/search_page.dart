import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/gd_music_api.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const _sources = [
    ('netease', '网易云'),
    ('tencent', 'QQ音乐'),
    ('kugou', '酷狗'),
    ('kuwo', '酷我'),
    ('migu', '咪咕'),
    ('spotify', 'Spotify'),
    ('ytmusic', 'YouTube'),
    ('apple', 'Apple'),
  ];

  static const _qualities = [
    ('128', '标准 128k'),
    ('192', '较高 192k'),
    ('320', '高品 320k'),
    ('999', '无损'),
  ];

  String _source = 'netease';
  String _quality = '320';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(PlayerProvider p) {
    final q = _controller.text.trim();
    if (q.isNotEmpty) {
      p.searchOnline(q, source: _source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 搜索栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在线音乐搜索',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '搜索歌曲、歌手、专辑...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  p.searchOnline('');
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: scheme.surface,
                      ),
                      onSubmitted: (_) => _search(p),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: p.isSearching ? null : () => _search(p),
                    icon: p.isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  // 音乐源选择
                  _buildChipSelector(
                    label: '音乐源',
                    value: _source,
                    items: _sources,
                    onChanged: (v) {
                      setState(() => _source = v);
                      if (_controller.text.trim().isNotEmpty) {
                        _search(p);
                      }
                    },
                  ),
                  // 音质选择
                  _buildChipSelector(
                    label: '音质',
                    value: _quality,
                    items: _qualities,
                    onChanged: (v) => setState(() => _quality = v),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 搜索结果
        Expanded(
          child: p.searchError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text(
                        p.searchError!,
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : p.searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: scheme.outline.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '输入关键词搜索音乐',
                        style: TextStyle(color: scheme.outline, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : _SearchResultList(items: p.searchResults, quality: _quality),
        ),
      ],
    );
  }

  Widget _buildChipSelector({
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 13)),
        PopupMenuButton<String>(
          initialValue: value,
          onSelected: onChanged,
          child: Chip(
            label: Text(
              items.firstWhere((e) => e.$1 == value).$2,
              style: const TextStyle(fontSize: 13),
            ),
            avatar: const Icon(Icons.arrow_drop_down, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          itemBuilder: (context) => items
              .map((e) => PopupMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
        ),
      ],
    );
  }
}

class _SearchResultList extends StatelessWidget {
  final List<GdSearchTrack> items;
  final String quality;

  const _SearchResultList({required this.items, required this.quality});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final t = items[index];
        final isDownloading = p.isDownloading(t.source, t.id);
        final downloadProgress = p.getDownloadProgress(t.source, t.id);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            [
              t.artistText,
              t.album,
              t.source,
            ].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  p.favorites.isFavorite(t)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: p.favorites.isFavorite(t) ? Colors.red : null,
                ),
                tooltip: p.favorites.isFavorite(t) ? '取消收藏' : '收藏',
                onPressed: () async {
                  await p.toggleFavorite(t);
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
              // 下载按钮
              isDownloading
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: downloadProgress,
                            strokeWidth: 2.5,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                          Text(
                            '${(downloadProgress * 100).toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: '下载',
                      onPressed: () => _downloadTrack(context, p, t),
                    ),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: '添加到播放列表',
                onPressed: () async {
                  final ok = await p.playSearchResult(t, br: quality);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: Text(p.playError ?? '添加失败')),
                      );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_filled),
                tooltip: '立即播放',
                color: scheme.primary,
                onPressed: () async {
                  final ok = await p.playSearchResult(t, br: quality);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: Text(p.playError ?? '播放失败')),
                      );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadTrack(
    BuildContext context,
    PlayerProvider p,
    GdSearchTrack t,
  ) async {
    final result = await p.downloadTrack(t, br: quality);
    if (!context.mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('下载完成: ${t.name}'),
            action: SnackBarAction(
              label: '打开位置',
              onPressed: () async {
                // 打开文件所在目录
                final dir = result.substring(0, result.lastIndexOf('\\'));
                await Process.run('explorer', [dir]);
              },
            ),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('下载失败: ${p.playError ?? '未知错误'}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }
}
