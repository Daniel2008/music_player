class LrcLine {
  final Duration time;
  final String text;

  LrcLine(this.time, this.text);
}

class LrcParser {
  static List<LrcLine> parse(String content) {
    final lines = <LrcLine>[];
    for (final raw in content.split('\n')) {
      final matches = RegExp(
        r"\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,2}))?\](.*)",
      ).allMatches(raw);
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final msStr = m.group(3);
        final ms = msStr == null ? 0 : int.parse(msStr.padRight(2, '0')) * 10;
        final text = m.group(4)!.trim();
        lines.add(
          LrcLine(Duration(minutes: min, seconds: sec, milliseconds: ms), text),
        );
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}
