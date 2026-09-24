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
      surface: const Color(0xFFFAFAFA),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F5F5),
      surfaceContainer: const Color(0xFFF0F0F0),
      surfaceContainerHigh: const Color(0xFFEAEAEA),
      surfaceContainerHighest: const Color(0xFFE3E3E3),
      onSurface: const Color(0xFF202124),
      onSurfaceVariant: const Color(0xFF616368),
      outlineVariant: const Color(0xFFDEDFE1),
    );
    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF171719),
          surfaceContainerLowest: const Color(0xFF111113),
          surfaceContainerLow: const Color(0xFF1C1C1F),
          surfaceContainer: const Color(0xFF222225),
          surfaceContainerHigh: const Color(0xFF29292D),
          surfaceContainerHighest: const Color(0xFF333338),
          onSurface: const Color(0xFFECECEE),
          onSurfaceVariant: const Color(0xFFABABB2),
          outlineVariant: const Color(0xFF343439),
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
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFF111827).withValues(alpha: 0.1);

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
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white,
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
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        iconColor: scheme.onSurfaceVariant,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
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
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
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
          elevatedPanel: scheme.surfaceContainerHigh,
          sidebar: scheme.surfaceContainerLowest,
          border: border,
          glow: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.06),
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
    required this.glow,
  });

  final Color panel;
  final Color elevatedPanel;
  final Color sidebar;
  final Color border;
  final Color glow;

  @override
  AppVisualTheme copyWith({
    Color? panel,
    Color? elevatedPanel,
    Color? sidebar,
    Color? border,
    Color? glow,
  }) => AppVisualTheme(
    panel: panel ?? this.panel,
    elevatedPanel: elevatedPanel ?? this.elevatedPanel,
    sidebar: sidebar ?? this.sidebar,
    border: border ?? this.border,
    glow: glow ?? this.glow,
  );

  @override
  AppVisualTheme lerp(covariant AppVisualTheme? other, double t) {
    if (other == null) return this;
    return AppVisualTheme(
      panel: Color.lerp(panel, other.panel, t)!,
      elevatedPanel: Color.lerp(elevatedPanel, other.elevatedPanel, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      border: Color.lerp(border, other.border, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}
