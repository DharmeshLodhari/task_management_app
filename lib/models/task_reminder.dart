class TaskReminder {
  final String id;
  final String originalText;
  final String taskText;
  final DateTime reminderTime;
  final DateTime createdAt;
  final int notificationId;

  const TaskReminder({
    required this.id,
    required this.originalText,
    required this.taskText,
    required this.reminderTime,
    required this.createdAt,
    required this.notificationId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalText': originalText,
        'taskText': taskText,
        'reminderTime': reminderTime.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'notificationId': notificationId,
      };

  factory TaskReminder.fromJson(Map<String, dynamic> json) => TaskReminder(
        id: json['id'] as String,
        originalText: json['originalText'] as String,
        taskText: json['taskText'] as String,
        reminderTime: DateTime.parse(json['reminderTime'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        notificationId: json['notificationId'] as int,
      );
}
