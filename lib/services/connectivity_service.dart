import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'gd_music_api.dart';

/// 网络连接状态
enum ConnectivityStatus { online, offline, checking }

/// 轻量级网络连接监控服务
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    checkNow();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkNow(),
    );
  }
  ConnectivityStatus _status = ConnectivityStatus.checking;
  bool _circuitBroken = false;
  Timer? _checkTimer;
  bool _disposed = false;
  String _host = Uri.parse(GdMusicApiClient.defaultBaseUrl).host;

  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isCircuitBroken => _circuitBroken;

  Future<void> checkNow() async {
    if (_disposed) return;
    _status = ConnectivityStatus.checking;
    notifyListeners();
    try {
      final result = await InternetAddress.lookup(
        _host,
      ).timeout(const Duration(seconds: 5));
      if (!_disposed) {
        _status = result.isNotEmpty && result[0].rawAddress.isNotEmpty
            ? ConnectivityStatus.online
            : ConnectivityStatus.offline;
        if (_status == ConnectivityStatus.online) {
          _circuitBroken = false;
        }
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        _status = ConnectivityStatus.offline;
        notifyListeners();
      }
    }
  }

  /// 触发熔断，停止 API 请求一段时间
  void tripCircuitBreaker() {
    if (_circuitBroken) return;
    _circuitBroken = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 10), () {
      if (!_disposed) {
        _circuitBroken = false;
        notifyListeners();
      }
    });
  }

  /// 把熔断器和 API 客户端连接起来：
  /// - 离线时不发起任何请求
  /// - 请求失败时触发熔断
  /// - 请求成功时自动解除熔断
  void bindToApiClient(GdMusicApiClient api) {
    _host = api.baseUri.host.isEmpty
        ? Uri.parse(GdMusicApiClient.defaultBaseUrl).host
        : api.baseUri.host;
    api.onRequestFailed = tripCircuitBreaker;
    api.setCircuitBreaker(() => isCircuitBroken);
    api.onRequestSuccess = () {
      if (_circuitBroken) {
        _circuitBroken = false;
        notifyListeners();
      }
    };
  }

  void updateApiHost(Uri uri) {
    if (uri.host.isEmpty || uri.host == _host) return;
    _host = uri.host;
    checkNow();
  }

  @override
  void dispose() {
    _disposed = true;
    _checkTimer?.cancel();
    super.dispose();
  }
}
