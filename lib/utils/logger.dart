import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 统一日志工具
///
/// - debug 模式：完整输出到 console + log
/// - release 模式：仅 warn/error
class AppLog {
  AppLog._();

  static const String _name = 'music_player';

  static void d(Object? message, {String? tag}) {
    if (kDebugMode) {
      _log(message.toString(), name: _name, level: 'D', tag: tag);
    }
  }

  static void i(Object? message, {String? tag}) {
    _log(message.toString(), name: _name, level: 'I', tag: tag);
  }

  static void w(Object? message, {String? tag, Object? error}) {
    _log(message.toString(), name: _name, level: 'W', tag: tag, error: error);
  }

  static void e(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stack,
  }) {
    _log(
      message.toString(),
      name: _name,
      level: 'E',
      tag: tag,
      error: error,
      stack: stack,
    );
  }

  static void _log(
    String message, {
    required String name,
    required String level,
    String? tag,
    Object? error,
    StackTrace? stack,
  }) {
    final prefix = tag == null ? '[$level]' : '[$level/$tag]';
    final line = '$prefix $message';
    if (kDebugMode) {
      // 同时输出到 debugPrint（IDE 控制台） 和 developer.log（DevTools）
      debugPrint(line);
    }
    developer.log(line, name: name, error: error, stackTrace: stack);
  }
}
