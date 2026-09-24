import 'package:flutter/material.dart';

import '../../models/track.dart';

class LyricLineTile extends StatelessWidget {
  const LyricLineTile({
    super.key,
    required this.text,
    required this.isActive,
    required this.distanceAlpha,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final double distanceAlpha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 3,
              height: isActive ? 28 : 0,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isActive ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
            ),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isActive ? 22 : 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(
                          alpha: distanceAlpha,
                        ),
                  height: 1.6,
                  letterSpacing: 0,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: scheme.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                          Shadow(
                            color: scheme.primary.withValues(alpha: 0.15),
                            blurRadius: 32,
                          ),
                        ]
                      : [],
                ),
                child: Text(text, textAlign: TextAlign.center, softWrap: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LyricEmptyState extends StatelessWidget {
  const LyricEmptyState({
    super.key,
    required this.error,
    required this.current,
    required this.isLocal,
    required this.onSearch,
    required this.onCustomSearch,
    required this.onRefetch,
  });

  final String? error;
  final Track? current;
  final bool isLocal;
  final VoidCallback onSearch;
  final VoidCallback onCustomSearch;
  final VoidCallback onRefetch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 48,
              color: scheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              error ?? '暂无歌词',
              style: TextStyle(color: scheme.outline, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (isLocal && current != null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('搜索在线歌词'),
                onPressed: onSearch,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('自定义关键词搜索'),
                onPressed: onCustomSearch,
              ),
            ],
            if (current != null && current!.isRemote) ...[
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重新获取歌词'),
                onPressed: onRefetch,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<String?> showCustomLyricSearchDialog(
  BuildContext context, {
  required String initialKeyword,
}) async {
  final controller = TextEditingController(text: initialKeyword);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义搜索歌词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入歌曲名或歌手名进行搜索：',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：歌曲名 - 歌手',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
