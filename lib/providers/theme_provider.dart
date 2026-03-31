import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// 预设主题色列表
  static const List<PresetThemeColor> presetColors = [
    PresetThemeColor('蓝色', Color(0xFF2196F3)),
    PresetThemeColor('紫色', Color(0xFF9C27B0)),
    PresetThemeColor('绿色', Color(0xFF4CAF50)),
    PresetThemeColor('橙色', Color(0xFFFF9800)),
    PresetThemeColor('粉色', Color(0xFFE91E63)),
    PresetThemeColor('青色', Color(0xFF00BCD4)),
    PresetThemeColor('红色', Color(0xFFF44336)),
    PresetThemeColor('靛蓝', Color(0xFF3F51B5)),
  ];

  ThemeMode mode = ThemeMode.dark;
  Color _seedColor = const Color(0xFF2196F3);
  Color get seedColor => _seedColor;

  late ThemeData lightTheme;
  late ThemeData darkTheme;

  ThemeProvider() {
    _rebuildThemes();
    _loadSettings();
  }

  void _rebuildThemes() {
    lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      useMaterial3: true,
    );
    darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
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
    final primary = _hexToColor(data['primary'] as String? ?? '#2196F3');
    final background = _hexToColor(data['background'] as String? ?? '#121212');
    final brightness = (data['brightness'] as String? ?? 'dark').toLowerCase();
    final isDark = brightness == 'dark';
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: background,
    );
    if (isDark) {
      darkTheme = ThemeData(colorScheme: scheme, useMaterial3: true);
      mode = ThemeMode.dark;
    } else {
      lightTheme = ThemeData(colorScheme: scheme, useMaterial3: true);
      mode = ThemeMode.light;
    }
    _seedColor = primary;
    notifyListeners();
    _saveSettings();
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
