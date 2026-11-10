import 'dart:math' as math;
import 'dart:typed_data';

/// Converts SoLoud FFT frames into stable, perceptually distributed bands.
///
/// The processor owns its buffers so the visualizer can run without creating
/// allocations on every frame.
class VisualizerSignal {
  VisualizerSignal({required this.maxBars})
    : levels = Float32List(maxBars),
      peaks = Float32List(maxBars),
      _bandStarts = Int32List(maxBars),
      _bandEnds = Int32List(maxBars),
      _previousEnergies = Float32List(maxBars),
      _peakHold = Float32List(maxBars);

  final int maxBars;
  final Float32List levels;
  final Float32List peaks;

  final Int32List _bandStarts;
  final Int32List _bandEnds;
  final Float32List _previousEnergies;
  final Float32List _peakHold;

  int _bandCount = 0;
  int _mappedFftLength = 0;
  double _peakEnvelope = 0.015;
  double _rmsEnvelope = 0.008;
  double _fluxAverage = 0;
  double _beatCooldown = 0;
  double _beatIntensity = 0;
  double bassEnergy = 0;
  double midEnergy = 0;
  double highEnergy = 0;

  double get beatIntensity => _beatIntensity;

  int get bandCount => _bandCount;

  int bandStart(int index) => _bandStarts[index];

  int bandEnd(int index) => _bandEnds[index];

  void setBandCount(int count) {
    final next = count.clamp(1, maxBars).toInt();
    if (next == _bandCount) return;
    _bandCount = next;
    _mappedFftLength = 0;
    reset();
  }

  void reset() {
    levels.fillRange(0, maxBars, 0);
    peaks.fillRange(0, maxBars, 0);
    _peakHold.fillRange(0, maxBars, 0);
    _previousEnergies.fillRange(0, maxBars, 0);
    _peakEnvelope = 0.015;
    _rmsEnvelope = 0.008;
    _fluxAverage = 0;
    _beatCooldown = 0;
    _beatIntensity = 0;
    bassEnergy = midEnergy = highEnergy = 0;
  }

  double _sample(double value) =>
      value.isFinite ? value.clamp(0.0, 2.0).toDouble() : 0;

