import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;

  ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  );
  ThemeData darkTheme = ThemeData.dark(useMaterial3: true);

  Future<void> setMode(ThemeMode newMode) async {
    mode = newMode;
    notifyListeners();
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
    notifyListeners();
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
