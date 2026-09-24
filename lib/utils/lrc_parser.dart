class LrcLine {
  LrcLine(this.time, this.text);
  final Duration time;
  final String text;
}

class LrcParser {
  static final _lineRegex = RegExp(
    r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\](.*)',
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

  /// 返回 [position] 对应的最后一行歌词索引。
  ///
  /// 时间轴已由 [parse] 排序，因此二分查找可将每帧的定位从 O(n) 降为 O(log n)。
  static int indexAt(List<LrcLine> lines, Duration position) {
    var low = 0;
    var high = lines.length - 1;
    var result = -1;

    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      if (lines[mid].time <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
