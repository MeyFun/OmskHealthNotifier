enum SlotType {
  free,
  videochatFree,
  busy,
}

class TicketSlot {
  final String id;
  final String time;
  final String date;
  final SlotType type;
  final String? rawRel;

  TicketSlot({
    required this.id,
    required this.time,
    required this.date,
    required this.type,
    this.rawRel,
  });

  factory TicketSlot.fromJson(Map<String, dynamic> json) {
    String rawType = json['type'] ?? 'free';
    SlotType parsedType;

    if (rawType == 'videochatFree') {
      parsedType = SlotType.videochatFree;
    } else if (rawType == 'busy') {
      parsedType = SlotType.busy;
    } else {
      parsedType = SlotType.free;
    }

    return TicketSlot(
      id: json['id']?.toString() ?? '',
      time: json['time'] ?? '',
      date: json['date'] ?? '',
      type: parsedType,
      rawRel: json['rawRel']?.toString() ?? '',
    );
  }
}