import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../services/alarm_scheduler_service.dart';

class AlarmScreen extends StatefulWidget {
  final TaskReminder reminder;

  const AlarmScreen({super.key, required this.reminder});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Timer _clockTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start ringing the device's default alarm sound as soon as screen opens.
    AlarmSchedulerService.startAlarmRingtone();
  }

  @override
  void dispose() {
    // Ensure ringtone stops even if screen is dismissed programmatically.
    AlarmSchedulerService.stopAlarmRingtone();
    _pulseController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  String _timeString(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _dateString(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D0D2B), Color(0xFF1A1A3E), Color(0xFF0D0D2B)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── Time display ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: Column(
                    children: [
                      Text(
                        _timeString(_now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 68,
                          fontWeight: FontWeight.w100,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateString(_now),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 15,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Alarm icon + task card ────────────────────
                Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF3949AB).withOpacity(0.2),
                          border: Border.all(
                            color: const Color(0xFF7986CB),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3949AB).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.alarm,
                          size: 56,
                          color: Color(0xFF9FA8DA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'TASK REMINDER',
                      style: TextStyle(
                        color: const Color(0xFF9FA8DA).withOpacity(0.8),
                        fontSize: 12,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Text(
                        widget.reminder.taskText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Close button ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await AlarmSchedulerService.stopAlarmRingtone();
                          if (mounted) Navigator.pop(context);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.15),
                            border:
                                Border.all(color: Colors.red.shade400, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.redAccent,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CLOSE',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
