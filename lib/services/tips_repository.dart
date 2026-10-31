import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tip.dart';

class TipsRepository {
  TipsRepository._();
  static final TipsRepository instance = TipsRepository._();

  TipsDatabase? _db;

  TipsDatabase? get db => _db;
  List<KitchenTip> get tips => _db?.tips ?? const [];
  List<TipGroup> get groups => _db?.groups ?? const [];

  Future<TipsDatabase> load() async {
    if (_db != null) return _db!;
    final raw = await rootBundle.loadString('assets/tips_db.json');
    _db = TipsDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _db!;
  }

  KitchenTip? byId(String id) {
    final db = _db;
    if (db == null) return null;
    try {
      return db.tips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  List<KitchenTip> byGroup(String groupId) {
    final db = _db;
    if (db == null) return const [];
    return db.tips.where((t) => t.groupId == groupId).toList();
  }
}
