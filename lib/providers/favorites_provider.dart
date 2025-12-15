import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/gd_music_api.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<GdSearchTrack> _favorites = [];
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
        _favorites.addAll(
          jsonData.map((item) => GdSearchTrack.fromJson(item)).toList(),
        );
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
    final index = _favorites.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.add(track);
    }
    notifyListeners();
    await _saveFavorites();
  }

  bool isFavorite(GdSearchTrack track) {
    return _favorites.any((t) => t.id == track.id);
  }
}
