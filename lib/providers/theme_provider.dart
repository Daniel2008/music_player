import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';

/// 预设主题色
class PresetThemeColor {
  const PresetThemeColor(this.name, this.color);
  final String name;
  final Color color;
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({bool useGoogleFonts = true})
    : _useGoogleFonts = useGoogleFonts {
    _rebuildThemes();
    _loadSettings();
  }
  final bool _useGoogleFonts;
  static const String _modeKey = 'theme_mode';
  static const String _colorKey = 'theme_seed_color';

  /// 预设主题色列表 — 使用经过精心调配的 HSL 色彩
  static const List<PresetThemeColor> presetColors = [
    PresetThemeColor('松石', Color(0xFF2F7D73)),
    PresetThemeColor('靛蓝', Color(0xFF5B6ABF)),
    PresetThemeColor('翡翠', Color(0xFF10B981)),
    PresetThemeColor('琥珀', Color(0xFFF59E0B)),
    PresetThemeColor('玫红', Color(0xFFEC4899)),
    PresetThemeColor('青碧', Color(0xFF06B6D4)),
    PresetThemeColor('珊瑚', Color(0xFFF43F5E)),
    PresetThemeColor('钴蓝', Color(0xFF3B82F6)),
  ];

  ThemeMode mode = ThemeMode.dark;
  Color _seedColor = const Color(0xFF2F7D73);
  Color get seedColor => _seedColor;

  late ThemeData lightTheme;
  late ThemeData darkTheme;

  TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    // 不再在运行时下载 Google Fonts。中文字体直接使用系统已安装字体，
    // 避免字体文件、下载状态和 glyph cache 形成额外常驻内存。
    final fontFamily = _useGoogleFonts ? 'Noto Sans SC' : 'Microsoft YaHei UI';
    const fontFamilyFallback = [
      'Microsoft YaHei UI',
      'Microsoft YaHei',
      'Segoe UI',
      'PingFang SC',
      'Noto Sans CJK SC',
    ];
    final baseTheme = base.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    TextStyle ts({
      required double fontSize,
      required FontWeight fontWeight,
      double? letterSpacing,
      double? height,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );

    return baseTheme.copyWith(
      displayLarge: ts(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: ts(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: ts(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: ts(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      bodyLarge: ts(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      bodyMedium: ts(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      labelLarge: ts(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelMedium: ts(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: ts(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }

  void _rebuildThemes() {
    final lightScheme = ColorScheme.fromSeed(seedColor: _seedColor).copyWith(
      surface: const Color(0xFFF7F9FC),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF3F6FA),
      surfaceContainerHigh: const Color(0xFFEEF2F7),
      surfaceContainerHighest: const Color(0xFFE3E9F1),
      onSurface: const Color(0xFF18212F),
      onSurfaceVariant: const Color(0xFF667085),
      outline: const Color(0xFF8792A3),
      outlineVariant: const Color(0xFFD6DDE7),
    );
    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF0D1117),
          surfaceContainerLowest: const Color(0xFF090C11),
          surfaceContainerLow: const Color(0xFF121821),
          surfaceContainer: const Color(0xFF17202B),
          surfaceContainerHigh: const Color(0xFF1D2936),
          surfaceContainerHighest: const Color(0xFF273443),
          onSurface: const Color(0xFFF2F4F7),
          onSurfaceVariant: const Color(0xFFAAB5C4),
          outline: const Color(0xFF7D8B9C),
          outlineVariant: const Color(0xFF2B3949),
        );

    lightTheme = _buildThemeData(
      lightScheme,
      _buildTextTheme(Brightness.light),
    );
    darkTheme = _buildThemeData(darkScheme, _buildTextTheme(Brightness.dark));
  }

  ThemeData _buildThemeData(ColorScheme scheme, TextTheme textTheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final surface = scheme.surface;
    final panel = scheme.surfaceContainerLow;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.085)
        : const Color(0xFF344054).withValues(alpha: 0.12);

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      textTheme: textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        color: panel,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.white.withValues(alpha: 0.82),
        isDense: true,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          foregroundColor: scheme.onSurfaceVariant,
          hoverColor: scheme.primary.withValues(alpha: 0.09),
          highlightColor: scheme.primary.withValues(alpha: 0.14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        iconColor: scheme.onSurfaceVariant,
        minLeadingWidth: 32,
        minVerticalPadding: 8,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        elevation: 12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        childrenPadding: const EdgeInsets.only(bottom: 6),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        minThumbSeparation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.primary : border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        elevation: 20,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(5),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => scheme.onSurfaceVariant.withValues(
            alpha: states.contains(WidgetState.hovered) ? 0.48 : 0.28,
          ),
        ),
      ),
    );

    return base.copyWith(
      extensions: [
        AppVisualTheme(
          panel: panel,
          elevatedPanel: isDark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest,
          sidebar: scheme.surfaceContainerLowest,
          border: border,
          panelMuted: scheme.surfaceContainerHigh,
          hover: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.055),
          selected: scheme.primary.withValues(alpha: isDark ? 0.17 : 0.1),
          glow: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.07),
          shadow: scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.08),
        ),
      ],
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await StorageService.instance.prefs;
    final modeIndex = prefs.getInt(_modeKey);
    final colorValue = prefs.getInt(_colorKey);

    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < ThemeMode.values.length) {
      mode = ThemeMode.values[modeIndex];
    }
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    _rebuildThemes();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await StorageService.instance.prefs;
    await prefs.setInt(_modeKey, mode.index);
    await prefs.setInt(_colorKey, _seedColor.toARGB32());
  }

  Future<void> setMode(ThemeMode newMode) async {
    mode = newMode;
    notifyListeners();
    _saveSettings();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    _rebuildThemes();
    notifyListeners();
    await _saveSettings();
  }

  Future<void> loadSkin(String assetPath) async {
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final primary = _hexToColor(data['primary'] as String? ?? '#5B6ABF');
      final brightness = (data['brightness'] as String? ?? 'dark')
          .toLowerCase();
      final isDark = brightness == 'dark';

      _seedColor = primary;
      mode = isDark ? ThemeMode.dark : ThemeMode.light;
      _rebuildThemes();
      notifyListeners();
      _saveSettings();
    } catch (e) {
      debugPrint('加载皮肤失败: $e');
    }
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) {
        return Color(int.parse('FF$h', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF2F7D73);
  }
}

@immutable
class AppVisualTheme extends ThemeExtension<AppVisualTheme> {
  const AppVisualTheme({
    required this.panel,
    required this.elevatedPanel,
    required this.sidebar,
    required this.border,
    required this.panelMuted,
    required this.hover,
    required this.selected,
    required this.glow,
    required this.shadow,
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
    );
  }
}
