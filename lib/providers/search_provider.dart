import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/gd_music_api.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider({GdMusicApiClient? gdApi})
    : _gdApi = gdApi ?? GdMusicApiClient();
  final GdMusicApiClient _gdApi;

  List<GdSearchTrack> searchResults = const [];
  bool isSearching = false;
  String? searchError;
  int _searchSeq = 0;
  bool _disposed = false;

  Future<void> searchOnline(String keyword, {String source = 'netease'}) async {
    final q = keyword.trim();
    final seq = ++_searchSeq;
    if (q.isEmpty) {
      searchResults = const [];
      searchError = null;
      isSearching = false;
      notifyListeners();
      return;
    }

    isSearching = true;
    searchError = null;
    notifyListeners();

    try {
      final results = await _gdApi.search(keyword: q, source: source);
      if (seq != _searchSeq || _disposed) return;
      searchResults = results;
    } catch (e) {
      if (seq != _searchSeq || _disposed) return;
      searchError = e.toString();
      searchResults = const [];
    } finally {
      if (seq == _searchSeq && !_disposed) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _searchSeq++;
    searchResults = const [];
    searchError = null;
    isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
