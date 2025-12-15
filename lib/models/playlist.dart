import 'track.dart';

class Playlist {
  final String name;
  final List<Track> tracks;
  int currentIndex;

  Playlist({required this.name, List<Track>? tracks, this.currentIndex = 0})
    : tracks = tracks ?? [];

  Track? get current => tracks.isEmpty ? null : tracks[currentIndex];

  bool get isEmpty => tracks.isEmpty;

  void addAll(List<Track> items) {
    tracks.addAll(items);
  }

  void next() {
    if (tracks.isEmpty) return;
    currentIndex = (currentIndex + 1) % tracks.length;
  }

  void previous() {
    if (tracks.isEmpty) return;
    currentIndex = (currentIndex - 1 + tracks.length) % tracks.length;
  }
}
