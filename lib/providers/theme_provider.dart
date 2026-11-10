import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import '../ui/theme/app_design.dart';

// 兼容历史 import：AppVisualTheme 现已归入统一设计令牌文件。
export '../ui/theme/app_design.dart' show AppVisualTheme;

/// 预设主题色
class PresetThemeColor {
  const PresetThemeColor(this.name, this.color);
  final String name;
  final Color color;
}

class ThemeProvider extends ChangeNotifier {
  /// [useGoogleFonts] 仅用于选择首选系统字体族，不会在运行时下载字体。
  ThemeProvider({bool useGoogleFonts = true})
    : _fontFamily = useGoogleFonts ? 'Noto Sans SC' : 'Microsoft YaHei UI' {
    _rebuildThemes();
    _loadSettings();
  }

  final String _fontFamily;

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

  static const List<String> _fontFallback = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Segoe UI',
    'PingFang SC',
    'Noto Sans CJK SC',
  ];

  TextTheme _buildTextTheme(Brightness brightness, Color onSurface) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    TextStyle ts({
      required double fontSize,
      required FontWeight fontWeight,
      double height = 1.4,
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: onSurface,
    );

    return base
        .apply(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          bodyColor: onSurface,
          displayColor: onSurface,
        )
        .copyWith(
          displayLarge: ts(
            fontSize: AppTypeScale.display,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          headlineLarge: ts(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          headlineMedium: ts(
            fontSize: AppTypeScale.headline,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleLarge: ts(
            fontSize: AppTypeScale.title,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleMedium: ts(
            fontSize: AppTypeScale.subtitle,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: ts(
            fontSize: AppTypeScale.body,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: ts(
            fontSize: AppTypeScale.subtitle,
            fontWeight: FontWeight.w400,
            height: 1.55,
          ),
          bodyMedium: ts(
            fontSize: AppTypeScale.body,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodySmall: ts(
            fontSize: AppTypeScale.caption,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          labelLarge: ts(
            fontSize: AppTypeScale.body,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: ts(
            fontSize: AppTypeScale.caption,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: ts(
            fontSize: AppTypeScale.overline,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        );
  }

  /// 把种子色轻微混入中性表面，让切换主题色时整体氛围也跟着变化。
  Color _tinted(Color base, {required double alpha}) =>
      Color.alphaBlend(_seedColor.withValues(alpha: alpha), base);

  ColorScheme _buildScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    if (isDark) {
      return scheme.copyWith(
        surface: _tinted(const Color(0xFF0B1017), alpha: 0.045),
        surfaceContainerLowest: _tinted(const Color(0xFF080C12), alpha: 0.035),
        surfaceContainerLow: _tinted(const Color(0xFF111923), alpha: 0.05),
        surfaceContainer: _tinted(const Color(0xFF17212C), alpha: 0.055),
        surfaceContainerHigh: _tinted(const Color(0xFF1E2A37), alpha: 0.06),
        surfaceContainerHighest: _tinted(const Color(0xFF283645), alpha: 0.065),
        onSurface: const Color(0xFFEFF3F8),
        onSurfaceVariant: const Color(0xFFA7B4C4),
        outline: const Color(0xFF7A8A9E),
        outlineVariant: const Color(0xFF2C3948),
      );
    }

    return scheme.copyWith(
      surface: _tinted(const Color(0xFFF6F8FC), alpha: 0.02),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: _tinted(const Color(0xFFFBFCFE), alpha: 0.015),
      surfaceContainer: _tinted(const Color(0xFFF1F5FA), alpha: 0.025),
      surfaceContainerHigh: _tinted(const Color(0xFFE9EFF6), alpha: 0.03),
      surfaceContainerHighest: _tinted(const Color(0xFFDDE6F0), alpha: 0.035),
      onSurface: const Color(0xFF16202C),
      onSurfaceVariant: const Color(0xFF5D6B7D),
      outline: const Color(0xFF8A97A8),
      outlineVariant: const Color(0xFFD9E1EB),
    );
  }

  void _rebuildThemes() {
    final lightScheme = _buildScheme(Brightness.light);
    final darkScheme = _buildScheme(Brightness.dark);
    lightTheme = _buildThemeData(
      lightScheme,
      _buildTextTheme(Brightness.light, lightScheme.onSurface),
    );
    darkTheme = _buildThemeData(
      darkScheme,
      _buildTextTheme(Brightness.dark, darkScheme.onSurface),
    );
  }

  ThemeData _buildThemeData(ColorScheme scheme, TextTheme textTheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final panel = scheme.surfaceContainerLow;
    final border = scheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.11);
    final strongBorder = scheme.onSurface.withValues(alpha: 0.16);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: panel,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.45)
            : scheme.surfaceContainerLowest,
        isDense: true,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
          fontSize: AppTypeScale.body,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.controlHeight, 40),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.controlHeight, 40),
          side: BorderSide(color: strongBorder),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AppSpacing.controlHeight, 40),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          foregroundColor: scheme.onSurfaceVariant,
          hoverColor: scheme.primary.withValues(alpha: 0.1),
          highlightColor: scheme.primary.withValues(alpha: 0.16),
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.4,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        iconColor: scheme.onSurfaceVariant,
        minLeadingWidth: 32,
        minVerticalPadding: AppSpacing.sm,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smAll),
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
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        textStyle: textTheme.bodyMedium,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.smAll,
        ),
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.inverseSurface,
        valueIndicatorTextStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        minThumbSeparation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
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
        linearMinHeight: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        elevation: 6,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        elevation: 20,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        elevation: 12,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline.withValues(alpha: 0.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppRadius.xs),
        thickness: WidgetStateProperty.all(5),
        interactive: true,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => scheme.onSurfaceVariant.withValues(
            alpha: states.contains(WidgetState.hovered) ? 0.5 : 0.28,
          ),
        ),
      ),
      extensions: [
        AppVisualTheme(
          panel: panel,
          elevatedPanel: isDark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest,
          sidebar: scheme.surfaceContainerLowest,
          border: border,
          panelMuted: scheme.surfaceContainerHigh,
          hover: scheme.primary.withValues(alpha: isDark ? 0.09 : 0.06),
          selected: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.11),
          glow: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
          shadow: Colors.black.withValues(alpha: isDark ? 0.34 : 0.1),
          accentSurface: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.1),
          success: isDark ? const Color(0xFF4ADE80) : const Color(0xFF12805C),
          warning: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
          overlay: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.04),
            scheme.surfaceContainerHigh,
          ).withValues(alpha: isDark ? 0.68 : 0.9),
          scrim: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.86),
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
    await _saveSettings();
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
      await _saveSettings();
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
