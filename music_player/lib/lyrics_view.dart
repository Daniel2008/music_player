import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class LyricsView extends StatefulWidget {
  final String? currentSong;
  final Duration position;

  const LyricsView({
    super.key,
    required this.currentSong,
    required this.position,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  Map<int, String> _lyrics = {};
  bool _isLoading = false;
  String _currentLyric = '';

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSong != widget.currentSong) {
      _loadLyrics();
    }
    _updateCurrentLyric();
  }

  Future<void> _loadLyrics() async {
    if (widget.currentSong == null) {
      setState(() {
        _lyrics = {};
        _currentLyric = '';
      });
      return;
    }

    final songFile = File(widget.currentSong!);
    final lrcFile = File('${songFile.path}.lrc');
    
    if (await lrcFile.exists()) {
      // 从本地加载歌词
      final content = await lrcFile.readAsString();
      _parseLyrics(content);
    } else {
      // 从API获取歌词
      setState(() {
        _isLoading = true;
      });

      try {
        final songName = path.basename(widget.currentSong!);
        final encodedName = Uri.encodeComponent(songName);
        final response = await http.get(
          Uri.parse('https://api.52vmy.cn/api/music/lrc?msg=$encodedName&n=1')
        );

        if (response.statusCode == 200) {
          final content = utf8.decode(response.bodyBytes);
          // 保存歌词到本地
          await lrcFile.writeAsString(content);
          _parseLyrics(content);
        }
      } catch (e) {
        debugPrint('Error loading lyrics: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _parseLyrics(String content) {
    final Map<int, String> lyrics = {};
    final RegExp timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
    
    for (var line in content.split('\n')) {
      final matches = timeRegex.allMatches(line);
      final lyricText = line.replaceAll(timeRegex, '').trim();
      
      if (lyricText.isNotEmpty) {
        for (var match in matches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
          
          final timestamp = minutes * 60 * 1000 + seconds * 1000 + milliseconds;
          lyrics[timestamp] = lyricText;
        }
      }
    }

    setState(() {
      _lyrics = lyrics;
    });
  }

  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) {
      setState(() {
        _currentLyric = '';
      });
      return;
    }

    final currentTime = widget.position.inMilliseconds;
    String? lyric;
    int? lastTimestamp;

    for (var timestamp in _lyrics.keys) {
      if (timestamp <= currentTime) {
        if (lastTimestamp == null || timestamp > lastTimestamp) {
          lastTimestamp = timestamp;
          lyric = _lyrics[timestamp];
        }
      }
    }

    setState(() {
      _currentLyric = lyric ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.currentSong != null)
              Flexible(
                child: Text(
                  File(widget.currentSong!).uri.pathSegments.last,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (widget.currentSong != null)
              const SizedBox(height: 8),
            Flexible(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _currentLyric,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
