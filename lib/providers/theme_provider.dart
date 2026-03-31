import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

/// 预设主题色
class PresetThemeColor {
  final String name;
  final Color color;
  const PresetThemeColor(this.name, this.color);
}

class ThemeProvider extends ChangeNotifier {
  static const String _modeKey = 'theme_mode';
  static const String _colorKey = 'theme_seed_color';

  /// 预设主题色列表 — 使用经过精心调配的 HSL 色彩
  static const List<PresetThemeColor> presetColors = [
    PresetThemeColor('靛蓝', Color(0xFF5B6ABF)),
    PresetThemeColor('薰衣草', Color(0xFF8B5CF6)),
    PresetThemeColor('翡翠', Color(0xFF10B981)),
    PresetThemeColor('琥珀', Color(0xFFF59E0B)),
    PresetThemeColor('玫红', Color(0xFFEC4899)),
    PresetThemeColor('青碧', Color(0xFF06B6D4)),
    PresetThemeColor('珊瑚', Color(0xFFF43F5E)),
    PresetThemeColor('钴蓝', Color(0xFF3B82F6)),
  ];

  ThemeMode mode = ThemeMode.dark;
  Color _seedColor = const Color(0xFF5B6ABF);
  Color get seedColor => _seedColor;

  late ThemeData lightTheme;
  late ThemeData darkTheme;

  ThemeProvider() {
    _rebuildThemes();
    _loadSettings();
  }

  /// 构建精致的 TextTheme
  TextTheme _buildTextTheme(Brightness brightness) {
    final baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    // 使用 Google Fonts 的 Noto Sans SC 作为中文字体
    return GoogleFonts.notoSansScTextTheme(baseTextTheme).copyWith(
      // 大标题：加粗、微加字距
      displayLarge: GoogleFonts.notoSansSc(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      // 页面标题
      headlineMedium: GoogleFonts.notoSansSc(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      // 卡片标题
      titleLarge: GoogleFonts.notoSansSc(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      // 正文
      bodyLarge: GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      // 标签文本
      labelLarge: GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.notoSansSc(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.notoSansSc(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  void _rebuildThemes() {
    final lightTextTheme = _buildTextTheme(Brightness.light);
    final darkTextTheme = _buildTextTheme(Brightness.dark);

    final lightScheme = ColorScheme.fromSeed(seedColor: _seedColor);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    lightTheme = ThemeData(
      colorScheme: lightScheme,
      useMaterial3: true,
      textTheme: lightTextTheme,
      // 统一卡片样式
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      // 统一输入框样式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      // 统一 FilledButton 样式
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      // 统一 Tooltip 样式
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: lightScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: lightScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),
    );

    darkTheme = ThemeData(
      colorScheme: darkScheme,
      useMaterial3: true,
      textTheme: darkTextTheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F14),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF1A1A24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: darkScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: darkScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_modeKey);
      final colorValue = prefs.getInt(_colorKey);

      if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
        mode = ThemeMode.values[modeIndex];
      }
      if (colorValue != null) {
        _seedColor = Color(colorValue);
      }
      _rebuildThemes();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_modeKey, mode.index);
      await prefs.setInt(_colorKey, _seedColor.toARGB32());
    } catch (_) {}
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
    _saveSettings();
  }

  Future<void> loadSkin(String assetPath) async {
    final jsonStr = await rootBundle.loadString(assetPath);
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final primary = _hexToColor(data['primary'] as String? ?? '#5B6ABF');
    final brightness = (data['brightness'] as String? ?? 'dark').toLowerCase();
    final isDark = brightness == 'dark';

    _seedColor = primary;
    mode = isDark ? ThemeMode.dark : ThemeMode.light;
    _rebuildThemes(); // 复用完整主题构建逻辑，保留 textTheme、cardTheme 等配置
    notifyListeners();
    _saveSettings();
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
