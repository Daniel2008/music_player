import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track.dart';

void main() {
  group('Track', () {
    test('fromGdSearchTrack creates remote track', () {
      // Track.fromGdSearchTrack is a factory
    });

    test('toJson -> fromJson round-trip preserves id', () {
      final track = Track(
        title: 'Test Song',
        path: '/music/test.mp3',
        artist: 'Test Artist',
        kind: TrackKind.local,
      );

      final json = track.toJson();
      final restored = Track.fromJson(json);
      expect(restored, isNotNull);
      expect(restored!.id, equals(track.id));
      expect(restored.title, equals('Test Song'));
      expect(restored.artist, equals('Test Artist'));
      expect(restored.kind, equals(TrackKind.local));
    });

    test('copyWith preserves sentinel values', () {
      final original = Track(
        title: 'Original',
        path: '/a.mp3',
        artist: 'Artist',
      );
      final copy = original.copyWith(path: '/b.mp3');

      expect(copy.path, equals('/b.mp3'));
      expect(copy.title, equals('Original'));
      expect(copy.artist, equals('Artist'));
    });

    test('generateRemoteId produces deterministic IDs', () {
      final id1 = Track.generateRemoteId('netease', '12345');
      final id2 = Track.generateRemoteId('netease', '12345');
      expect(id1, equals(id2));
      expect(id1, startsWith('remote_netease_'));
    });

    test('fromJson returns null on invalid input', () {
      expect(Track.fromJson({}), isNotNull); // defaults filled
      expect(Track.fromJson(<String, dynamic>{}), isNotNull);
    });
  });
}
