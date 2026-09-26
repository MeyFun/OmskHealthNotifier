enum TicketType { offline, online }

class TicketSlot {
  final String id; // Уникальный идентификатор талона (хэш, дата+время+тип)
  final DateTime dateTime;
  final TicketType type;

  TicketSlot({
    required this.id,
    required this.dateTime,
    required this.type,
  });

  factory TicketSlot.fromJson(Map<String, dynamic> json) {
    return TicketSlot(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      type: json['is_online'] == true ? TicketType.online : TicketType.offline,
    );
  }
}