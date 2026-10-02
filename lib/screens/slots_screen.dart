import 'package:flutter/material.dart';
import '../repositories/health_repository.dart';
import '../models/ticket_slot.dart';

class SlotsScreen extends StatefulWidget {
  final String doctorName;
  final String hospitalName;
  final String scheduleUrl;

  const SlotsScreen({
    super.key,
    required this.doctorName,
    required this.hospitalName,
    required this.scheduleUrl,
  });

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  final HealthRepository _repository = HealthRepository();
  late Future<List<TicketSlot>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _repository.getSlots(widget.scheduleUrl);
  }

  void _refresh() {
    setState(() {
      _slotsFuture = _repository.getSlots(widget.scheduleUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Text(
              widget.hospitalName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TicketSlot>>(
              future: _slotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Ошибка загрузки талонов: ${snapshot.error}'),
                  );
                }

                final slots = snapshot.data ?? [];

                if (slots.isEmpty) {
                  return const Center(
                    child: Text('Свободных талонов к этому врачу нет'),
                  );
                }

                return ListView.builder(
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final isVideo = slot.type == SlotType.videochatFree;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isVideo ? Icons.videocam : Icons.access_time,
                          color: isVideo ? Colors.purple : Colors.green,
                        ),
                        title: Text('Время: ${slot.time}'),
                        subtitle: Text('Дата: ${slot.date}'),
                        trailing: Chip(
                          label: Text(isVideo ? 'Видеочат' : 'Свободно'),
                          backgroundColor: isVideo
                              ? Colors.purple.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
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