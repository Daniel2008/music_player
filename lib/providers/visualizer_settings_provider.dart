import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// Shared visualizer tuning persisted across normal and fullscreen views.
class VisualizerSettingsProvider extends ChangeNotifier {
  VisualizerSettingsProvider() {
    _load();
  }

  static const _sensitivityKey = 'visualizer_sensitivity';
  static const _smoothingKey = 'visualizer_smoothing';
  static const _glowKey = 'visualizer_glow_strength';
  static const _backgroundKey = 'visualizer_background_opacity';
  static const _fpsKey = 'visualizer_max_fps';

  double sensitivity = 1.0;
  double smoothing = 0.5;
  double glowStrength = 1.0;
  double backgroundOpacity = 0.0;
  int maxFps = 30;
  Timer? _saveTimer;
  int _revision = 0;
  bool _disposed = false;

  Future<void> _load() async {
    final loadRevision = _revision;
    final prefs = await StorageService.instance.prefs;
    if (_disposed || loadRevision != _revision) return;
    sensitivity = _clamp(
      prefs.getDouble(_sensitivityKey) ?? sensitivity,
      0.4,
      2.5,
    );
    smoothing = _clamp(prefs.getDouble(_smoothingKey) ?? smoothing, 0.0, 1.0);
    glowStrength = _clamp(prefs.getDouble(_glowKey) ?? glowStrength, 0.0, 1.8);
    backgroundOpacity = _clamp(
      prefs.getDouble(_backgroundKey) ?? backgroundOpacity,
      0.0,
      0.45,
    );
    maxFps = _normalizeFps(prefs.getInt(_fpsKey) ?? maxFps);
    notifyListeners();
  }

  double _clamp(double value, double min, double max) =>
      value.isFinite ? value.clamp(min, max).toDouble() : min;

  void setSensitivity(double value) {
    sensitivity = _clamp(value, 0.4, 2.5);
    _revision++;
    notifyListeners();
    _scheduleSave();
  }

  void setSmoothing(double value) {
    smoothing = _clamp(value, 0.0, 1.0);
    _revision++;
    notifyListeners();
    _scheduleSave();
  }

  void setGlowStrength(double value) {
    glowStrength = _clamp(value, 0.0, 1.8);
    _revision++;
    notifyListeners();
    _scheduleSave();
  }

  void setBackgroundOpacity(double value) {
    backgroundOpacity = _clamp(value, 0.0, 0.45);
    _revision++;
    notifyListeners();
    _scheduleSave();
  }

  void setMaxFps(int value) {
    maxFps = _normalizeFps(value);
    _revision++;
    notifyListeners();
    _scheduleSave();
  }

  int _normalizeFps(int value) {
    if (value <= 22) return 15;
    if (value < 45) return 30;
    return 60;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      _saveTimer = null;
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    if (_disposed) return;
    final prefs = await StorageService.instance.prefs;
    await Future.wait([
      prefs.setDouble(_sensitivityKey, sensitivity),
      prefs.setDouble(_smoothingKey, smoothing),
      prefs.setDouble(_glowKey, glowStrength),
      prefs.setDouble(_backgroundKey, backgroundOpacity),
      prefs.setInt(_fpsKey, maxFps),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    super.dispose();
  }
}
