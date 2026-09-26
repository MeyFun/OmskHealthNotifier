class Hospital {
  final String id;
  final String name;
  final String address;

  Hospital({
    required this.id,
    required this.name,
    required this.address,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'].toString(),
      name: json['name'] as String,
      address: json['address'] ?? '',
    );
  }
}