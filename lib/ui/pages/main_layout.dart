import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/theme_provider.dart';
import '../theme/app_design.dart';
import '../widgets/hotkey_binder.dart';
import '../widgets/mini_player_v2.dart';
import '../widgets/surface_texture.dart';
import 'favorites_workspace_page.dart';
import 'history_workspace_page.dart';
import 'player_workspace_page_v3.dart';
import 'search_page.dart';
import 'settings_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final bool _isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

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
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.wideRail;
    final useBottomNavigation = width < AppBreakpoints.bottomNav;

    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: Stack(
        children: [
          const HotkeyBinder(),
          Column(
            children: [
              if (_isDesktop) _buildTitleBar(context),
              Expanded(
                child: Row(
                  children: [
                    if (!useBottomNavigation)
                      _buildNavigationRail(context, isWide),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            // 使用 Offstage+TickerMode 代替 IndexedStack：
                            // 不可见页面的 Ticker 被禁用，动画自动暂停。
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
                            _buildBottomNavigation(context),
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

  Widget _buildTitleBar(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: AppSpacing.titleBarHeight,
        decoration: BoxDecoration(
          color: visual.sidebar,
          border: Border(bottom: BorderSide(color: visual.border)),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.28),
                    scheme.primaryContainer.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.24),
                ),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 16,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 1),
            Text(
              'Music Player',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const Expanded(child: SizedBox()),
            _buildWindowButton(
              icon: Icons.remove_rounded,
              onPressed: () => windowManager.minimize(),
            ),
            _buildWindowButton(
              icon: Icons.crop_square_rounded,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _buildWindowButton(
              icon: Icons.close_rounded,
              onPressed: () => windowManager.close(),
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
    bool isClose = false,
  }) {
    final scheme = context.scheme;
    final hoverColor = isClose ? scheme.error : scheme.primary;
    return SizedBox(
      width: 44,
      height: AppSpacing.titleBarHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: hoverColor.withValues(alpha: isClose ? 0.85 : 0.12),
          child: Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool isWide) {
    final scheme = context.scheme;
    final visual = context.visual;
    final theme = context.read<ThemeProvider>();
    final isDark = context.isDark;

    return Container(
      width: isWide ? 204 : 72,
      decoration: BoxDecoration(
        color: visual.sidebar,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.075 : 0.045),
              visual.sidebar,
            ),
            visual.sidebar,
          ],
        ),
        border: Border(right: BorderSide(color: visual.border)),
      ),
      child: TexturedSurface(
        kind: SurfaceTextureKind.woven,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            if (isWide)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '音乐库',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  children: [
                    for (int i = 0; i < _navItems.length; i++) ...[
                      _buildNavItem(context, i, isWide),
                      if (i < _navItems.length - 1)
                        const SizedBox(height: AppSpacing.xxs),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _buildThemeToggle(context, theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, bool isWide) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final scheme = context.scheme;
    final visual = context.visual;
    final isDark = context.isDark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      builder: (context, value, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onDestinationSelected(index),
            borderRadius: AppRadius.mdAll,
            hoverColor: visual.hover,
            splashColor: scheme.primary.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                color: isSelected ? visual.selected : Colors.transparent,
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          scheme.primary.withValues(
                            alpha: isDark ? 0.24 : 0.14,
                          ),
                          scheme.primary.withValues(alpha: 0.03),
                        ],
                      )
                    : null,
                border: Border.all(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: isWide
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (isWide && isSelected)
                    Container(
                      width: 3,
                      height: 22,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        borderRadius: AppRadius.xsAll,
                      ),
                    ),
                  AnimatedContainer(
                    duration: AppMotion.normal,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isSelected ? scheme.primary : Colors.transparent,
                      borderRadius: AppRadius.smAll,
                      boxShadow: isSelected
                          ? AppShadows.glow(scheme.primary, alpha: 0.22)
                          : null,
                    ),
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        scheme.onPrimary,
                        value,
                      ),
                      size: 20,
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        item.label,
                        style: context.textStyles.titleSmall?.copyWith(
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

  Widget _buildBottomNavigation(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: visual.elevatedPanel,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: visual.border),
          boxShadow: AppShadows.soft(
            visual.shadow.withValues(alpha: context.isDark ? 0.2 : 0.08),
          ),
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
                    borderRadius: AppRadius.mdAll,
                    child: AnimatedContainer(
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedIndex == i
                            ? visual.selected
                            : Colors.transparent,
                        borderRadius: AppRadius.mdAll,
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
                          const SizedBox(height: AppSpacing.xxs + 1),
                          Text(
                            _navItems[i].label,
                            style: context.textStyles.labelSmall?.copyWith(
                              color: _selectedIndex == i
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
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
  ) {
    final scheme = context.scheme;
    final visual = context.visual;
    return Tooltip(
      message: isDark ? '切换到浅色模式' : '切换到深色模式',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => theme.setMode(isDark ? ThemeMode.light : ThemeMode.dark),
          borderRadius: AppRadius.mdAll,
          hoverColor: scheme.primary.withValues(alpha: 0.1),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: visual.elevatedPanel,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: visual.border),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
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