  void process(
    Float32List fftData,
    bool isPlaying,
    double dt, {
    double sensitivity = 1,
    double smoothing = 0.5,
    bool adaptive = true,
  }) {
    if (_bandCount == 0 || fftData.isEmpty) return;

    final safeDt = dt.clamp(0.004, 0.1).toDouble();
    _beatCooldown = math.max(0, _beatCooldown - safeDt);

    if (!isPlaying) {
      _decay(safeDt);
      return;
    }

    var framePeak = 0.0;
    var frameSquareSum = 0.0;
    for (var i = 0; i < fftData.length; i++) {
      final sample = _sample(fftData[i]);
      if (sample > framePeak) framePeak = sample;
      frameSquareSum += sample * sample;
    }

    if (framePeak < 0.00008) {
      _decay(safeDt);
      return;
    }

    final frameRms = math.sqrt(frameSquareSum / fftData.length);
    _peakEnvelope = math.max(
      framePeak,
      _peakEnvelope * math.exp(-safeDt / 1.4),
    );
    _rmsEnvelope = math.max(frameRms, _rmsEnvelope * math.exp(-safeDt / 2.2));

    _ensureBandMapping(fftData.length);
    final noiseFloor = math.min(framePeak * 0.022, 0.0028);
    // Mix peak and RMS normalization to retain transients without letting a
    // single loud bin dominate every frame.
    final normalizer = adaptive
        ? math.max(0.003, math.max(_peakEnvelope * 0.73, _rmsEnvelope * 1.72))
        : 0.72;
    final smooth = smoothing.clamp(0.0, 1.0);
    final attack = 1 - math.exp(-safeDt / (0.018 + smooth * 0.065));
    final release = 1 - math.exp(-safeDt / (0.10 + smooth * 0.32));
    var spectralFlux = 0.0;

    for (var i = 0; i < _bandCount; i++) {
      final start = _bandStarts[i];
      final end = _bandEnds[i];
      var bandPeak = 0.0;
      var bandSquareSum = 0.0;
      final binCount = math.max(1, end - start);

      for (var j = start; j < end && j < fftData.length; j++) {
        final sample = _sample(fftData[j]);
        if (sample > bandPeak) bandPeak = sample;
        bandSquareSum += sample * sample;
      }

      final bandRms = math.sqrt(bandSquareSum / binCount);
      final energy = bandPeak * 0.62 + bandRms * 0.38;
      final bandProgress = _bandCount <= 1 ? 0.0 : i / (_bandCount - 1);
      final frequencyWeight = 0.94 + 0.12 * math.pow(bandProgress, 0.66);
      final normalized =
          ((energy - noiseFloor) / normalizer * sensitivity.clamp(0.4, 2.5))
              .clamp(0.0, 1.0);
      final target =
          ((math.pow(normalized, 0.68).toDouble() * frequencyWeight * 0.94)
              .clamp(0.0, 1.0)
              .toDouble());
      final previous = _previousEnergies[i];
      final rise = energy - previous;
      if (rise > 0) {
        spectralFlux += rise * frequencyWeight;
      }
      _previousEnergies[i] = energy;

      final coefficient = target > levels[i] ? attack : release;
      levels[i] += (target - levels[i]) * coefficient;

      if (levels[i] >= peaks[i]) {
        peaks[i] = levels[i];
        _peakHold[i] = 0.22;
      } else if (_peakHold[i] > 0) {
        _peakHold[i] = math.max(0, _peakHold[i] - safeDt);
      } else {
        peaks[i] = math.max(levels[i], peaks[i] - safeDt * 0.38);
      }
    }

    spectralFlux /= _bandCount;
    final fluxBlend = 1 - math.exp(-safeDt / 0.54);
    _fluxAverage = _fluxAverage == 0
        ? spectralFlux
        : _fluxAverage + (spectralFlux - _fluxAverage) * fluxBlend;
    final beatThreshold = _fluxAverage * 1.34 + 0.008;
    if (spectralFlux > beatThreshold && _beatCooldown == 0) {
      final strength =
          ((spectralFlux - beatThreshold) / math.max(0.01, beatThreshold))
              .clamp(0.0, 1.0)
              .toDouble();
      _beatIntensity = math.max(_beatIntensity, 0.42 + strength * 0.58);
      _beatCooldown = 0.12;
    } else {
      _beatIntensity *= math.exp(-safeDt / 0.19);
    }
    _updateEnergies();
  }

  void _decay(double dt) {
    final coefficient = 1 - math.exp(-dt / 0.20);
    for (var i = 0; i < _bandCount; i++) {
      levels[i] += (0 - levels[i]) * coefficient;
      peaks[i] = math.max(0, peaks[i] - dt * 0.58);
      _peakHold[i] = 0;
      _previousEnergies[i] *= math.exp(-dt / 0.12);
    }
    _beatIntensity *= math.exp(-dt / 0.19);
    _fluxAverage *= math.exp(-dt / 0.24);
    _peakEnvelope = math.max(0.003, _peakEnvelope * math.exp(-dt / 1.4));
    _rmsEnvelope = math.max(0.002, _rmsEnvelope * math.exp(-dt / 2.2));
    _updateEnergies();
  }

  void _updateEnergies() {
    final bassEnd = (_bandCount * 0.2).ceil().clamp(1, _bandCount);
    final midEnd = (_bandCount * 0.6).ceil().clamp(bassEnd, _bandCount);
    double average(int start, int end) {
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        sum += levels[i];
      }
      return sum / math.max(1, end - start);
    }

    bassEnergy = average(0, bassEnd);
    midEnergy = average(bassEnd, midEnd);
    highEnergy = average(midEnd, _bandCount);
  }

  void _ensureBandMapping(int fftLength) {
    if (_mappedFftLength == fftLength) return;
    _mappedFftLength = fftLength;

    // A stronger low-frequency bias approximates a logarithmic frequency map
    // while remaining sample-rate independent.
    const exponent = 1.85;
    for (var i = 0; i < _bandCount; i++) {
      final start = (math.pow(i / _bandCount, exponent) * fftLength)
          .floor()
          .clamp(0, fftLength - 1)
          .toInt();
      final end = (math.pow((i + 1) / _bandCount, exponent) * fftLength)
          .ceil()
          .clamp(start + 1, fftLength)
          .toInt();
      _bandStarts[i] = start;
      _bandEnds[i] = end;
    }
  }
}
