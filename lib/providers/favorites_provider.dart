import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/gd_music_api.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider() {
    ready = _loadFavorites();
  }
  final List<GdSearchTrack> _favorites = [];
  final Set<String> _favoriteIds = {};
  static const String _fileName = 'favorites.json';
  static const int _maxFavorites = 500;
  static const int _schemaVersion = 1;
  Timer? _saveDebounce;
  late final Future<void> ready;

  List<GdSearchTrack> get favorites => _favorites;

  String _favoriteKey(GdSearchTrack track) => '${track.source}_${track.id}';

  Future<void> _loadFavorites() async {
    final result = await StorageService.instance
        .readJsonFile<List<GdSearchTrack>>(
          fileName: _fileName,
          currentSchemaVersion: _schemaVersion,
          decode: (raw, _) {
            if (raw is! List) return null;
            return raw
                .whereType<Map>()
                .map((e) {
                  try {
                    return GdSearchTrack.fromJson(e.cast<String, dynamic>());
                  } catch (e) {
                    AppLog.w('跳过无效的收藏条目: $e');
                    return null;
                  }
                })
                .whereType<GdSearchTrack>()
                .toList();
          },
        );
    if (result != null) {
      _favorites.clear();
      _favoriteIds.clear();
      for (final track in result) {
        _favorites.add(track);
        _favoriteIds.add(_favoriteKey(track));
      }
      notifyListeners();
    }
  }

  void _saveFavorites() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      await StorageService.instance.writeJsonFile(
        fileName: _fileName,
        currentSchemaVersion: _schemaVersion,
        encode: () => _favorites.map((track) => track.toJson()).toList(),
      );
    });
  }

  Future<void> toggleFavorite(GdSearchTrack track) async {
    final key = _favoriteKey(track);
    if (_favoriteIds.contains(key)) {
      _favorites.removeWhere((t) => _favoriteKey(t) == key);
      _favoriteIds.remove(key);
    } else {
      if (_favorites.length >= _maxFavorites) {
        final oldest = _favorites.removeAt(0);
        _favoriteIds.remove(_favoriteKey(oldest));
      }
      _favorites.add(track);
      _favoriteIds.add(key);
    }
    notifyListeners();
    _saveFavorites();
  }

  /// O(1) 查询，代替原来的 O(n) 线性搜索
  bool isFavorite(GdSearchTrack track) {
    return _favoriteIds.contains(_favoriteKey(track));
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    await _doSave();
  }

  Future<void> _doSave() async {
    await StorageService.instance.writeJsonFile(
      fileName: _fileName,
      currentSchemaVersion: _schemaVersion,
      encode: () => _favorites.map((track) => track.toJson()).toList(),
    );
  }

  @override
  void dispose() {
    unawaited(flush());
    super.dispose();
  }
}
