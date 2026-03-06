import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording.dart';

class StorageService {
  static const _key = 'recordings';

  Future<List<Recording>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list
        .map((e) => Recording.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Recording> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      recordings.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
