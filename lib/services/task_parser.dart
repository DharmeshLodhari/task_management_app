class ParsedTask {
  final String taskText;
  final DateTime scheduledTime;

  const ParsedTask({required this.taskText, required this.scheduledTime});
}

class TaskParser {
  // Matches all STT variants:
  // "5 PM", "5:00 PM", "5:00 pm", "5:00 p.m.", "5:00 P.M.", "5:00 p m", "5:00 p. m."
  static final _timePattern = RegExp(
    r'(?:at\s+)?(\d{1,2}(?::\d{2})?\s*[aApP]\.?\s*[mM]\.?)',
    caseSensitive: false,
  );

  static ParsedTask? parse(String text) {
    if (text.trim().isEmpty) return null;

    final timeMatch = _timePattern.firstMatch(text);
    if (timeMatch == null) return null;

    final timeStr = timeMatch.group(1)!.trim();
    final scheduledTime = _parseTime(timeStr);
    if (scheduledTime == null) return null;

    String taskText = text
        .replaceAll(RegExp(r'i have a task to\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'i need to\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'remind me to\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'please remind me\s*', caseSensitive: false), '')
        .replaceAll(timeMatch.group(0)!, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (taskText.endsWith('.')) {
      taskText = taskText.substring(0, taskText.length - 1).trim();
    }

    if (taskText.isNotEmpty) {
      taskText = taskText[0].toUpperCase() + taskText.substring(1);
    }

    return ParsedTask(
      taskText: taskText.isEmpty ? text.trim() : taskText,
      scheduledTime: scheduledTime,
    );
  }

  static DateTime? _parseTime(String timeStr) {
    final now = DateTime.now();
    // Normalize: strip dots (p.m. → pm), collapse spaces, lowercase
    final cleaned = timeStr
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final withColonAmPm = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)$');
    final withColon24 = RegExp(r'^(\d{1,2}):(\d{2})$');
    final withoutColon = RegExp(r'^(\d{1,2})\s*(am|pm)$');

    int hour = 0, minute = 0;
    Match? match;

    if ((match = withColonAmPm.firstMatch(cleaned)) != null) {
      hour = int.parse(match!.group(1)!);
      minute = int.parse(match.group(2)!);
      final amPm = match.group(3)!;
      if (amPm == 'pm' && hour != 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;
    } else if ((match = withColon24.firstMatch(cleaned)) != null) {
      hour = int.parse(match!.group(1)!);
      minute = int.parse(match.group(2)!);
    } else if ((match = withoutColon.firstMatch(cleaned)) != null) {
      hour = int.parse(match!.group(1)!);
      final amPm = match.group(2)!;
      if (amPm == 'pm' && hour != 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;
    } else {
      return null;
    }

    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
