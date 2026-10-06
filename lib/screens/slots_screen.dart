import 'package:flutter/material.dart';

import '../repositories/health_repository.dart';
import '../models/ticket_slot.dart';
import '../services/favorites_service.dart';
import '../services/notification_service.dart';
import '../services/slot_monitoring_service.dart';

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

class _SlotsScreenState extends State<SlotsScreen> with WidgetsBindingObserver {
  final HealthRepository _repository = HealthRepository();
  final FavoritesService _favoritesService = FavoritesService();

  late Future<List<TicketSlot>> _slotsFuture;
  bool _isSubscribed = false;
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _slotsFuture = _loadInitialSlots();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<List<TicketSlot>> _loadSlots() async {
    final slots = await _repository.getSlots(widget.scheduleUrl);
    if (slots.isNotEmpty) {
      final isSubscribed = await _favoritesService.isSubscribed(
        widget.scheduleUrl,
      );
      if (isSubscribed) {
        final notified = await NotificationService.maybeShowNotification(
          scheduleUrl: widget.scheduleUrl,
          doctorName: widget.doctorName,
          hospitalName: widget.hospitalName,
          slots: slots,
        );
        if (notified) {
          await _favoritesService.removeSlotSubscription(widget.scheduleUrl);
          await SlotMonitoringService.syncWithSubscriptions();
        }
      }
      await _checkSubscriptionStatus();
    }
    return slots;
  }

  Future<List<TicketSlot>> _loadInitialSlots() async {
    await _checkSubscriptionStatus();
    return _loadSlots();
  }

  // Проверяем, находится ли пользователь уже в очереди
  Future<void> _checkSubscriptionStatus() async {
    final subscribed = await _favoritesService.isSubscribed(widget.scheduleUrl);
    if (mounted) {
      setState(() {
        _isSubscribed = subscribed;
        _isLoadingSubscription = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _checkSubscriptionStatus();
    if (!mounted) return;
    setState(() {
      _slotsFuture = _loadSlots();
    });
  }

  // Метод добавления в фоновый мониторинг
  Future<void> _subscribeToDoctor() async {
    try {
      await _favoritesService.addSlotSubscription(
        scheduleUrl: widget.scheduleUrl,
        doctorName: widget.doctorName,
        hospitalName: widget.hospitalName,
      );
      await NotificationService.resetSlotTracking(widget.scheduleUrl);

      if (!mounted) return;

      setState(() {
        _isSubscribed = true;
      });

      try {
        await SlotMonitoringService.syncWithSubscriptions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Вы добавлены в очередь, но не удалось запустить фоновую службу: $e',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вы встали в очередь к: ${widget.doctorName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при добавлении в отслеживание: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctorName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          // Название больницы
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Text(
              widget.hospitalName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          // 🔔 ДИНАМИЧЕСКАЯ КНОПКА «ОЧЕРЕДЬ»
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubscribed
                      ? Colors.grey.shade400
                      : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  _isSubscribed
                      ? Icons.check_circle_outline
                      : Icons.notifications_active_outlined,
                ),
                label: Text(
                  _isLoadingSubscription
                      ? 'Загрузка...'
                      : (_isSubscribed
                            ? 'Вы уже в очереди'
                            : 'Встать в очередь (Отслеживать)'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Если уже подписаны или идет загрузка, кнопка блокируется (нажатие выключено)
                onPressed: (_isSubscribed || _isLoadingSubscription)
                    ? null
                    : _subscribeToDoctor,
              ),
            ),
          ),

          // Блок со списком талонов
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
                    child: Text(
                      'Свободных талонов сейчас нет.\nНажмите кнопку выше, чтобы отслеживать появление.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                    ),
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
