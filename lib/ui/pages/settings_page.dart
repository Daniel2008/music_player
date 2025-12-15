import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
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

        // 播放设置
        _buildSection(
          context,
          title: '播放',
          icon: Icons.play_circle_outline,
          children: [
            _buildTile(
              context,
              title: '默认音质',
              subtitle: '在线播放默认音质',
              trailing: const Chip(label: Text('320kbps')),
            ),
            const Divider(height: 1),
            _buildTile(
              context,
              title: '淡入淡出',
              subtitle: '切歌时平滑过渡',
              trailing: Switch(value: false, onChanged: (_) {}),
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
              subtitle: 'GD 音乐台',
              trailing: Icon(
                Icons.open_in_new,
                color: scheme.outline,
                size: 20,
              ),
              onTap: () {},
            ),
          ],
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
