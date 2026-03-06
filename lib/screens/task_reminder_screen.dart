import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/task_reminder.dart';
import '../services/task_parser.dart';
import '../services/reminder_storage_service.dart';
import '../services/alarm_scheduler_service.dart';

class TaskReminderScreen extends StatefulWidget {
  const TaskReminderScreen({super.key});

  @override
  State<TaskReminderScreen> createState() => _TaskReminderScreenState();
}

class _TaskReminderScreenState extends State<TaskReminderScreen> {
  final _stt = SpeechToText();
  final _reminderStorage = ReminderStorageService();

  bool _sttAvailable = false;
  bool _isListening = false;
  String _transcription = '';
  ParsedTask? _parsedTask;

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if ((status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) &&
            mounted) {
          setState(() => _isListening = false);
          _onListeningDone();
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      _showSnack('Speech recognition is not available on this device.');
      return;
    }
    setState(() {
      _transcription = '';
      _parsedTask = null;
      _isListening = true;
    });
    await _stt.listen(
      onResult: (result) {
        setState(() {
          _transcription = result.recognizedWords;
          if (result.finalResult) {
            _parsedTask = TaskParser.parse(_transcription);
          }
        });
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _isListening = false);
    _onListeningDone();
  }

  void _onListeningDone() {
    if (_transcription.isNotEmpty && _parsedTask == null) {
      setState(() => _parsedTask = TaskParser.parse(_transcription));
    }
  }

  Future<void> _scheduleReminder() async {
    if (_parsedTask == null) return;

    final now = DateTime.now();
    final notifId = now.millisecondsSinceEpoch % 2147483647;

    final reminder = TaskReminder(
      id: now.millisecondsSinceEpoch.toString(),
      originalText: _transcription,
      taskText: _parsedTask!.taskText,
      reminderTime: _parsedTask!.scheduledTime,
      createdAt: now,
      notificationId: notifId,
    );

    final reminders = await _reminderStorage.load();
    reminders.insert(0, reminder);
    await _reminderStorage.save(reminders);

    // Schedule via native AlarmManager.setAlarmClock().
    // Fires even when app is killed or device is in Doze mode.
    // No special permissions required.
    await AlarmSchedulerService.schedule(
      id: notifId,
      scheduledTime: _parsedTask!.scheduledTime,
      reminderId: reminder.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Reminder set for ${_formatTime(_parsedTask!.scheduledTime)}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  String _formatTime(DateTime dt) {
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Task Reminder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hint card
            Card(
              color:
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 20),
                    SizedBox(height: 6),
                    Text(
                      'Say something like:\n"I have a task to email my HR at 3:00 PM"',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Mic button
            Center(
              child: GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.withOpacity(0.12)
                        : Colors.indigo.withOpacity(0.1),
                    border: Border.all(
                      color: _isListening ? Colors.red : Colors.indigo,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 54,
                    color: _isListening ? Colors.red : Colors.indigo,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _isListening ? 'Listening... tap to stop' : 'Tap mic to speak',
                style: TextStyle(
                  color: _isListening ? Colors.red : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Transcription area
            if (_transcription.isNotEmpty || _isListening) ...[
              const Text(
                'Transcription',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _transcription.isEmpty ? 'Listening...' : _transcription,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Extracted result
            if (_parsedTask != null) ...[
              const Text(
                'Extracted Task',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.green.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.task_alt,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _parsedTask!.taskText,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Reminder at ${_formatTime(_parsedTask!.scheduledTime)}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _scheduleReminder,
                icon: const Icon(Icons.alarm_add),
                label: const Text('Set Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
            ] else if (_transcription.isNotEmpty && !_isListening) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No time detected. Try saying "at 3:00 PM" or "at 12 AM".',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
