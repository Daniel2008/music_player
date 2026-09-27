import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../providers/theme_provider.dart';
import '../widgets/mini_player_v2.dart';
import '../widgets/hotkey_binder.dart';
import 'player_workspace_page_v3.dart';
import 'search_page.dart';
import 'favorites_workspace_page.dart';
import 'history_workspace_page.dart';
import 'settings_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final bool _isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  late final List<Widget?> _pages = [
    const PlayerWorkspacePage(),
    null,
    null,
    null,
    null,
  ];

  static const _navItems = [
    _NavItem(
      icon: Icons.graphic_eq_rounded,
      selectedIcon: Icons.graphic_eq_rounded,
      label: '播放',
    ),
    _NavItem(
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
      label: '搜索',
    ),
    _NavItem(
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music_rounded,
      label: '收藏',
    ),
    _NavItem(
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      label: '历史',
    ),
    _NavItem(
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      label: '设置',
    ),
  ];

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _pages[index] ??= _buildPage(index);
      _selectedIndex = index;
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 1:
        return const SearchPage();
      case 2:
        return const FavoritesWorkspacePage();
      case 3:
        return const HistoryWorkspacePage();
      case 4:
        return const SettingsPage();
      default:
        return const PlayerWorkspacePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1080;
    final useBottomNavigation = width < 720;
    final isDesktop = _isDesktop;

    return Scaffold(
      body: Stack(
        children: [
          const HotkeyBinder(),
          Column(
            children: [
              // 自定义标题栏（仅桌面平台）
              if (isDesktop) _buildTitleBar(context, scheme),
              // 主内容
              Expanded(
                child: Row(
                  children: [
                    // 小窗口切换为底部导航，避免内容区被侧栏挤压。
                    if (!useBottomNavigation)
                      _buildNavigationRail(context, scheme, isDark, isWide),
                    // 主内容区域
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            // 使用 Offstage+TickerMode 代替 IndexedStack
                            // 不可见页面的 Ticker 被禁用，动画自动暂停
                            child: Stack(
                              children: [
                                for (int i = 0; i < _pages.length; i++)
                                  if (_pages[i] != null)
                                    Offstage(
                                      offstage: _selectedIndex != i,
                                      child: TickerMode(
                                        enabled: _selectedIndex == i,
                                        child: _pages[i]!,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          const MiniPlayer(),
                          if (useBottomNavigation)
                            _buildBottomNavigation(context, scheme),
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

  Widget _buildTitleBar(BuildContext context, ColorScheme scheme) {
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
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
        height: 48,
        decoration: BoxDecoration(
          color: visual.sidebar,
          border: Border(bottom: BorderSide(color: visual.border, width: 1)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 16,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'Music Player',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
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
      width: 44,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isClose
              ? const Color(0xFFE81123).withValues(alpha: 0.9)
              : scheme.onSurface.withValues(alpha: 0.08),
          child: Icon(
            icon,
            size: 15,
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
      width: isWide ? 204 : 72,
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppVisualTheme>()!.sidebar,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).extension<AppVisualTheme>()!.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (isWide)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '音乐库',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          // 导航项
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  for (int i = 0; i < _navItems.length; i++) ...[
                    _buildNavItem(context, i, scheme, isDark, isWide),
                    if (i < _navItems.length - 1) const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ),
          // 底部操作区域
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 主题切换按钮
                _buildThemeToggle(context, theme, isDark, scheme),
                const SizedBox(height: 8),
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
    bool isWide,
  ) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final visual = Theme.of(context).extension<AppVisualTheme>()!;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onDestinationSelected(index),
            borderRadius: BorderRadius.circular(8),
            hoverColor: visual.hover,
            splashColor: scheme.primary.withValues(alpha: 0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? visual.selected : Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: isWide
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        scheme.primary,
                        value,
                      ),
                      size: 20,
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: Color.lerp(
                            scheme.onSurfaceVariant,
                            scheme.onSurface,
                            value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation(BuildContext context, ColorScheme scheme) {
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: visual.elevatedPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: visual.border),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _navItems.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: _selectedIndex == i,
                  label: _navItems[i].label,
                  child: InkWell(
                    onTap: () => _onDestinationSelected(i),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedIndex == i
                            ? visual.selected
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedIndex == i
                                ? _navItems[i].selectedIcon
                                : _navItems[i].icon,
                            size: 20,
                            color: _selectedIndex == i
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _navItems[i].label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: _selectedIndex == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
          borderRadius: BorderRadius.circular(8),
          hoverColor: scheme.primary.withValues(alpha: 0.08),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).extension<AppVisualTheme>()!.elevatedPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).extension<AppVisualTheme>()!.border,
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
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
