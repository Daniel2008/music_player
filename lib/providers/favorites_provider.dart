import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/gd_music_api.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<GdSearchTrack> _favorites = [];
  final Set<String> _favoriteIds = {}; // 用 Set 索引加速 isFavorite 查询
  final String _favoritesFileName = 'favorites.json';

  List<GdSearchTrack> get favorites => _favorites;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<File> _getFavoritesFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_favoritesFileName');
  }

  Future<void> _loadFavorites() async {
    try {
      final file = await _getFavoritesFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(contents);
        _favorites.clear();
        _favoriteIds.clear();
        for (final item in jsonData) {
          final track = GdSearchTrack.fromJson(item);
          _favorites.add(track);
          _favoriteIds.add(track.id);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final file = await _getFavoritesFile();
      final jsonData = _favorites.map((track) => track.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Failed to save favorites: $e');
    }
  }

  Future<void> toggleFavorite(GdSearchTrack track) async {
    if (_favoriteIds.contains(track.id)) {
      _favorites.removeWhere((t) => t.id == track.id);
      _favoriteIds.remove(track.id);
    } else {
      _favorites.add(track);
      _favoriteIds.add(track.id);
    }
    notifyListeners();
    await _saveFavorites();
  }

  /// O(1) 查询，代替原来的 O(n) 线性搜索
  bool isFavorite(GdSearchTrack track) {
    return _favoriteIds.contains(track.id);
  }
}
