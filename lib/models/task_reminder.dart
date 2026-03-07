enum RecurrenceType { none, daily, weekly, monthly, customInterval }

enum ReminderStatus { pending, completed }

class RecurrenceRule {
  final RecurrenceType type;
  final List<int>? weekdays; // 1=Mon..7=Sun
  final int? intervalDays;   // for customInterval

  const RecurrenceRule({
    required this.type,
    this.weekdays,
    this.intervalDays,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'weekdays': weekdays,
        'intervalDays': intervalDays,
      };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
        type: RecurrenceType.values
            .firstWhere((e) => e.name == (json['type'] as String)),
        weekdays: (json['weekdays'] as List?)?.cast<int>(),
        intervalDays: json['intervalDays'] as int?,
      );
}

class TaskReminder {
  final String id;
  final String originalText;
  final String taskText;
  final DateTime reminderTime;
  final DateTime createdAt;
  final int notificationId;
  final RecurrenceRule? recurrence;
  final ReminderStatus status;

  const TaskReminder({
    required this.id,
    required this.originalText,
    required this.taskText,
    required this.reminderTime,
    required this.createdAt,
    required this.notificationId,
    this.recurrence,
    this.status = ReminderStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalText': originalText,
        'taskText': taskText,
        'reminderTime': reminderTime.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'notificationId': notificationId,
        'recurrence': recurrence?.toJson(),
        'status': status.name,
      };

  factory TaskReminder.fromJson(Map<String, dynamic> json) => TaskReminder(
        id: json['id'] as String,
        originalText: json['originalText'] as String,
        taskText: json['taskText'] as String,
        reminderTime: DateTime.parse(json['reminderTime'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        notificationId: json['notificationId'] as int,
        recurrence: json['recurrence'] == null
            ? null
            : RecurrenceRule.fromJson(
                (json['recurrence'] as Map).cast<String, dynamic>(),
              ),
        status: (json['status'] as String?) == null
            ? ReminderStatus.pending
            : ReminderStatus.values.firstWhere(
                (e) => e.name == json['status'],
                orElse: () => ReminderStatus.pending,
              ),
      );
}
