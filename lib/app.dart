import 'package:flutter/material.dart';
import 'screens/specialties_screen.dart';

class HealthNotifierApp extends StatelessWidget {
  const HealthNotifierApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'К Врачу — Омск',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SpecialtiesScreen(),
    );
  }
}