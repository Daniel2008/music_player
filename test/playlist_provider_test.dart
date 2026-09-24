import 'package:music_player/services/storage_service.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/providers/playlist_provider.dart';
import 'package:music_player/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testStorageDirectory;

  setUp(() async {
    testStorageDirectory = await Directory.systemTemp.createTemp(
      'music_player_test_',
    );
    StorageService.instance.setTestDirectory(testStorageDirectory);
  });

  tearDown(() async {
    StorageService.instance.setTestDirectory(null);
    if (await testStorageDirectory.exists()) {
      await testStorageDirectory.delete(recursive: true);
    }
  });
  late PlaylistProvider playlistProvider;

  setUp(() {
    playlistProvider = PlaylistProvider();
  });

  group('PlaylistProvider', () {
    test('initial state is empty', () {
      expect(playlistProvider.isEmpty, isTrue);
      expect(playlistProvider.tracks.length, equals(0));
      expect(playlistProvider.current, isNull);
    });

    test('addTrack appends and sets index', () {
      final track = Track(title: 'Song 1', path: '/song1.mp3');
      playlistProvider.addTrack(track);
      expect(playlistProvider.tracks.length, equals(1));
      playlistProvider.setCurrentIndex(0);
      expect(playlistProvider.current?.title, equals('Song 1'));
    });

    test('removeTrack shrinks list', () {
      playlistProvider.addTrack(Track(title: 'A', path: '/a.mp3'));
      playlistProvider.addTrack(Track(title: 'B', path: '/b.mp3'));
      playlistProvider.removeTrack(0);
      expect(playlistProvider.tracks.length, equals(1));
      expect(playlistProvider.tracks.first.title, equals('B'));
    });

    test('removeTrack before current adjusts current index', () {
      playlistProvider.addTrack(Track(title: 'A', path: '/a.mp3'));
      playlistProvider.addTrack(Track(title: 'B', path: '/b.mp3'));
      playlistProvider.addTrack(Track(title: 'C', path: '/c.mp3'));
      playlistProvider.setCurrentIndex(2);

      playlistProvider.removeTrack(0);

      expect(playlistProvider.currentIndex, 1);
      expect(playlistProvider.current?.title, 'C');
    });

    test('reorderTrack moves a track down using adjusted index', () {
      playlistProvider.addTrack(Track(title: 'A', path: '/a.mp3'));
      playlistProvider.addTrack(Track(title: 'B', path: '/b.mp3'));
      playlistProvider.addTrack(Track(title: 'C', path: '/c.mp3'));

      playlistProvider.reorderTrack(0, 1);

      expect(
        playlistProvider.tracks.map((track) => track.title),
        orderedEquals(['B', 'A', 'C']),
      );
    });

    test('reorderTrack moves a track up', () {
      playlistProvider.addTrack(Track(title: 'A', path: '/a.mp3'));
      playlistProvider.addTrack(Track(title: 'B', path: '/b.mp3'));
      playlistProvider.addTrack(Track(title: 'C', path: '/c.mp3'));

      playlistProvider.reorderTrack(2, 0);

      expect(
        playlistProvider.tracks.map((track) => track.title),
        orderedEquals(['C', 'A', 'B']),
      );
    });

    test('next in loop wraps around', () {
      playlistProvider.addTrack(Track(title: 'A', path: '/a.mp3'));
      playlistProvider.addTrack(Track(title: 'B', path: '/b.mp3'));
      playlistProvider.setPlayMode(PlayMode.loop);
      playlistProvider.setCurrentIndex(0);
      playlistProvider.next();
      expect(playlistProvider.currentIndex, equals(1));
      playlistProvider.next();
      expect(playlistProvider.currentIndex, equals(0)); // wraps
    });

    test('next in sequence stops at end', () {
      playlistProvider.addTrack(Track(title: 'A', path: '/a.mp3'));
      playlistProvider.addTrack(Track(title: 'B', path: '/b.mp3'));
      playlistProvider.setPlayMode(PlayMode.sequence);
      playlistProvider.setCurrentIndex(0);
      playlistProvider.next();
      expect(playlistProvider.currentIndex, equals(1));
      playlistProvider.next();
      expect(playlistProvider.currentIndex, equals(1)); // stays at end
    });

    test('shuffle avoids current index', () {
      final tracks = List.generate(
        10,
        (i) => Track(title: 'Song $i', path: '/song$i.mp3'),
      );
      for (final t in tracks) {
        playlistProvider.addTrack(t);
      }
      playlistProvider.setPlayMode(PlayMode.shuffle);
      playlistProvider.setCurrentIndex(3);
      // Run shuffle multiple times, should never stay at current
      for (var i = 0; i < 10; i++) {
        playlistProvider.next();
        expect(playlistProvider.currentIndex, isNot(equals(3)));
        playlistProvider.setCurrentIndex(3);
      }
    });

    test('cyclePlayMode toggles modes', () {
      expect(playlistProvider.playMode, equals(PlayMode.loop)); // default
      playlistProvider.cyclePlayMode();
      expect(playlistProvider.playMode, equals(PlayMode.single));
      playlistProvider.cyclePlayMode();
      expect(playlistProvider.playMode, equals(PlayMode.shuffle));
    });

    test('clear empties everything', () {
      playlistProvider.addTrack(Track(title: 'X', path: '/x.mp3'));
      playlistProvider.clear();
      expect(playlistProvider.isEmpty, isTrue);
      expect(playlistProvider.currentIndex, equals(-1));
    });

    test('addOrSelectTrack 不会绕过播放列表上限', () {
      for (var i = 0; i < 500; i++) {
        playlistProvider.addTrack(
          Track(id: 'existing-$i', title: 'T$i', path: '/$i.mp3'),
        );
      }

      final result = playlistProvider.addOrSelectTrack(
        Track(id: 'overflow', title: 'Overflow', path: '/overflow.mp3'),
      );

      expect(result, equals(-1));
      expect(playlistProvider.tracks.length, equals(500));
      expect(
        playlistProvider.tracks.any((track) => track.id == 'overflow'),
        isFalse,
      );
    });
  });
}
