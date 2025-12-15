import 'package:uuid/uuid.dart';

enum TrackKind { local, remote }

class Track {
  final String id;
  final String title;
  final String path;
  final Duration? duration;

  /// `local`: `path` is a local filesystem path.
  /// `remote`: `path` is a playable URL.
  final TrackKind kind;

  /// For `remote` tracks.
  final String? remoteSource;
  final String? remoteTrackId;
  final String? remoteLyricId;
  final String? lyricKey;

  Track({
    required this.title,
    required this.path,
    this.duration,
    this.kind = TrackKind.local,
    this.remoteSource,
    this.remoteTrackId,
    this.remoteLyricId,
    this.lyricKey,
  }) : id = const Uuid().v4();

  bool get isRemote => kind == TrackKind.remote;
}
