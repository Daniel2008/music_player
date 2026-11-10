import 'package:flutter/material.dart';

import '../../providers/theme_provider.dart';
import '../theme/app_design.dart';
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
                icon: Icon(Icons.light_mode_rounded, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 18),
              ),
            ],
            selected: {theme.mode},
            onSelectionChanged: (selection) => theme.setMode(selection.first),
            showSelectedIcon: false,
          ),
        ),
        Divider(height: 1, color: context.visual.border),
        SettingsTile(
          title: '主题皮肤',
          subtitle: '选择预设主题色，界面配色会同步变化',
          onTap: () => _showSkinPicker(context),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.scheme.onSurfaceVariant,
          ),
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
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).dialogTheme.backgroundColor ??
                      scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: context.visual.border),
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '选择主题色',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '选择一种颜色作为应用主题色，背景与强调色会一起调整。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: ThemeProvider.presetColors.map((preset) {
                          final isSelected =
                              theme.seedColor.toARGB32() ==
                              preset.color.toARGB32();
                          final onSeed = preset.color.computeLuminance() > 0.5
                              ? const Color(0xFF1A1A1A)
                              : Colors.white;
                          return AnimatedContainer(
                            duration: AppMotion.normal,
                            curve: AppMotion.curve,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? preset.color.withValues(alpha: 0.12)
                                  : scheme.surfaceContainerHigh.withValues(
                                      alpha: 0.6,
                                    ),
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(
                                color: isSelected
                                    ? preset.color
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.7,
                                      ),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                theme.setSeedColor(preset.color);
                                setSheetState(() {});
                              },
                              borderRadius: AppRadius.mdAll,
                              hoverColor: preset.color.withValues(alpha: 0.08),
                              child: SizedBox(
                                width: 80,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: preset.color,
                                          shape: BoxShape.circle,
                                          boxShadow: isSelected
                                              ? AppShadows.glow(
                                                  preset.color,
                                                  alpha: 0.35,
                                                )
                                              : null,
                                        ),
                                        child: isSelected
                                            ? Icon(
                                                Icons.check_rounded,
                                                color: onSeed,
                                                size: 22,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        preset.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: isSelected
                                                  ? scheme.primary
                                                  : scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
