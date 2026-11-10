import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../theme/app_design.dart';

/// 主题/皮肤快捷栏（当前未挂到页面，保留以备用）。
class ThemeSkinBar extends StatelessWidget {
  const ThemeSkinBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final scheme = context.scheme;
    final visual = context.visual;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: visual.panel,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: visual.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '深色模式',
            child: IconButton(
              icon: const Icon(Icons.dark_mode_rounded, size: 19),
              onPressed: () => theme.setMode(ThemeMode.dark),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? visual.selected : null,
                foregroundColor: isDark ? scheme.primary : null,
              ),
            ),
          ),
          Tooltip(
            message: '浅色模式',
            child: IconButton(
              icon: const Icon(Icons.light_mode_rounded, size: 19),
              onPressed: () => theme.setMode(ThemeMode.light),
              style: IconButton.styleFrom(
                backgroundColor: !isDark ? visual.selected : null,
                foregroundColor: !isDark ? scheme.primary : null,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.color_lens_rounded,
              size: 19,
              color: scheme.primary,
            ),
            tooltip: '主题皮肤',
            onSelected: (v) => theme.loadSkin('assets/skins/$v.json'),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'classic_blue', child: Text('经典蓝')),
              PopupMenuItem(value: 'forest_dark', child: Text('森林暗色')),
            ],
          ),
        ],
      ),
    );
  }
}
