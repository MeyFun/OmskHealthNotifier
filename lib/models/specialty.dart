class Specialty {
  final String id;
  final String title;
  final String url;

  Specialty({
    required this.id,
    required this.title,
    required this.url,
  });

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}