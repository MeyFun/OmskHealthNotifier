class Doctor {
  final String id;
  final String name;
  final String hospitalId;
  final String specialtyId;

  Doctor({
    required this.id,
    required this.name,
    required this.hospitalId,
    required this.specialtyId,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'].toString(),
      name: json['name'] as String,
      hospitalId: json['hospital_id'].toString(),
      specialtyId: json['specialty_id'].toString(),
    );
  }
}