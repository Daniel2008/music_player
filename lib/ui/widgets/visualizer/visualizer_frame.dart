import 'dart:math' as math;
import 'dart:typed_data';

import 'visualizer_signal.dart';

/// Mutable buffers read by the painter on every repaint, not widget rebuilds.
class VisualizerFrame {
  VisualizerFrame({int maxBars = 72, int historyLength = 64})
    : signal = VisualizerSignal(maxBars: maxBars),
      history = List.generate(historyLength, (_) => Float32List(maxBars));

  final VisualizerSignal signal;
  final List<Float32List> history;
  final Float32List waveform = Float32List(256);
  int historyHead = 0;
  int historyCount = 0;
  double phase = 0;
  double _historyElapsed = 0;
  double _waveEnvelope = 0.025;

  void resetHistory() {
    for (final row in history) {
      row.fillRange(0, row.length, 0);
    }
    historyHead = historyCount = 0;
    _historyElapsed = 0;
  }

  void captureHistory(double dt, double speed) {
    _historyElapsed += dt;
    final interval = 0.05 / speed.clamp(0.5, 2.0);
    while (_historyElapsed + 0.000001 >= interval) {
      _historyElapsed -= interval;
      history[historyHead].setRange(0, signal.bandCount, signal.levels);
      historyHead = (historyHead + 1) % history.length;
      historyCount = math.min(history.length, historyCount + 1);
    }
  }

  void processWaveform(
    Float32List samples,
    double dt, {
    double sensitivity = 1,
    bool adaptive = true,
  }) {
    if (samples.isEmpty) {
      waveform.fillRange(0, waveform.length, 0);
      return;
    }
    double sample(int i) =>
        samples[i].isFinite ? samples[i].clamp(-1.0, 1.0).toDouble() : 0;
    var mean = 0.0;
    for (var i = 0; i < samples.length; i++) {
      mean += sample(i);
    }
    mean /= samples.length;
    var peak = 0.0;
    for (var i = 0; i < samples.length; i++) {
      peak = math.max(peak, (sample(i) - mean).abs());
    }
    _waveEnvelope = math.max(
      0.025,
      math.max(peak, _waveEnvelope * math.exp(-dt / 1.2)),
    );
    final gain =
        sensitivity.clamp(0.4, 2.5) /
        (adaptive ? math.max(0.06, _waveEnvelope * 1.15) : 1);
    for (var i = 0; i < waveform.length; i++) {
      final position = i * (samples.length - 1) / (waveform.length - 1);
      final first = position.floor();
      final second = math.min(first + 1, samples.length - 1);
      final value =
          sample(first) +
          (sample(second) - sample(first)) * (position - first) -
          mean;
      waveform[i] = peak < 0.0005 ? 0 : (value * gain).clamp(-1.0, 1.0);
    }
  }

  void clearWaveform() {
    waveform.fillRange(0, waveform.length, 0);
    _waveEnvelope = 0.025;
  }
}
