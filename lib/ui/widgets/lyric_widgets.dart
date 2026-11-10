import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../theme/app_design.dart';

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
    final scheme = context.scheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(
          vertical: 7,
          horizontal: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              width: isActive ? 3 : 0,
              height: 24,
              margin: EdgeInsets.only(right: isActive ? AppSpacing.md : 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: AppRadius.xsAll,
                boxShadow: isActive
                    ? AppShadows.glow(scheme.primary, alpha: 0.35)
                    : null,
              ),
            ),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.medium,
                curve: AppMotion.curve,
                style: TextStyle(
                  fontSize: isActive
                      ? AppTypeScale.title
                      : AppTypeScale.body + 1,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(
                          alpha: distanceAlpha.clamp(0.5, 1.0),
                        ),
                  height: 1.35,
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
    final scheme = context.scheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    context.visual.panelMuted,
                  ],
                ),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(
                Icons.lyrics_outlined,
                size: 30,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              error ?? '暂无歌词',
              style: context.textStyles.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (isLocal && current != null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: const Text('搜索在线歌词'),
                onPressed: onSearch,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('自定义关键词搜索'),
                onPressed: onCustomSearch,
              ),
            ],
            if (current != null && current!.isRemote) ...[
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义搜索歌词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入歌曲名或歌手名进行搜索：',
              style: dialogContext.textStyles.bodySmall?.copyWith(
                color: dialogContext.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '例如：歌曲名 - 歌手'),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
