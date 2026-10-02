import 'package:flutter/material.dart';
import '../repositories/health_repository.dart';
import '../models/specialty.dart';
import 'hospitals_screen.dart';

class SpecialtiesScreen extends StatefulWidget {
  const SpecialtiesScreen({super.key});

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen> {
  final HealthRepository _repository = HealthRepository();
  late Future<List<Specialty>> _specialtiesFuture;

  @override
  void initState() {
    super.initState();
    _specialtiesFuture = _repository.getSpecialties();
  }

  void _refresh() {
    setState(() {
      _specialtiesFuture = _repository.getSpecialties();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Специальности'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Specialty>>(
        future: _specialtiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ошибка: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final specialties = snapshot.data ?? [];

          if (specialties.isEmpty) {
            return const Center(child: Text('Специальности не найдены'));
          }

          return ListView.builder(
            itemCount: specialties.length,
            itemBuilder: (context, index) {
              final specialty = specialties[index];
              return ListTile(
                title: Text(specialty.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HospitalsScreen(
                        specialtyTitle: specialty.title,
                        specialtyUrl: specialty.url,
                      ),
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