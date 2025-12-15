import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class PlaylistProvider extends ChangeNotifier {
  final Playlist playlist;

  PlaylistProvider({Playlist? initialPlaylist})
    : playlist = initialPlaylist ?? Playlist(name: '默认播放列表');

  Track? get current => playlist.current;
  bool get isEmpty => playlist.isEmpty;
  int get currentIndex => playlist.currentIndex;

  void addTrack(Track track) {
    playlist.tracks.add(track);
    notifyListeners();
  }

  void addAll(List<Track> tracks) {
    playlist.tracks.addAll(tracks);
    notifyListeners();
  }

  void removeTrack(int index) {
    if (index < 0 || index >= playlist.tracks.length) return;
    playlist.tracks.removeAt(index);
    if (playlist.currentIndex >= playlist.tracks.length) {
      playlist.currentIndex = playlist.tracks.length - 1;
    }
    notifyListeners();
  }

  void clear() {
    playlist.tracks.clear();
    playlist.currentIndex = -1;
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < playlist.tracks.length) {
      playlist.currentIndex = index;
      notifyListeners();
    }
  }

  void next() {
    playlist.next();
    notifyListeners();
  }

  void previous() {
    playlist.previous();
    notifyListeners();
  }

  /// 更新当前曲目的路径（用于在线曲目解析后更新 URL）
  void updateCurrentTrackPath(String path) {
    final current = playlist.current;
    if (current != null) {
      final index = playlist.currentIndex;
      if (index >= 0 && index < playlist.tracks.length) {
        playlist.tracks[index] = current.copyWith(path: path);
        notifyListeners();
      }
    }
  }

  /// 更新当前曲目的封面
  void updateCurrentTrackArtUri(String? artUri) {
    final current = playlist.current;
    if (current != null) {
      final index = playlist.currentIndex;
      if (index >= 0 && index < playlist.tracks.length) {
        playlist.tracks[index] = current.copyWith(artUri: artUri);
        notifyListeners();
      }
    }
  }

  /// 更新指定索引的曲目
  void updateTrackAt(int index, Track track) {
    if (index >= 0 && index < playlist.tracks.length) {
      playlist.tracks[index] = track;
      notifyListeners();
    }
  }

  Future<void> addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      final tracks = result.files.map((file) {
        final fileName = file.name;
        final title = fileName.substring(0, fileName.lastIndexOf('.'));
        return Track(title: title, path: file.path ?? '');
      }).toList();

      addAll(tracks);
    }
  }

  Future<void> addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      final directory = Directory(result);
      final files = directory
          .listSync()
          .where((entity) => entity is File && _isAudioFile(entity.path))
          .cast<File>()
          .toList();

      final tracks = files.map((file) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final title = fileName.substring(0, fileName.lastIndexOf('.'));
        return Track(title: title, path: file.path);
      }).toList();

      addAll(tracks);
    }
  }

  bool _isAudioFile(String path) {
    final audioExtensions = ['.mp3', '.wav', '.aac', '.flac', '.ogg', '.wma'];
    final extension = path.toLowerCase().substring(path.lastIndexOf('.'));
    return audioExtensions.contains(extension);
  }
}
