import 'package:flutter/material.dart';
import '../models/specialty.dart';
import 'hospitals_screen.dart';

class SpecialtiesScreen extends StatefulWidget {
  const SpecialtiesScreen({Key? key}) : super(key: key);

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen> {
  bool _isLoading = false;
  List<Specialty> _specialties = [];

  @override
  void initState() {
    super.initState();
    _fetchSpecialties();
  }

  Future<void> _fetchSpecialties() async {
    setState(() => _isLoading = true);

    // Заглушка: Позже заменим на реальный сетевой запрос к серверу
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _specialties = [
        Specialty(id: '1', name: 'Терапевт'),
        Specialty(id: '2', name: 'Офтальмолог'),
        Specialty(id: '3', name: 'Хирург'),
        Specialty(id: '4', name: 'Невролог'),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1. Выберите специальность'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _specialties.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final specialty = _specialties[index];
                return ListTile(
                  title: Text(
                    specialty.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HospitalsScreen(specialty: specialty),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}