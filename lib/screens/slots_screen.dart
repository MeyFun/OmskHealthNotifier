import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/ticket_slot.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SlotsScreen extends StatefulWidget {
  final Doctor doctor;

  const SlotsScreen({super.key, required this.doctor});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  bool _isMonitoring = false;
  late Future<List<TicketSlot>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _fetchSlots();
  }

  Future<List<TicketSlot>> _fetchSlots() async {
  // Вытаскиваем URL из объекта doctor (или если пусто — берём дефолтный)
  final targetUrl = widget.doctor.scheduleUrl.isNotEmpty
      ? widget.doctor.scheduleUrl
      : 'https://omskzdrav.ru/service/schedule/550101000044127/timetable';

  final apiUrl = Uri.parse('http://10.0.2.2:8000/api/slots?url=$targetUrl');

  try {
    // Передаем apiUrl здесь:
    final response = await http.get(apiUrl);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List slotsJson = data['slots'] ?? [];

      return slotsJson.map((json) {
        SlotType type = SlotType.free;
        if (json['type'] == 'videochatFree') {
          type = SlotType.videochatFree;
        }

        return TicketSlot(
          id: json['id'] ?? '',
          dateTime: DateTime.now(),
          time: json['time'] ?? '',
          date: json['date'] ?? '',
          type: type,
        );
      }).toList();
    }
  } catch (e) {
    debugPrint('Ошибка загрузки слотов: $e');
  }
  return [];
}

  Color _getSlotColor(SlotType type) {
    switch (type) {
      case SlotType.free:
        return Colors.green;
      case SlotType.videochatFree:
        return Colors.blue;
      case SlotType.busy:
        return Colors.grey;
    }
  }

  String _getSlotText(SlotType type) {
    switch (type) {
      case SlotType.free:
        return 'Свободно';
      case SlotType.videochatFree:
        return 'Телемедицина';
      case SlotType.busy:
        return 'Занято';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctor.name),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctor.hospitalName,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isMonitoring
                            ? 'Уведомления включены'
                            : 'Уведомления выключены',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring ? Colors.green : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isMonitoring,
                  onChanged: (val) {
                    setState(() => _isMonitoring = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Мониторинг врача включен'
                              : 'Мониторинг отключен',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TicketSlot>>(
              future: _slotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final slots = snapshot.data ?? [];
                if (slots.isEmpty) {
                  return const Center(child: Text('Свободных слотов нет'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final isAvailable = slot.type != SlotType.busy;
                    final color = _getSlotColor(slot.type);

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(10),
                        color: color.withValues(alpha: 0.05),
                      ),
                      child: InkWell(
                        onTap: isAvailable ? () {} : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${slot.date} — ${slot.time}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getSlotText(slot.type),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}