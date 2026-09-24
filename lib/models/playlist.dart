import 'track.dart';

class Playlist {
  Playlist({required this.name, List<Track>? tracks, this.currentIndex = 0})
    : tracks = tracks ?? [];
  final String name;
  final List<Track> tracks;
  int currentIndex;

  Track? get current =>
      tracks.isEmpty || currentIndex < 0 || currentIndex >= tracks.length
      ? null
      : tracks[currentIndex];

  bool get isEmpty => tracks.isEmpty;

  void addAll(List<Track> items) {
    tracks.addAll(items);
  }
}
