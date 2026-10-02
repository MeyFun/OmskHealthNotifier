import 'doctor.dart';

class Hospital {
  final String hospitalName;
  final List<Doctor> doctors;

  Hospital({
    required this.hospitalName,
    required this.doctors,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    final docsList = json['doctors'] as List? ?? [];
    return Hospital(
      hospitalName: json['hospital_name'] ?? 'Медучреждение',
      doctors: docsList.map((d) => Doctor.fromJson(d)).toList(),
    );
  }
}