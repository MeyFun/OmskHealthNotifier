import 'package:flutter/material.dart';
import '../models/hospital.dart';
import '../models/specialty.dart';
// Потребуется на следующем шаге

class HospitalsScreen extends StatefulWidget {
  final Specialty specialty;

  const HospitalsScreen({
    super.key,
    required this.specialty,
  });

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  bool _isLoading = false;
  List<Hospital> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    setState(() => _isLoading = true);

    // Заглушка: имитация загрузки списка поликлиник для выбранной специальности
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _hospitals = [
        Hospital(
          id: '1',
          name: 'ГБ №1 им. Кабанова',
          address: 'ул. Перелета, 7',
        ),
        Hospital(
          id: '2',
          name: 'Городская поликлиника №4',
          address: 'ул. Академика Павлова, 29',
        ),
        Hospital(
          id: '3',
          name: 'МСЧ №9',
          address: 'ул. 5-я Кордная, 73',
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('2. Поликлиники (${widget.specialty.title})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _hospitals.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final hospital = _hospitals[index];
                return ListTile(
                  title: Text(
                    hospital.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(hospital.address),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Переход к выбору врача в этой поликлинике
                    /* Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorsScreen(
                          specialty: widget.specialty,
                          hospital: hospital,
                        ),
                      ),
                    ); */
                  },
                );
              },
            ),
    );
  }
}