import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/specialty.dart';
import '../models/doctor.dart';
import 'doctors_screen.dart';

class SpecialtiesScreen extends StatefulWidget {
  const SpecialtiesScreen({super.key});

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen> {
  late Future<List<Specialty>> _specialtiesFuture;

  // Временная тестовая ссылка на поликлинику (можно менять или выбирать из списка LPU)
  final String _hospitalUrl = 'https://omskzdrav.ru/service/schedule/550101000044127/timetable';

  @override
  void initState() {
    super.initState();
    _specialtiesFuture = _fetchSpecialties();
  }

  Future<List<Specialty>> _fetchSpecialties() async {
    final apiUrl = Uri.parse('http://10.0.2.2:8000/api/specialties?url=$_hospitalUrl');

    try {
      final response = await http.get(apiUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['specialties'] ?? [];

        return list.map((specJson) {
          final List docsJson = specJson['doctors'] ?? [];
          final doctors = docsJson.map((d) => Doctor(
            id: d['id'] ?? '',
            name: d['name'] ?? 'Врач',
            specialty: specJson['title'] ?? '',
            hospitalName: 'ГБ №1 им. Кабанова',
            scheduleUrl: d['schedule_url'] ?? '',
          )).toList();

          return Specialty(
            id: specJson['id'] ?? '',
            title: specJson['title'] ?? 'Специальность',
            doctors: doctors,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Ошибка сети: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор специальности'),
      ),
      body: FutureBuilder<List<Specialty>>(
        future: _specialtiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Специальности не найдены'));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final spec = list[index];
              return ListTile(
                title: Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Врачей: ${spec.doctors.length}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorsScreen(specialty: spec),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}