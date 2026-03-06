import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'services/alarm_scheduler_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Request permissions + check if launched by an alarm while killed.
  final launchReminderId = await AlarmSchedulerService.init();
  runApp(MyApp(launchReminderId: launchReminderId));
}

class MyApp extends StatelessWidget {
  final String? launchReminderId;

  const MyApp({super.key, this.launchReminderId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Reminder',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: DashboardScreen(launchReminderId: launchReminderId),
    );
  }
}
