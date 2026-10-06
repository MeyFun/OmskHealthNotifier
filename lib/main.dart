import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/specialties_screen.dart';
import 'services/notification_service.dart';
import 'services/slot_monitoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  SlotMonitoringService.initialize();

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Ошибка инициализации уведомлений: $e');
  }

  try {
    await NotificationService.initWorkmanager();
  } catch (e) {
    debugPrint('Ошибка инициализации Workmanager: $e');
  }

  try {
    await SlotMonitoringService.syncWithSubscriptions();
  } catch (e) {
    debugPrint('Ошибка восстановления фонового отслеживания: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Омск Здравоохранение',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SpecialtiesScreen(),
    );
  }
}
