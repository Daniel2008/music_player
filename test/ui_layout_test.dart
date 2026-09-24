import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_player/providers/api_settings_provider.dart';
import 'package:music_player/providers/search_provider.dart';
import 'package:music_player/providers/theme_provider.dart';
import 'package:music_player/ui/pages/search_page.dart';
import 'package:music_player/ui/widgets/app_surfaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final font = File(r'C:\Windows\Fonts\msyh.ttc');
    if (await font.exists()) {
      final loader = FontLoader('Microsoft YaHei UI')
        ..addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });

  for (final dark in [false, true]) {
    for (final width in [420.0, 900.0, 1280.0]) {
      testWidgets('search layout $width dark=$dark', (tester) async {
        tester.view.reset();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        final theme = ThemeProvider(useGoogleFonts: false);
        final search = SearchProvider();
        final settings = ApiSettingsProvider();
        final key = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: search),
              ChangeNotifierProvider.value(value: settings),
            ],
            child: MaterialApp(
              theme: dark ? theme.darkTheme : theme.lightTheme,
              home: RepaintBoundary(
                key: key,
                child: const Scaffold(body: SearchPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();
        expect(find.byTooltip('清空搜索'), findsOneWidget);
        await tester.tap(find.byTooltip('清空搜索'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('清空搜索'), findsNothing);

        final captureDir = Platform.environment['UI_CAPTURE_DIR'];
        if (captureDir != null) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await tester.runAsync(() async {
            await Directory(captureDir).create(recursive: true);
            await File(
              '$captureDir/search-${width.toInt()}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
          image.dispose();
        }
        await tester.pumpWidget(const SizedBox());
        search.dispose();
        settings.dispose();
        theme.dispose();
      });
    }
  }

  testWidgets('page actions wrap in narrow space', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final theme = ThemeProvider(useGoogleFonts: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.darkTheme,
        home: Scaffold(
          body: AppPageHeader(
            title: '收藏',
            icon: Icons.library_music_outlined,
            actions: [
              FilledButton(onPressed: () {}, child: const Text('播放全部')),
              OutlinedButton(onPressed: () {}, child: const Text('音质')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    theme.dispose();
  });
}
