import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/utils/lrc_parser.dart';

void main() {
  test('parse lrc lines', () {
    const content = '[00:01.20]Line1\n[00:05.5]Line2\n[01:00]Line3';
    final lines = LrcParser.parse(content);
    expect(lines.length, 3);
    expect(lines[0].text, 'Line1');
    expect(lines[0].time, const Duration(seconds: 1, milliseconds: 200));
    expect(lines[1].time, const Duration(seconds: 5, milliseconds: 500));
    expect(lines[2].time, const Duration(minutes: 1));
  });

  test('indexAt finds the active lyric line with binary search', () {
    final lines = LrcParser.parse('[00:01]Line1\n[00:05.5]Line2\n[01:00]Line3');

    expect(LrcParser.indexAt(lines, Duration.zero), -1);
    expect(LrcParser.indexAt(lines, const Duration(seconds: 1)), 0);
    expect(LrcParser.indexAt(lines, const Duration(seconds: 6)), 1);
    expect(LrcParser.indexAt(lines, const Duration(minutes: 2)), 2);
  });
}
