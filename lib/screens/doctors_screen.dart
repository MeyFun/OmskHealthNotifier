import 'package:flutter/material.dart';

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Врачи')),
      body: const Center(child: Text('Список врачей доступен в блоке больниц')),
    );
  }
}