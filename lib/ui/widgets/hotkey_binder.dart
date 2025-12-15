import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../platform/hotkeys.dart';
import '../../providers/player_provider.dart';

class HotkeyBinder extends StatefulWidget {
  const HotkeyBinder({super.key});

  @override
  State<HotkeyBinder> createState() => _HotkeyBinderState();
}

class _HotkeyBinderState extends State<HotkeyBinder> {
  bool _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registered) return;
    final p = context.read<PlayerProvider>();
    _registered = true;
    // Hotkey registration can fail in restricted environments.
    // Keep the app running even if hotkeys are unavailable.
    Hotkeys.register(p).catchError((_) {});
  }

  @override
  void dispose() {
    // Best-effort cleanup.
    Hotkeys.unregisterAll().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
