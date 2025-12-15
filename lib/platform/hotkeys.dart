import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';
import '../providers/player_provider.dart';

class Hotkeys {
  static Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
  }

  static Future<void> register(PlayerProvider p) async {
    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyP,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => p.isPlaying ? p.pause() : p.play(),
    );
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.arrowRight,
        modifiers: [HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => p.seek(p.position + const Duration(seconds: 5)),
    );
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.arrowLeft,
        modifiers: [HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) => p.seek(p.position - const Duration(seconds: 5)),
    );
  }
}
