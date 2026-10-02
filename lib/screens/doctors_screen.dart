import 'package:flutter/material.dart';
import '../models/specialty.dart';
import 'slots_screen.dart';

class DoctorsScreen extends StatelessWidget {
  final Specialty specialty;

  const DoctorsScreen({super.key, required this.specialty});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(specialty.title),
      ),
      body: ListView.builder(
        itemCount: specialty.doctors.length,
        itemBuilder: (context, index) {
          final doctor = specialty.doctors[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(doctor.hospitalName),
              trailing: const Icon(Icons.calendar_month),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SlotsScreen(doctor: doctor),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}