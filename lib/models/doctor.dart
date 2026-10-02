class Doctor {
  final String id;
  final String name;
  final String scheduleUrl;

  Doctor({
    required this.id,
    required this.name,
    required this.scheduleUrl,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      scheduleUrl: json['schedule_url'] ?? '',
    );
  }
}