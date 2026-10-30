import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists search queries + recently browsed recipe ids (newest first).
class HistoryStore extends ChangeNotifier {
  static const _searchKey = 'search_history_v1';
  static const _browseKey = 'browse_history_v1';
  static const maxSearch = 20;
  static const maxBrowse = 40;

  final List<String> _searches = [];
  final List<BrowseEntry> _browses = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<String> get searches => List.unmodifiable(_searches);
  List<BrowseEntry> get browses => List.unmodifiable(_browses);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _searches
      ..clear()
      ..addAll(prefs.getStringList(_searchKey) ?? const []);
    _browses.clear();
    final raw = prefs.getStringList(_browseKey) ?? const [];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        _browses.add(BrowseEntry.fromJson(m));
      } catch (_) {/* skip bad */}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _searches.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    _searches.insert(0, q);
    while (_searches.length > maxSearch) {
      _searches.removeLast();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchKey, _searches);
  }

  Future<void> clearSearches() async {
    _searches.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchKey);
  }

  Future<void> addBrowse({
    required String id,
    required String title,
    required String categoryId,
    required String categoryName,
  }) async {
    _browses.removeWhere((e) => e.id == id);
    _browses.insert(
      0,
      BrowseEntry(
        id: id,
        title: title,
        categoryId: categoryId,
        categoryName: categoryName,
        atMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    while (_browses.length > maxBrowse) {
      _browses.removeLast();
    }
    notifyListeners();
    await _persistBrowse();
  }

  Future<void> clearBrowses() async {
    _browses.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_browseKey);
  }

  Future<void> _persistBrowse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _browseKey,
      _browses.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

class BrowseEntry {
  final String id;
  final String title;
  final String categoryId;
  final String categoryName;
  final int atMs;

  const BrowseEntry({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.atMs,
  });

  factory BrowseEntry.fromJson(Map<String, dynamic> j) => BrowseEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        categoryId: j['categoryId'] as String? ?? '',
        categoryName: j['categoryName'] as String? ?? '',
        atMs: j['atMs'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'atMs': atMs,
      };
}
