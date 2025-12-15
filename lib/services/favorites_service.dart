import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gd_music_api.dart';

/// 在线音乐收藏管理
class FavoritesService {
  static const _key = 'online_favorites';

  List<GdSearchTrack> _favorites = [];
  bool _loaded = false;

  List<GdSearchTrack> get favorites => List.unmodifiable(_favorites);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _favorites = list
            .map((e) => _trackFromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _favorites = [];
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_favorites.map(_trackToJson).toList());
    await prefs.setString(_key, json);
  }

  bool isFavorite(GdSearchTrack track) {
    return _favorites.any((t) => t.id == track.id && t.source == track.source);
  }

  Future<void> add(GdSearchTrack track) async {
    if (isFavorite(track)) return;
    _favorites.insert(0, track);
    await _save();
  }

  Future<void> remove(GdSearchTrack track) async {
    _favorites.removeWhere((t) => t.id == track.id && t.source == track.source);
    await _save();
  }

  Future<void> toggle(GdSearchTrack track) async {
    if (isFavorite(track)) {
      await remove(track);
    } else {
      await add(track);
    }
  }

  Map<String, dynamic> _trackToJson(GdSearchTrack t) => {
    'id': t.id,
    'name': t.name,
    'artist': t.artists,
    'album': t.album,
    'pic_id': t.picId,
    'lyric_id': t.lyricId,
    'source': t.source,
  };

  GdSearchTrack _trackFromJson(Map<String, dynamic> json) {
    return GdSearchTrack.fromJson(json);
  }
}
