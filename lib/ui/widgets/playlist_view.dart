import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/gd_music_api.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key});

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final TextEditingController _controller = TextEditingController();

  static const List<String> _sources = [
    'netease',
    'kuwo',
    'joox',
    'tencent',
    'kugou',
    'migu',
    'apple',
    'spotify',
    'ytmusic',
    'deezer',
    'tidal',
    'qobuz',
    'ximalaya',
  ];

  static const List<String> _brs = ['128', '192', '320', '740', '999'];

  String _source = 'netease';
  String _br = '999';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final query = _controller.text.trim();
    final showingSearch = query.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '在线搜索（GD 音乐台）',
                      ),
                      onSubmitted: (v) => p.searchOnline(v, source: _source),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _source,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: '源',
                      ),
                      items: _sources
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(
                                s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v == null || v == _source) return;
                        setState(() => _source = v);
                        if (showingSearch) {
                          p.searchOnline(_controller.text, source: _source);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: _br,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: '音质',
                      ),
                      items: _brs
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(
                                s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v == null || v == _br) return;
                        setState(() => _br = v);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: p.isSearching
                        ? null
                        : () =>
                              p.searchOnline(_controller.text, source: _source),
                    icon: p.isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: p.addFiles,
                    icon: const Icon(Icons.library_music),
                    label: const Text('添加本地'),
                  ),
                  if (showingSearch)
                    IconButton(
                      tooltip: '清空',
                      onPressed: () {
                        _controller.clear();
                        p.searchOnline('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (showingSearch && p.searchError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(
              p.searchError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: showingSearch
              ? _SearchResultsList(items: p.searchResults, br: _br)
              : _PlaylistList(),
        ),
      ],
    );
  }
}

class _PlaylistList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final items = p.playlist.tracks;
    final current = p.playlist.current;
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = items[index];
        final selected = current?.id == t.id;
        return ListTile(
          selected: selected,
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            p.playlist.currentIndex = index;
            p.playCurrent();
          },
        );
      },
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final List<GdSearchTrack> items;
  final String br;

  const _SearchResultsList({required this.items, required this.br});

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerProvider>();
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = items[index];
        final subtitleParts = <String>[];
        if (t.artistText.isNotEmpty) subtitleParts.add(t.artistText);
        if (t.album.isNotEmpty) subtitleParts.add(t.album);
        subtitleParts.add(t.source);
        return ListTile(
          title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            subtitleParts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.play_arrow),
          onTap: () async {
            final ok = await p.playSearchResult(t, br: br);
            if (!ok && context.mounted) {
              final msg = p.playError ?? '播放失败';
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        );
      },
    );
  }
}
