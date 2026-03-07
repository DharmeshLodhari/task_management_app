import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../services/reminder_storage_service.dart';
import '../services/alarm_scheduler_service.dart';

class ManualReminderScreen extends StatefulWidget {
  const ManualReminderScreen({super.key});

  @override
  State<ManualReminderScreen> createState() => _ManualReminderScreenState();
}

class _ManualReminderScreenState extends State<ManualReminderScreen> {
  final _taskController = TextEditingController();
  final _reminderStorage = ReminderStorageService();
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveReminder() async {
    final taskText = _taskController.text.trim();
    if (taskText.isEmpty) {
      _showSnack('Please enter a task description.');
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Please select a time.');
      return;
    }

    final now = DateTime.now();
    DateTime reminderTime = DateTime(
      now.year, now.month, now.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );
    // If the chosen time has already passed today, schedule for tomorrow.
    if (reminderTime.isBefore(now)) {
      reminderTime = reminderTime.add(const Duration(days: 1));
    }

    final notifId = now.millisecondsSinceEpoch % 2147483647;
    final reminder = TaskReminder(
      id: now.millisecondsSinceEpoch.toString(),
      originalText: taskText,
      taskText: taskText,
      reminderTime: reminderTime,
      createdAt: now,
      notificationId: notifId,
    );

    final reminders = await _reminderStorage.load();
    reminders.insert(0, reminder);
    await _reminderStorage.save(reminders);

    await AlarmSchedulerService.schedule(
      id: notifId,
      scheduledTime: reminderTime,
      reminderId: reminder.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${_formatTime(reminderTime)}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeSelected = _selectedTime != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Manual Reminder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task text field
            const Text(
              'Task Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _taskController,
              decoration: InputDecoration(
                hintText: 'e.g. Call the doctor',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 28),

            // Time picker
            const Text(
              'Reminder Time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: timeSelected
                        ? const Color(0xFF000080)
                        : Colors.grey.shade400,
                    width: timeSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: timeSelected
                      ? const Color(0xFF000080).withOpacity(0.05)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: timeSelected ? const Color(0xFF000080) : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      timeSelected
                          ? _selectedTime!.format(context)
                          : 'Tap to pick a time',
                      style: TextStyle(
                        fontSize: 16,
                        color: timeSelected
                            ? const Color(0xFF000080)
                            : Colors.grey,
                        fontWeight: timeSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Repeat rule (basic)
            const Text(
              'Repeat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Currently this reminder does not repeat. (Recurring options will be added here.)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 36),

            // Save button
            ElevatedButton.icon(
              onPressed: _saveReminder,
              icon: const Icon(Icons.alarm_add),
              label: const Text('Set Reminder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
