import 'package:flutter/material.dart';

/// 全局设计令牌：所有界面共用同一套间距、圆角、字号、动效与断点，
/// 避免每个页面各自硬编码视觉数值。
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// 页面左右安全留白。
  static const double page = 18;

  /// 相邻模块之间的标准间距。
  static const double gutter = 12;

  static const double titleBarHeight = 48;
  static const double controlHeight = 40;
  static const double mediaRowHeight = 60;

  static const EdgeInsets pageInsets = EdgeInsets.symmetric(horizontal: page);
  static const EdgeInsets panelInsets = EdgeInsets.all(lg);
  static const EdgeInsets cardInsets = EdgeInsets.all(md);
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static BorderRadius circular(double radius) => BorderRadius.circular(radius);
}

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 350);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

abstract final class AppBreakpoints {
  /// 小于该宽度时切换到底部导航。
  static const double bottomNav = 720;

  /// 大于等于该宽度时侧栏展开显示文字。
  static const double wideRail = 1080;

  /// 播放工作区使用左右分栏的最小宽度。
  static const double workspaceWide = 820;

  /// 页面头部操作区折行的阈值。
  static const double compactHeader = 820;

  static const double settingsMaxWidth = 1040;

  /// 迷你播放器响应式断点。
  static const double playerStacked = 860;
  static const double playerShowArtist = 900;
  static const double playerShowMode = 980;
  static const double playerShowTime = 1040;
  static const double playerShowVolume = 1180;
  static const double playerCompactPadding = 620;
  static const double playerCompactTime = 720;

  /// 面板头部控件压缩阈值。
  static const double panelHeaderCompact = 440;
}

abstract final class AppTypeScale {
  static const double display = 32;
  static const double headline = 24;
  static const double title = 20;
  static const double subtitle = 16;
  static const double body = 14;
  static const double caption = 12;
  static const double overline = 11;
  static const double micro = 10;
}

abstract final class AppShadows {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: color,
      blurRadius: 14,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> elevated(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.65),
      blurRadius: 24,
      spreadRadius: -6,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 8,
      spreadRadius: -2,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double alpha = 0.24}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 18,
      spreadRadius: 1,
      offset: const Offset(0, 5),
    ),
  ];
}

/// 主题语义色扩展：在 [ColorScheme] 之外补充播放器专用的表面与状态色。
///
/// 所有字段都有安全默认值，未注册扩展的上下文也能正常渲染。
@immutable
class AppVisualTheme extends ThemeExtension<AppVisualTheme> {
  const AppVisualTheme({
    this.panel = const Color(0xFF17202B),
    this.elevatedPanel = const Color(0xFF1D2936),
    this.sidebar = const Color(0xFF090C11),
    this.border = const Color(0x22FFFFFF),
    this.panelMuted = const Color(0xFF273443),
    this.hover = const Color(0x142F7D73),
    this.selected = const Color(0x2B2F7D73),
    this.glow = const Color(0x1F2F7D73),
    this.shadow = const Color(0x38000000),
    this.accentSurface = const Color(0x1A2F7D73),
    this.success = const Color(0xFF34D399),
    this.warning = const Color(0xFFFBBF24),
    this.overlay = const Color(0x6617202B),
    this.scrim = const Color(0x99090C11),
  });

  final Color panel;
  final Color elevatedPanel;
  final Color sidebar;
  final Color border;
  final Color panelMuted;
  final Color hover;
  final Color selected;
  final Color glow;
  final Color shadow;
  final Color accentSurface;
  final Color success;
  final Color warning;

  /// 全屏页浮层的半透明底色。
  final Color overlay;

  /// 覆盖在动态背景上的遮罩色。
  final Color scrim;

  @override
  AppVisualTheme copyWith({
    Color? panel,
    Color? elevatedPanel,
    Color? sidebar,
    Color? border,
    Color? panelMuted,
    Color? hover,
    Color? selected,
    Color? glow,
    Color? shadow,
    Color? accentSurface,
    Color? success,
    Color? warning,
    Color? overlay,
    Color? scrim,
  }) => AppVisualTheme(
    panel: panel ?? this.panel,
    elevatedPanel: elevatedPanel ?? this.elevatedPanel,
    sidebar: sidebar ?? this.sidebar,
    border: border ?? this.border,
    panelMuted: panelMuted ?? this.panelMuted,
    hover: hover ?? this.hover,
    selected: selected ?? this.selected,
    glow: glow ?? this.glow,
    shadow: shadow ?? this.shadow,
    accentSurface: accentSurface ?? this.accentSurface,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    overlay: overlay ?? this.overlay,
    scrim: scrim ?? this.scrim,
  );

  @override
  AppVisualTheme lerp(covariant AppVisualTheme? other, double t) {
    if (other == null) return this;
    return AppVisualTheme(
      panel: Color.lerp(panel, other.panel, t)!,
      elevatedPanel: Color.lerp(elevatedPanel, other.elevatedPanel, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      border: Color.lerp(border, other.border, t)!,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      accentSurface: Color.lerp(accentSurface, other.accentSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// 让页面与组件用更短、更统一的写法读取主题信息。
extension AppDesignContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  AppVisualTheme get visual =>
      Theme.of(this).extension<AppVisualTheme>() ?? const AppVisualTheme();
}
