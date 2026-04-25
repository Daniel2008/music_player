import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/gd_music_api.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<GdSearchTrack> _favorites = [];
  final Set<String> _favoriteIds = {};
  static const String _favoritesFileName = 'favorites.json';
  static const int _maxFavorites = 500;
  Timer? _saveDebounce;

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
          try {
            final track = GdSearchTrack.fromJson(item);
            _favorites.add(track);
            _favoriteIds.add(track.id);
          } catch (e) {
            debugPrint('跳过无效的收藏条目: $e');
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
    }
  }

  void _saveFavorites() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final file = await _getFavoritesFile();
        final jsonData = _favorites.map((track) => track.toJson()).toList();
        await file.writeAsString(jsonEncode(jsonData));
      } catch (e) {
        debugPrint('Failed to save favorites: $e');
      }
    });
  }

  Future<void> toggleFavorite(GdSearchTrack track) async {
    if (_favoriteIds.contains(track.id)) {
      _favorites.removeWhere((t) => t.id == track.id);
      _favoriteIds.remove(track.id);
    } else {
      if (_favorites.length >= _maxFavorites) {
        final oldest = _favorites.removeAt(0);
        _favoriteIds.remove(oldest.id);
      }
      _favorites.add(track);
      _favoriteIds.add(track.id);
    }
    notifyListeners();
    _saveFavorites();
  }

  /// O(1) 查询，代替原来的 O(n) 线性搜索
  bool isFavorite(GdSearchTrack track) {
    return _favoriteIds.contains(track.id);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
