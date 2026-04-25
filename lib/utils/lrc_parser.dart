class LrcLine {
  final Duration time;
  final String text;

  LrcLine(this.time, this.text);
}

class LrcParser {
  static final _lineRegex = RegExp(
    r"\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\](.*)",
  );

  static List<LrcLine> parse(String content) {
    final lines = <LrcLine>[];
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      for (final m in _lineRegex.allMatches(raw)) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final msStr = m.group(3);
        final ms = msStr == null ? 0 : int.parse(msStr.padRight(3, '0'));
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
