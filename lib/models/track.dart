import 'package:uuid/uuid.dart';

enum TrackKind { local, remote }

class Track {
  final String id;
  final String title;
  final String path;
  final String? artist;
  final String? artUri;
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
    String? id,
    required this.title,
    required this.path,
    this.artist,
    this.artUri,
    this.duration,
    this.kind = TrackKind.local,
    this.remoteSource,
    this.remoteTrackId,
    this.remoteLyricId,
    this.lyricKey,
  }) : id = id ?? const Uuid().v4();

  bool get isRemote => kind == TrackKind.remote;

  /// 为远程曲目生成确定性 ID
  /// 基于 source 和 trackId，确保同一首歌始终有相同的 ID
  static String generateRemoteId(String source, String trackId) {
    return 'remote_${source}_$trackId';
  }

  /// 创建一个副本，可以覆盖指定的字段
  Track copyWith({
    String? id,
    String? title,
    String? path,
    String? artist,
    String? artUri,
    Duration? duration,
    TrackKind? kind,
    String? remoteSource,
    String? remoteTrackId,
    String? remoteLyricId,
    String? lyricKey,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      artist: artist ?? this.artist,
      artUri: artUri ?? this.artUri,
      duration: duration ?? this.duration,
      kind: kind ?? this.kind,
      remoteSource: remoteSource ?? this.remoteSource,
      remoteTrackId: remoteTrackId ?? this.remoteTrackId,
      remoteLyricId: remoteLyricId ?? this.remoteLyricId,
      lyricKey: lyricKey ?? this.lyricKey,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
