import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/ui/widgets/visualizer/visualizer_signal.dart';

void main() {
  group('VisualizerSignal', () {
    test('maps the complete FFT range into ordered bands', () {
      final signal = VisualizerSignal(maxBars: 48);
      signal.setBandCount(48);
      final fft = Float32List(256)..fillRange(0, 256, 0.5);

      signal.process(fft, true, 1 / 30);

      expect(signal.bandStart(0), 0);
      expect(signal.bandEnd(47), 256);
      for (var i = 1; i < signal.bandCount; i++) {
        expect(
          signal.bandStart(i),
          greaterThanOrEqualTo(signal.bandStart(i - 1)),
        );
        expect(signal.bandEnd(i), greaterThan(signal.bandStart(i)));
        expect(signal.bandEnd(i), lessThanOrEqualTo(256));
      }
    });

    test('tracks energy and decays after playback stops', () {
      final signal = VisualizerSignal(maxBars: 48);
      signal.setBandCount(48);
      final fft = Float32List(256)..fillRange(0, 256, 0.6);

      for (var frame = 0; frame < 6; frame++) {
        signal.process(fft, true, 1 / 30);
      }
      final activeLevel = signal.levels[24];
      expect(activeLevel, greaterThan(0.1));

      for (var frame = 0; frame < 6; frame++) {
        signal.process(Float32List(256), false, 1 / 30);
      }
      expect(signal.levels[24], lessThan(activeLevel));
      expect(signal.beatIntensity, lessThan(0.8));
    });
  });
}
