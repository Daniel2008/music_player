import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/ui/widgets/window_close_guard.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          calls.add(call.method);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null),
  );

  testWidgets('保存完成前不能销毁窗口，重复关闭不启动第二次保存', (tester) async {
    final saving = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WindowCloseGuard(
            onSave: () {
              attempts++;
              return saving.future;
            },
            child: const Text('player'),
          ),
        ),
      ),
    );
    for (final listener in List<WindowListener>.of(windowManager.listeners)) {
      listener.onWindowClose();
      listener.onWindowClose();
    }
    await tester.pump();
    expect(attempts, 1);
    expect(calls, isNot(contains('destroy')));
    saving.complete();
    await tester.pump();
    expect(calls, contains('destroy'));
  });

  testWidgets('保存失败保留窗口并允许重试关闭', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WindowCloseGuard(
            onSave: () async {
              if (++attempts == 1) throw StateError('disk full');
            },
            child: const Text('player'),
          ),
        ),
      ),
    );
    for (final listener in List<WindowListener>.of(windowManager.listeners)) {
      listener.onWindowClose();
    }
    await tester.pump();
    expect(calls, isNot(contains('destroy')));
    expect(find.textContaining('保存失败'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(calls, contains('destroy'));
  });
}
