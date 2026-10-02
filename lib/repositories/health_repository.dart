import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/specialty.dart';
import '../models/hospital.dart';
import '../models/ticket_slot.dart';

class HealthRepository {
  final ApiClient _apiClient;

  HealthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // 1. Получить специальности
  Future<List<Specialty>> getSpecialties() async {
    final data = await _apiClient.get(ApiConstants.specialtiesEndpoint);
    final List list = data['specialties'] ?? [];
    return list.map((json) => Specialty.fromJson(json)).toList();
  }

  // 2. Получить список медучреждений с врачами
  Future<List<Hospital>> getHospitalsWithDoctors(String specialtyUrl) async {
    final data = await _apiClient.get(
      ApiConstants.doctorsEndpoint,
      queryParameters: {'url': specialtyUrl},
    );
    final List list = data['hospitals'] ?? [];
    return list.map((json) => Hospital.fromJson(json)).toList();
  }

  // 3. Получить свободные талоны врача
  Future<List<TicketSlot>> getSlots(String doctorScheduleUrl) async {
    final data = await _apiClient.get(
      ApiConstants.slotsEndpoint,
      queryParameters: {'url': doctorScheduleUrl},
    );
    final List list = data['slots'] ?? [];
    return list.map((json) => TicketSlot.fromJson(json)).toList();
  }
}