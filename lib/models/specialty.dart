import 'doctor.dart';

class Specialty {
  final String id;
  final String title;
  final List<Doctor> doctors;

  Specialty({
    required this.id,
    required this.title,
    required this.doctors,
  });
}