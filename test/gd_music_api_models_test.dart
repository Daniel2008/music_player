import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/services/gd_music_api.dart';

void main() {
  test('GdSearchTrack.fromJson handles artist list', () {
    final t = GdSearchTrack.fromJson({
      'id': '123',
      'name': 'Song',
      'artist': ['A', 'B'],
      'album': 'Alb',
      'pic_id': 'p',
      'lyric_id': 'l',
      'source': 'netease',
    });

    expect(t.id, '123');
    expect(t.name, 'Song');
    expect(t.artists, ['A', 'B']);
    expect(t.artistText, 'A / B');
    expect(t.album, 'Alb');
    expect(t.lyricId, 'l');
    expect(t.source, 'netease');
  });

  test('GdSearchTrack.fromJson handles artist string', () {
    final t = GdSearchTrack.fromJson({
      'id': 1,
      'name': 'Song',
      'artist': 'Only',
      'album': '',
      'source': 'netease',
    });

    expect(t.artists, ['Only']);
  });

  test('GdTrackUrl.fromJson parses br/size', () {
    final u = GdTrackUrl.fromJson({
      'url': 'https://x',
      'br': '320',
      'size': 123,
    });
    expect(u.url, 'https://x');
    expect(u.br, 320);
    expect(u.sizeKb, 123);
  });
}
