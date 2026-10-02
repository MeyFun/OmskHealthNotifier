enum SlotType {
  free,
  videochatFree,
  busy,
}

class TicketSlot {
  final String id;
  final DateTime dateTime;
  final String time;
  final String date;
  final SlotType type;

  TicketSlot({
    required this.id,
    required this.dateTime,
    required this.time,
    required this.date,
    required this.type,
  });
}