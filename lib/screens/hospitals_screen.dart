import 'package:flutter/material.dart';
import '../repositories/health_repository.dart';
import '../models/hospital.dart';
import 'slots_screen.dart';

class HospitalsScreen extends StatefulWidget {
  final String specialtyTitle;
  final String specialtyUrl;

  const HospitalsScreen({
    super.key,
    required this.specialtyTitle,
    required this.specialtyUrl,
  });

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  final HealthRepository _repository = HealthRepository();
  late Future<List<Hospital>> _hospitalsFuture;

  @override
  void initState() {
    super.initState();
    _hospitalsFuture = _repository.getHospitalsWithDoctors(widget.specialtyUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.specialtyTitle),
      ),
      body: FutureBuilder<List<Hospital>>(
        future: _hospitalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          final hospitals = snapshot.data ?? [];

          if (hospitals.isEmpty) {
            return const Center(child: Text('Врачи по данной специальности не найдены'));
          }

          return ListView.builder(
            itemCount: hospitals.length,
            itemBuilder: (context, index) {
              final hospital = hospitals[index];
              return ExpansionTile(
                title: Text(
                  hospital.hospitalName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Врачей: ${hospital.doctors.length}'),
                children: hospital.doctors.map((doctor) {
                  return ListTile(
                    title: Text(doctor.name),
                    leading: const Icon(Icons.person_outline),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SlotsScreen(
                            doctorName: doctor.name,
                            hospitalName: hospital.hospitalName,
                            scheduleUrl: doctor.scheduleUrl,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}