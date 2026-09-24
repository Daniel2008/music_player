import 'package:flutter/material.dart';

import '../../providers/theme_provider.dart';
import 'settings_widgets.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key, required this.theme});

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: '外观',
      icon: Icons.palette_outlined,
      children: [
        SettingsTile(
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
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
            ],
            selected: {theme.mode},
            onSelectionChanged: (selection) => theme.setMode(selection.first),
          ),
        ),
        const Divider(height: 1),
        SettingsTile(
          title: '主题皮肤',
          subtitle: '选择预设皮肤或自定义',
          onTap: () => _showSkinPicker(context),
        ),
      ],
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

  void _showSkinPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择主题色', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '选择一种颜色作为应用的主题色',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: ThemeProvider.presetColors.map((preset) {
                  final isSelected =
                      theme.seedColor.toARGB32() == preset.color.toARGB32();
                  return InkWell(
                    onTap: () {
                      theme.setSeedColor(preset.color);
                      setSheetState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? preset.color
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? preset.color.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: preset.color,
                                radius: 18,
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            preset.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? preset.color
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
