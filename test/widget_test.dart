// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/app.dart';

void main() {
  testWidgets('App renders main layout', (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());
    // 新布局使用 NavigationRail，检查导航标签
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
