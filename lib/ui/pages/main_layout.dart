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
  late final AnimationController _navAnimationController;
  final bool _isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
    _navAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.mode == ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final isDesktop = _isDesktop;

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
                    // 主内容区域
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: IndexedStack(
                              index: _selectedIndex,
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
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surface.withValues(alpha: 0.92)
              : scheme.surface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.music_note_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Music Player',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
            ),
            const Expanded(child: SizedBox()),
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
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose
              ? const Color(0xFFE81123).withValues(alpha: 0.9)
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
    final theme = context.read<ThemeProvider>();

    return Container(
      width: isWide ? 84 : 68,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF12121A)
            : scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // 导航项
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  for (int i = 0; i < _navItems.length; i++) ...[
                    _buildNavItem(context, i, scheme, isDark),
                    if (i < _navItems.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          // 底部操作区域
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 主题切换按钮
                _buildThemeToggle(context, theme, isDark, scheme),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    ColorScheme scheme,
    bool isDark,
  ) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onDestinationSelected(index),
            borderRadius: BorderRadius.circular(16),
            hoverColor: scheme.primary.withValues(alpha: 0.06),
            splashColor: scheme.primary.withValues(alpha: 0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 药丸形选中指示器
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 48 : 0,
                        height: 28,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(
                            alpha: value * 0.9,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      // 图标带轻微弹跳缩放
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 1.0,
                          end: isSelected ? 1.1 : 1.0,
                        ),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: Color.lerp(
                            scheme.onSurfaceVariant.withValues(alpha: 0.7),
                            scheme.primary,
                            value,
                          ),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: Color.lerp(
                        scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        scheme.onSurface,
                        value,
                      ),
                      letterSpacing: 0.2,
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
          hoverColor: scheme.primary.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
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
                size: 18,
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
