import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';

class Store {
  static const _k = 'entries';
  static SharedPreferences? _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static List<Entry> all() {
    final raw = _p?.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Entry.fromMap(e)).toList()
      ..sort((a,b) => b.date.compareTo(a.date));
  }

  static Future<void> save(Entry e) async {
    final list = all();
    final i = list.indexWhere((x) => x.id == e.id);
    if (i >= 0) list[i] = e; else list.insert(0, e);
    await _p!.setString(_k, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  static Future<void> delete(String id) async {
    final list = all()..removeWhere((e) => e.id == id);
    await _p!.setString(_k, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static List<Entry> search(String q) {
    final lq = q.toLowerCase();
    return all().where((e) => e.title.toLowerCase().contains(lq) || e.body.toLowerCase().contains(lq)).toList();
  }
}
