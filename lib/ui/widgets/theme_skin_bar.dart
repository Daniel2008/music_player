import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSkinBar extends StatelessWidget {
  const ThemeSkinBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.dark_mode),
          onPressed: () => theme.setMode(ThemeMode.dark),
        ),
        IconButton(
          icon: const Icon(Icons.light_mode),
          onPressed: () => theme.setMode(ThemeMode.light),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.color_lens),
          onSelected: (v) => theme.loadSkin('assets/skins/$v.json'),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'classic_blue', child: Text('经典蓝')),
            PopupMenuItem(value: 'forest_dark', child: Text('森林暗色')),
          ],
        ),
      ],
    );
  }
}
