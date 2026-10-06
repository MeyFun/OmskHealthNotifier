import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../services/slot_monitoring_service.dart';
import 'slots_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with WidgetsBindingObserver {
  final FavoritesService _favoritesService = FavoritesService();
  late Future<List<Map<String, String>>> _subscriptionsFuture;
  late Future<bool> _serviceStatusFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSubscriptions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_loadSubscriptions);
    }
  }

  void _loadSubscriptions() {
    _subscriptionsFuture = _favoritesService.getSlotSubscriptions();
    _serviceStatusFuture = SlotMonitoringService.isRunning();
  }

  Future<void> _removeSubscription(String scheduleUrl) async {
    try {
      await _favoritesService.removeSlotSubscription(scheduleUrl);
      await SlotMonitoringService.syncWithSubscriptions();
      if (!mounted) return;
      setState(_loadSubscriptions);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Отслеживание остановлено')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось остановить отслеживание: $e')),
      );
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Разрешить фоновую работу?'),
        content: const Text(
          'Чтобы Android реже приостанавливал проверку талонов, можно '
          'исключить приложение из оптимизации батареи. Это увеличит '
          'расход батареи. Разрешение необязательно, и производитель '
          'телефона всё равно может ограничивать фоновые процессы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Не сейчас'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (shouldRequest != true) return;

    try {
      final granted =
          await SlotMonitoringService.requestBatteryOptimizationExemption();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Оптимизация батареи отключена для приложения'
                : 'Разрешение не предоставлено',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось запросить разрешение: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личный кабинет'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_loadSubscriptions),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonitoringCard(),
          Expanded(
            child: FutureBuilder<List<Map<String, String>>>(
              future: _subscriptionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Не удалось загрузить очередь: ${snapshot.error}',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(_loadSubscriptions),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final subscriptions = snapshot.data ?? [];
                if (subscriptions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Вы пока не отслеживаете талоны.\n'
                        'Откройте врача и нажмите «Встать в очередь».',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: subscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = subscriptions[index];
                    final scheduleUrl = subscription['scheduleUrl']!;
                    final doctorName = subscription['doctorName'] ?? 'Врач';
                    final hospitalName =
                        subscription['hospitalName'] ?? 'Больница';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: Text(doctorName),
                        subtitle: Text(
                          '$hospitalName\nОжидаем появления талонов',
                        ),
                        isThreeLine: true,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => SlotsScreen(
                                doctorName: doctorName,
                                hospitalName: hospitalName,
                                scheduleUrl: scheduleUrl,
                              ),
                            ),
                          );
                          if (mounted) setState(_loadSubscriptions);
                        },
                        trailing: IconButton(
                          tooltip: 'Остановить отслеживание',
                          icon: const Icon(Icons.notifications_off_outlined),
                          onPressed: () => _removeSubscription(scheduleUrl),
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

  Widget _buildMonitoringCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<bool>(
              future: _serviceStatusFuture,
              builder: (context, snapshot) {
                final isRunning = snapshot.data ?? false;
                return Row(
                  children: [
                    Icon(
                      isRunning ? Icons.sync : Icons.sync_disabled,
                      color: isRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Проверяем состояние службы…'
                            : isRunning
                            ? 'Фоновое отслеживание работает'
                            : 'Фоновое отслеживание остановлено',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'При активной очереди талоны проверяются примерно раз в 5 минут.',
            ),
            TextButton.icon(
              onPressed: _requestBatteryOptimizationExemption,
              icon: const Icon(Icons.battery_saver_outlined),
              label: const Text('Настроить работу без ограничений батареи'),
            ),
          ],
        ),
      ),
    );
  }
}
