import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../providers/theme_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/hotkey_binder.dart';
import 'player_page.dart';
import 'search_page.dart';
import 'favorites_page.dart';
import 'settings_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final AnimationController _navAnimationController;

  static const _pages = [
    PlayerPage(),
    SearchPage(),
    FavoritesPage(),
    SettingsPage(),
  ];

  static const _navItems = [
    _NavItem(
      icon: Icons.play_circle_outline,
      selectedIcon: Icons.play_circle,
      label: '播放',
    ),
    _NavItem(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      label: '搜索',
    ),
    _NavItem(
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite,
      label: '收藏',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _navAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.mode == ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      body: Stack(
        children: [
          const HotkeyBinder(),
          Column(
            children: [
              // 自定义标题栏（仅桌面平台）
              if (isDesktop) _buildTitleBar(context, scheme, isDark),
              // 主内容
              Expanded(
                child: Row(
                  children: [
                    // 侧边导航栏
                    _buildNavigationRail(context, scheme, isDark, isWide),
                    // 分割线
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    // 主内容区域
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: _pages,
                            ),
                          ),
                          const MiniPlayer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, ColorScheme scheme, bool isDark) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            // 应用图标
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            // 应用标题
            Text(
              'Music Player',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            // 拖拽区域
            const Expanded(child: SizedBox()),
            // 窗口控制按钮
            _buildWindowButton(
              icon: Icons.remove_rounded,
              onPressed: () => windowManager.minimize(),
              scheme: scheme,
            ),
            _buildWindowButton(
              icon: Icons.crop_square_rounded,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              scheme: scheme,
            ),
            _buildWindowButton(
              icon: Icons.close_rounded,
              onPressed: () => windowManager.close(),
              scheme: scheme,
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme scheme,
    bool isClose = false,
  }) {
    return SizedBox(
      width: 46,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose
              ? Colors.red.withValues(alpha: 0.9)
              : scheme.onSurface.withValues(alpha: 0.08),
          child: Icon(
            icon,
            size: 16,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    bool isWide,
  ) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      width: isWide ? 88 : 72,
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // 导航项
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (int i = 0; i < _navItems.length; i++) ...[
                    _buildNavItem(context, i, scheme),
                    if (i < _navItems.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          // 底部操作区域
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 主题切换按钮
                _buildThemeToggle(context, theme, isDark, scheme),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, ColorScheme scheme) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onDestinationSelected(index),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.transparent,
                  scheme.primaryContainer,
                  value,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: Color.lerp(
                      scheme.onSurfaceVariant,
                      scheme.onPrimaryContainer,
                      value,
                    ),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        scheme.onSurface,
                        value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeToggle(
    BuildContext context,
    ThemeProvider theme,
    bool isDark,
    ColorScheme scheme,
  ) {
    return Tooltip(
      message: isDark ? '切换到浅色模式' : '切换到深色模式',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => theme.setMode(isDark ? ThemeMode.light : ThemeMode.dark),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
