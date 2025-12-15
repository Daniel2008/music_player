import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/gd_music_api.dart';

class SearchProvider extends ChangeNotifier {
  final GdMusicApiClient _gdApi;
  
  List<GdSearchTrack> searchResults = const [];
  bool isSearching = false;
  String? searchError;
  int _searchSeq = 0;
  
  SearchProvider({GdMusicApiClient? gdApi}) 
    : _gdApi = gdApi ?? GdMusicApiClient();

  Future<void> searchOnline(String keyword, {String source = 'netease'}) async {
    final q = keyword.trim();
    if (q.isEmpty) {
      searchResults = const [];
      searchError = null;
      isSearching = false;
      notifyListeners();
      return;
    }

    final seq = ++_searchSeq;
    isSearching = true;
    searchError = null;
    notifyListeners();

    try {
      final results = await _gdApi.search(keyword: q, source: source);
      if (seq != _searchSeq) return;
      searchResults = results;
    } catch (e) {
      if (seq != _searchSeq) return;
      searchError = e.toString();
      searchResults = const [];
    } finally {
      if (seq == _searchSeq) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    searchResults = const [];
    searchError = null;
    isSearching = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _gdApi.close();
    super.dispose();
  }
}
