import 'package:uuid/uuid.dart';
import '../services/gd_music_api.dart';

const Object _sentinel = Object();

enum TrackKind { local, remote }

class Track {
  static const _uuid = Uuid();
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
  }) : id = id ?? _uuid.v4();

  bool get isRemote => kind == TrackKind.remote;

  /// 从在线搜索结果创建 Track（统一转换逻辑）
  factory Track.fromGdSearchTrack(GdSearchTrack item) {
    final displayArtist = item.artistText;
    final title = displayArtist.isEmpty
        ? item.name
        : '${item.name} - $displayArtist';
    return Track(
      id: Track.generateRemoteId(item.source, item.id),
      title: title,
      path: '',
      artist: displayArtist.isEmpty ? null : displayArtist,
      kind: TrackKind.remote,
      remoteSource: item.source,
      remoteTrackId: item.id,
      remoteLyricId: item.lyricId ?? item.id,
      lyricKey: 'gd_${item.source}_${item.lyricId ?? item.id}',
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'artist': artist,
      'artUri': artUri,
      'durationMs': duration?.inMilliseconds,
      'kind': kind.index,
      'remoteSource': remoteSource,
      'remoteTrackId': remoteTrackId,
      'remoteLyricId': remoteLyricId,
      'lyricKey': lyricKey,
    };
  }

  /// 从 JSON 反序列化
  static Track? fromJson(Map<String, dynamic> json) {
    try {
      final durationMs = json['durationMs'] as int?;
      final kindIndex = json['kind'] as int? ?? 0;
      return Track(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '未知曲目',
        path: json['path'] as String? ?? '',
        artist: json['artist'] as String?,
        artUri: json['artUri'] as String?,
        duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
        kind: TrackKind.values[kindIndex.clamp(0, TrackKind.values.length - 1)],
        remoteSource: json['remoteSource'] as String?,
        remoteTrackId: json['remoteTrackId'] as String?,
        remoteLyricId: json['remoteLyricId'] as String?,
        lyricKey: json['lyricKey'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// 为远程曲目生成确定性 ID
  /// 基于 source 和 trackId，确保同一首歌始终有相同的 ID
  static String generateRemoteId(String source, String trackId) {
    return 'remote_${source}_$trackId';
  }

  /// 创建一个副本，可以覆盖指定的字段
  /// 传入 null 会将字段真正置为 null（而非跳过）
  /// 如果不想修改某字段，不传该参数即可
  Track copyWith({
    String? id,
    String? title,
    String? path,
    Object? artist = _sentinel,
    Object? artUri = _sentinel,
    Object? duration = _sentinel,
    TrackKind? kind,
    Object? remoteSource = _sentinel,
    Object? remoteTrackId = _sentinel,
    Object? remoteLyricId = _sentinel,
    Object? lyricKey = _sentinel,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      artist: artist == _sentinel ? this.artist : artist as String?,
      artUri: artUri == _sentinel ? this.artUri : artUri as String?,
      duration: duration == _sentinel ? this.duration : duration as Duration?,
      kind: kind ?? this.kind,
      remoteSource: remoteSource == _sentinel ? this.remoteSource : remoteSource as String?,
      remoteTrackId: remoteTrackId == _sentinel ? this.remoteTrackId : remoteTrackId as String?,
      remoteLyricId: remoteLyricId == _sentinel ? this.remoteLyricId : remoteLyricId as String?,
      lyricKey: lyricKey == _sentinel ? this.lyricKey : lyricKey as String?,
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
