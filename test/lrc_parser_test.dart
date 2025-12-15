import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/utils/lrc_parser.dart';

void main() {
  test('parse lrc lines', () {
    final content = '[00:01.20]Line1\n[00:05.5]Line2\n[01:00]Line3';
    final lines = LrcParser.parse(content);
    expect(lines.length, 3);
    expect(lines[0].text, 'Line1');
    expect(lines[0].time, const Duration(seconds: 1, milliseconds: 200));
    expect(lines[1].time, const Duration(seconds: 5, milliseconds: 500));
    expect(lines[2].time, const Duration(minutes: 1));
  });
}
