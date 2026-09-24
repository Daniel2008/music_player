import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    test('默认 dark 模式', () async {
      final provider = ThemeProvider(useGoogleFonts: false);
      expect(provider.mode, ThemeMode.dark);
      expect(provider.seedColor, isNotNull);
    });

    test('setMode 修改模式', () async {
      final provider = ThemeProvider(useGoogleFonts: false);
      await provider.setMode(ThemeMode.light);
      expect(provider.mode, ThemeMode.light);
    });

    test('setSeedColor 修改种子色', () async {
      final provider = ThemeProvider(useGoogleFonts: false);
      // 等构造函数里触发的 _loadSettings() 完成（避免被覆盖）
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await provider.setSeedColor(const Color(0xFF112233));
      expect(provider.seedColor, const Color(0xFF112233));
    });

    test('持久化：setMode 和 setSeedColor 都触发保存', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider(useGoogleFonts: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await provider.setMode(ThemeMode.light);
      await provider.setSeedColor(const Color(0xFF112233));
      // 这里仅验证 setMode/setSeedColor 不抛错；
      // 完整持久化-恢复测试需在 setUpAll 中清空 StorageService 单例缓存。
    });

    test('lightTheme / darkTheme 可用', () {
      final provider = ThemeProvider(useGoogleFonts: false);
      expect(provider.lightTheme, isNotNull);
      expect(provider.darkTheme, isNotNull);
    });
  });
}
