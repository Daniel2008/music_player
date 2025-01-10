import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'music_player_state.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key});

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentSong(int? currentIndex) {
    if (currentIndex != null && _scrollController.hasClients) {
      final itemHeight = 48.0; // ListTile 的标准高度
      _scrollController.animateTo(
        currentIndex * itemHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '播放列表',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Consumer<MusicPlayerState>(
                  builder: (context, state, child) {
                    return Text(
                      '${state.playlist.length} 首歌曲',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MusicPlayerState>(
              builder: (context, state, child) {
                if (state.currentIndex != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToCurrentSong(state.currentIndex);
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: state.playlist.length,
                  itemBuilder: (context, index) {
                    final song = state.playlist[index];
                    final isPlaying = state.currentIndex == index;
                    
                    return GestureDetector(
                      onSecondaryTapUp: (details) {
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx + 1,
                            details.globalPosition.dy + 1,
                          ),
                          items: [
                            PopupMenuItem(
                              child: const Text('播放'),
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  state.setCurrentSong(song);
                                });
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('删除'),
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('删除歌曲'),
                                      content: const Text('确定要从磁盘中永久删除这首歌曲吗？此操作无法撤销。'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            final success = await state.removeSong(song);
                                            if (!success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('删除文件失败'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('删除', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                });
                              },
                            ),
                          ],
                        );
                      },
                      onDoubleTap: () {
                        state.setCurrentSong(song);
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ListTile(
                          title: Text(
                            File(song).uri.pathSegments.last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPlaying
                                  ? Colors.blue
                                  : null,
                            ),
                          ),
                          selected: isPlaying,
                          onTap: null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
