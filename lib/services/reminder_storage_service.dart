import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_reminder.dart';

class ReminderStorageService {
  static const _key = 'task_reminders';

  Future<List<TaskReminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list
        .map((e) =>
            TaskReminder.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<TaskReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      reminders.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
