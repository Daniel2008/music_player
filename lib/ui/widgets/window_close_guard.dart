import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowCloseGuard extends StatefulWidget {
  const WindowCloseGuard({
    super.key,
    required this.onSave,
    required this.child,
  });
  final Future<void> Function() onSave;
  final Widget child;

  @override
  State<WindowCloseGuard> createState() => _WindowCloseGuardState();
}

class _WindowCloseGuardState extends State<WindowCloseGuard>
    with WindowListener {
  bool _saving = false;
  bool get _desktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_desktop) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
    }
  }

  @override
  void onWindowClose() => unawaited(_saveAndClose());

  Future<void> _saveAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (mounted) await windowManager.destroy();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存失败，窗口已保留。请检查磁盘空间或目录权限后重试。'),
            action: SnackBarAction(label: '重试', onPressed: onWindowClose),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    if (_desktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    canRequestFocus: !_saving,
    child: AbsorbPointer(absorbing: _saving, child: widget.child),
  );
}
