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
      _previousEnergies = Float32List(maxBars);

  final int maxBars;
  final Float32List levels;
  final Float32List peaks;

  final Int32List _bandStarts;
  final Int32List _bandEnds;
  final Float32List _previousEnergies;

  int _bandCount = 0;
  int _mappedFftLength = 0;
  double _peakEnvelope = 0.015;
  double _rmsEnvelope = 0.008;
  double _fluxAverage = 0;
  double _beatCooldown = 0;
  double _beatIntensity = 0;

  double get beatIntensity => _beatIntensity;

  int get bandCount => _bandCount;

  int bandStart(int index) => _bandStarts[index];

  int bandEnd(int index) => _bandEnds[index];

  void setBandCount(int count) {
    final next = count.clamp(1, maxBars).toInt();
    if (next == _bandCount) return;
    _bandCount = next;
    _mappedFftLength = 0;
    for (var i = 0; i < _bandCount; i++) {
      levels[i] = 0;
      peaks[i] = 0;
      _previousEnergies[i] = 0;
    }
  }

  void process(Float32List fftData, bool isPlaying, double dt) {
    if (_bandCount == 0 || fftData.isEmpty) return;

    final safeDt = dt.clamp(0.016, 0.1).toDouble();
    _beatCooldown = math.max(0, _beatCooldown - safeDt);

    if (!isPlaying) {
      _decay(safeDt);
      return;
    }

    var framePeak = 0.0;
    var frameSquareSum = 0.0;
    for (var i = 0; i < fftData.length; i++) {
      final sample = fftData[i].clamp(0.0, 2.0);
      if (sample > framePeak) framePeak = sample;
      frameSquareSum += sample * sample;
    }

    if (framePeak < 0.00008) {
      _decay(safeDt);
      return;
    }

    final frameRms = math.sqrt(frameSquareSum / fftData.length);
    _peakEnvelope = math.max(framePeak, _peakEnvelope * 0.94);
    _rmsEnvelope = math.max(frameRms, _rmsEnvelope * 0.96);

    _ensureBandMapping(fftData.length);
    final noiseFloor = math.min(framePeak * 0.022, 0.0028);
    // Mix peak and RMS normalization to retain transients without letting a
    // single loud bin dominate every frame.
    final normalizer = math.max(
      0.010,
      math.max(_peakEnvelope * 0.73, _rmsEnvelope * 1.72),
    );
    final attack = 1 - math.exp(-safeDt / 0.045);
    final release = 1 - math.exp(-safeDt / 0.22);
    var spectralFlux = 0.0;

    for (var i = 0; i < _bandCount; i++) {
      final start = _bandStarts[i];
      final end = _bandEnds[i];
      var bandPeak = 0.0;
      var bandSquareSum = 0.0;
      final binCount = math.max(1, end - start);

      for (var j = start; j < end && j < fftData.length; j++) {
        final sample = fftData[j].clamp(0.0, 2.0);
        if (sample > bandPeak) bandPeak = sample;
        bandSquareSum += sample * sample;
      }

      final bandRms = math.sqrt(bandSquareSum / binCount);
      final energy = bandPeak * 0.62 + bandRms * 0.38;
      final bandProgress = _bandCount <= 1 ? 0.0 : i / (_bandCount - 1);
      final frequencyWeight = 0.86 + 0.20 * math.pow(bandProgress, 0.66);
      final normalized = ((energy - noiseFloor) / normalizer * 1.08).clamp(
        0.0,
        1.0,
      );
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
      } else {
        peaks[i] = math.max(0, peaks[i] - safeDt * 0.52);
      }
    }

    spectralFlux /= _bandCount;
    _fluxAverage = _fluxAverage == 0
        ? spectralFlux
        : _fluxAverage * 0.94 + spectralFlux * 0.06;
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
  }

  void _decay(double dt) {
    final coefficient = 1 - math.exp(-dt / 0.20);
    for (var i = 0; i < _bandCount; i++) {
      levels[i] += (0 - levels[i]) * coefficient;
      peaks[i] = math.max(0, peaks[i] - dt * 0.58);
      _previousEnergies[i] *= math.exp(-dt / 0.12);
    }
    _beatIntensity *= math.exp(-dt / 0.19);
    _fluxAverage *= math.exp(-dt / 0.24);
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
