class ApiConstants {
  // 10.0.2.2 — адрес ПК при запуске из эмулятора Android
  // Если запускаешь на реальном телефоне через Wi-Fi — укажи IP компьютера, например: 'http://192.168.1.50:8000/api'
  // Если запускаешь на Windows (Desktop) или в браузере — используй 'http://127.0.0.1:8000/api'
  static const String baseUrl = 'http://192.168.1.102:8000/api';

  static const String specialtiesEndpoint = '$baseUrl/specialties';
  static const String doctorsEndpoint = '$baseUrl/doctors';
  static const String slotsEndpoint = '$baseUrl/slots';
}