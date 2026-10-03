import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import '../models/specialty.dart';
import '../models/hospital.dart';
import '../models/ticket_slot.dart';

class HealthRepository {
  // Прямая ссылка на сгенерированный файл data.json в репозитории
  static const String _githubDataUrl =
      'https://raw.githubusercontent.com/MeyFun/OmskHealthNotifier/main/data.json';

  // Кэшируем загруженные данные в памяти, чтобы не качать JSON при каждом переходе
  Map<String, dynamic>? _cachedData;

  Future<Map<String, dynamic>> _loadData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    final response = await http.get(Uri.parse(_githubDataUrl));

    if (response.statusCode == 200) {
      _cachedData = jsonDecode(utf8.decode(response.bodyBytes));
      return _cachedData!;
    } else {
      throw Exception('Не удалось загрузить данные с сервера (${response.statusCode})');
    }
  }

  // 1. Получить список всех специальностей
  Future<List<Specialty>> getSpecialties() async {
    final data = await _loadData();
    final List specialtiesList = data['specialties'] ?? [];
    return specialtiesList.map((e) => Specialty.fromJson(e)).toList();
  }

  // 2. Получить больницы и врачей по конкретной специальности
  Future<List<Hospital>> getHospitalsWithDoctors(String specialtyUrl) async {
    final data = await _loadData();
    final List specialtiesList = data['specialties'] ?? [];

    // Ищем нужную специальность по ссылке или ID
    final currentSpec = specialtiesList.firstWhere(
      (e) => e['url'] == specialtyUrl || specialtyUrl.contains(e['id'].toString()),
      orElse: () => null,
    );

    if (currentSpec != null && currentSpec['hospitals'] != null) {
      final List hospitalsList = currentSpec['hospitals'];
      return hospitalsList.map((e) => Hospital.fromJson(e)).toList();
    }

    return [];
  }

  // 3. Запрос свободных талонов конкретного врача (в реальном времени с omskzdrav.ru)
  Future<List<TicketSlot>> getSlots(String scheduleUrl) async {
    try {
      final response = await http.get(
        Uri.parse(scheduleUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return parseSlotsFromHtml(response.body);
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Ошибка загрузки талонов: $e');
      return [];
    }
  }

  List<TicketSlot> parseSlotsFromHtml(String htmlBody) {
    final document = html_parser.parse(htmlBody);
    final List<Map<String, dynamic>> tempSlots = [];

    final cells = document.querySelectorAll('td.free');

    for (var cell in cells) {
      final slotId = cell.attributes['id'] ?? '';
      final classes = cell.attributes['class'] ?? '';
      final relInfo = cell.attributes['rel'] ?? '';

      final timeSpan = cell.querySelector('span.ttg-cell-time');
      final timeText = timeSpan != null ? timeSpan.text.trim() : cell.text.trim();

      String dateText = '';
      if (relInfo.isNotEmpty) {
        dateText = relInfo.contains(' ') ? relInfo.split(' ').first : relInfo;
      }

      final bool isVideo = classes.contains('videochatFree');

      final slot = TicketSlot(
        id: slotId,
        time: timeText,
        date: dateText,
        type: isVideo ? SlotType.videochatFree : SlotType.free,
      );

      tempSlots.add({
        'slot': slot,
        'rawRel': relInfo,
        'date': dateText,
        'time': timeText,
      });
    }

    // --- СОРТИРОВКА ТАЛОНОВ ПО ДАТЕ И ВРЕМЕНИ ---
    tempSlots.sort((a, b) {
      DateTime? dateA = _parseDateTime(
        a['date'] as String?,
        a['time'] as String?,
        a['rawRel'] as String?,
      );
      DateTime? dateB = _parseDateTime(
        b['date'] as String?,
        b['time'] as String?,
        b['rawRel'] as String?,
      );

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });

    return tempSlots.map((e) => e['slot'] as TicketSlot).toList();
  }

  // Вспомогательный метод парсинга даты/времени из разных форматов
  DateTime? _parseDateTime(String? dateStr, String? timeStr, String? rawRel) {
    try {
      // 1. Пробуем распарсить ISO / полный формат из rawRel (например "2026-10-13 10:12:00")
      if (rawRel != null && rawRel.isNotEmpty) {
        final parsed = DateTime.tryParse(rawRel);
        if (parsed != null) return parsed;
      }

      final date = dateStr ?? '';
      final time = timeStr ?? '';

      // 2. Если дата в формате DD.MM.YYYY
      if (date.contains('.')) {
        final parts = date.split('.');
        if (parts.length >= 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          int hour = 0;
          int minute = 0;
          if (time.contains(':')) {
            final tParts = time.split(':');
            hour = int.parse(tParts[0]);
            minute = int.parse(tParts[1]);
          }

          return DateTime(year, month, day, hour, minute);
        }
      } else if (date.contains('-')) {
        // 3. Если дата в формате YYYY-MM-DD
        final parts = date.split('-');
        if (parts.length >= 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);

          int hour = 0;
          int minute = 0;
          if (time.contains(':')) {
            final tParts = time.split(':');
            hour = int.parse(tParts[0]);
            minute = int.parse(tParts[1]);
          }

          return DateTime(year, month, day, hour, minute);
        }
      }
    } catch (e) {
      debugPrint('Ошибка парсинга даты талона: $e');
    }
    return null;
  }
}