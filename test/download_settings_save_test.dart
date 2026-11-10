import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/providers/download_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('关闭保存等待早先的设置写入，并将最后的修改依次写入', () async {
    final blocked = Completer<bool>();
    final started = Completer<void>();
    final latestStarted = Completer<void>();
    final latestBlocked = Completer<bool>();
    final writes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            if (call.method == 'setString') {
              final value = call.arguments['value'] as String;
              writes.add(value);
              if (value == '/first') {
                started.complete();
                return blocked.future;
              }
              if (value == '/latest') {
                latestStarted.complete();
                return latestBlocked.future;
              }
            }
            return true;
          },
        );
    final provider = DownloadProvider();
    await provider.ready;
    await provider.setDefaultDownloadPath('/first');
    final first = provider.flushSettings();
    await started.future;
    await provider.setDefaultDownloadPath('/latest');
    var closingFinished = false;
    final closing = provider.flushSettings().whenComplete(() {
      closingFinished = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(writes, ['/first']);
    blocked.complete(true);
    await latestStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(closingFinished, isFalse);
    latestBlocked.complete(true);
    await Future.wait([first, closing]);
    expect(writes, ['/first', '/latest']);
    provider.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
  });
}
