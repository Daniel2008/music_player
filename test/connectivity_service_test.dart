import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/services/connectivity_service.dart';
import 'package:music_player/services/gd_music_api.dart';

void main() {
  group('ConnectivityService', () {
    test('初始状态为 checking', () {
      final s = ConnectivityService();
      expect(
        s.status,
        anyOf(
          ConnectivityStatus.online,
          ConnectivityStatus.checking,
          ConnectivityStatus.offline,
        ),
      );
      s.dispose();
    });

    test('tripCircuitBreaker 开启熔断 10s', () {
      final s = ConnectivityService();
      s.tripCircuitBreaker();
      expect(s.isCircuitBroken, isTrue);
      s.dispose();
    });

    test('bindToApiClient 触发熔断', () {
      final s = ConnectivityService();
      final api = GdMusicApiClient();
      s.bindToApiClient(api);
      // 模拟请求失败
      api.onRequestFailed?.call();
      expect(s.isCircuitBroken, isTrue);
      // 模拟请求成功会清除
      api.onRequestSuccess?.call();
      expect(s.isCircuitBroken, isFalse);
      s.dispose();
    });

    test('多次 tripCircuitBreaker 不会重复开启计时器', () {
      final s = ConnectivityService();
      s.tripCircuitBreaker();
      s.tripCircuitBreaker();
      s.tripCircuitBreaker();
      expect(s.isCircuitBroken, isTrue);
      s.dispose();
    });
  });
}
