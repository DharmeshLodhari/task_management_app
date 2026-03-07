import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../models/task_reminder.dart';
import '../services/storage_service.dart';
import '../services/reminder_storage_service.dart';
import '../services/alarm_scheduler_service.dart';
import 'recorder_screen.dart';
import 'task_reminder_screen.dart';
import 'alarm_screen.dart';
import 'manual_reminder_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// Non-null when the app was cold-launched by tapping an alarm notification
  /// (i.e. the app was previously killed).
  final String? launchReminderId;

  const DashboardScreen({super.key, this.launchReminderId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _storage = StorageService();
  final _reminderStorage = ReminderStorageService();
  final _player = AudioPlayer();

  Timer? _foregroundAlarmTimer;

  List<Recording> _recordings = [];
  List<TaskReminder> _reminders = [];
  String? _playingId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  /// Called when the app returns to foreground after being backgrounded.
  /// onNewIntent() (Java) stored the reminderId in pendingAlarmReminderId;
  /// we read it here — same mechanism as the killed-app cold-launch path.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final reminderId = await AlarmSchedulerService.checkPendingAlarm();
      if (reminderId != null && mounted) {
        _showAlarmForId(reminderId);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundAlarmTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final recordings = await _storage.load();
    final reminders = await _reminderStorage.load();
    if (mounted) {
      setState(() {
        _recordings = recordings;
        _reminders = reminders;
        _isLoading = false;
      });

      // Killed-app scenario: AlarmManager cold-launched us with a reminder ID.
      if (widget.launchReminderId != null) {
        _showAlarmForId(widget.launchReminderId!);
      }

      _scheduleForegroundAlarm();
    }
  }

  /// Foreground-only: sets a Dart Timer so the AlarmScreen appears immediately
  /// without a notification banner when the app is visible. Cancels the native
  /// alarm first so AlarmReceiver never fires for this reminder.
  void _scheduleForegroundAlarm() {
    _foregroundAlarmTimer?.cancel();
    final now = DateTime.now();
    final upcoming = _reminders
        .where((r) => r.reminderTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
    if (upcoming.isEmpty) return;

    final next = upcoming.first;
    _foregroundAlarmTimer = Timer(next.reminderTime.difference(now), () {
      _scheduleForegroundAlarm(); // arm next one
      if (!mounted) return;

      // Only handle here if the app is actually visible.
      // If backgrounded/killed, do NOT cancel — AlarmReceiver must fire.
      final isForegrounded =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!isForegrounded) return;

      AlarmSchedulerService.cancel(next.notificationId);
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AlarmScreen(reminder: next),
        ),
      );
    });
  }

  /// Find the reminder by ID and push AlarmScreen.
  void _showAlarmForId(String reminderId) {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AlarmScreen(reminder: _reminders[idx]),
          ),
        );
      }
    });
  }

  // ── Recordings ──────────────────────────────────────────

  Future<void> _togglePlay(Recording recording) async {
    if (_playingId == recording.id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.stop();
      await _player.play(DeviceFileSource(recording.filePath));
      setState(() => _playingId = recording.id);
    }
  }

  Future<void> _deleteRecording(Recording recording) async {
    final confirmed = await _confirmDelete(recording.name);
    if (!confirmed) return;

    if (_playingId == recording.id) {
      await _player.stop();
      setState(() => _playingId = null);
    }
    final file = File(recording.filePath);
    if (file.existsSync()) file.deleteSync();
    _recordings.removeWhere((r) => r.id == recording.id);
    await _storage.save(_recordings);
    if (mounted) setState(() {});
  }

  // ── Reminders ────────────────────────────────────────────

  Future<void> _deleteReminder(TaskReminder reminder) async {
    final confirmed = await _confirmDelete(reminder.taskText);
    if (!confirmed) return;

    await AlarmSchedulerService.cancel(reminder.notificationId);
    _reminders.removeWhere((r) => r.id == reminder.id);
    await _reminderStorage.save(_reminders);
    if (mounted) setState(() {});
  }

  // ── Helpers ──────────────────────────────────────────────

  Future<bool> _confirmDelete(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF000080),
                child: Icon(Icons.alarm_add, color: Colors.white),
              ),
              title: const Text('Record Task Reminder'),
              subtitle: const Text('Schedule a reminder from voice'),
              onTap: () {
                Navigator.pop(ctx);
                _goToScreen(const TaskReminderScreen());
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF000080),
                child: Icon(Icons.edit_calendar, color: Colors.white),
              ),
              title: const Text('Manual Reminder'),
              subtitle: const Text('Type a task and pick a time'),
              onTap: () {
                Navigator.pop(ctx);
                _goToScreen(const ManualReminderScreen());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _goToScreen(Widget screen) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result == true) _loadAll();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Reminder'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildRemindersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecordingsList() {
    if (_recordings.isEmpty) {
      return const _EmptyState(
        icon: Icons.mic_none,
        message: 'No recordings yet',
        hint: 'Tap + to record audio',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recordings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rec = _recordings[index];
        final isPlaying = _playingId == rec.id;
        return Card(
          elevation: 2,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.mic),
            ),
            title: Text(rec.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_formatDate(rec.createdAt)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  color: isPlaying ? Colors.red : const Color(0xFF000080),
                  iconSize: 36,
                  onPressed: () => _togglePlay(rec),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.grey,
                  onPressed: () => _deleteRecording(rec),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildUpcomingSummaryCard() {
    final now = DateTime.now();
    final upcoming = _reminders
        .where((r) => r.reminderTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
    if (upcoming.isEmpty) return null;

    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = today.add(const Duration(days: 1));
    final todayReminders = upcoming
        .where((r) => r.reminderTime.isBefore(todayEnd))
        .take(3)
        .toList();

    final next = upcoming.first;
    final isSoon = next.reminderTime.difference(now) <=
        const Duration(minutes: 60);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upcoming, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Upcoming reminders',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (isSoon)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF000080),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatTime(next.reminderTime),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              next.taskText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            if (todayReminders.length > 1) ...[
              const SizedBox(height: 8),
              for (final r in todayReminders.skip(1))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_formatTime(r.reminderTime)} · ${r.taskText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
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

  Widget _buildRemindersList() {
    if (_reminders.isEmpty) {
      return const _EmptyState(
        icon: Icons.alarm_off,
        message: 'No reminders yet',
        hint: 'Tap + to record a task reminder',
      );
    }
    final summary = _buildUpcomingSummaryCard();
    final items = _reminders;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 3
            : width >= 600
                ? 2
                : 2;

        return CustomScrollView(
          slivers: [
            if (summary != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: summary,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final rem = items[index];
                    final isPast = rem.reminderTime.isBefore(DateTime.now());
                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPast
                                      ? Colors.grey.shade200
                                      : const Color(0xFF000080)
                                          .withOpacity(0.1),
                                  child: Icon(
                                    isPast
                                        ? Icons.alarm_off
                                        : Icons.alarm,
                                    size: 18,
                                    color: isPast
                                        ? Colors.grey
                                        : const Color(0xFF000080),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  color: Colors.grey,
                                  onPressed: () => _deleteReminder(rem),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rem.taskText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: isPast
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isPast ? Colors.grey : null,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 13,
                                  color: isPast
                                      ? Colors.grey
                                      : const Color(0xFF000080),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_formatTime(rem.reminderTime)} · ${_formatDate(rem.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isPast
                                          ? Colors.grey
                                          : const Color(0xFF000080),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (rem.originalText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"${rem.originalText}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
