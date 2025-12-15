import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';

class Hotkeys {
  static Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
  }

  static Future<void> register(
    PlayerProvider p,
    PlaylistProvider playlist,
  ) async {
    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyP,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) async {
        if (p.isPlaying) {
          p.pause();
        } else {
          final current = playlist.current;
          if (current != null && p.duration == Duration.zero) {
            await p.playTrack(current);
          } else {
            p.play();
          }
        }
      },
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
