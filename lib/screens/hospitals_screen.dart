import 'package:flutter/material.dart';
import '../models/hospital.dart';
import '../models/doctor.dart';
import '../models/specialty.dart';
import '../repositories/health_repository.dart';
import '../services/favorites_service.dart';
import 'slots_screen.dart';

class HospitalsScreen extends StatefulWidget {
  final Specialty specialty;

  const HospitalsScreen({super.key, required this.specialty});

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  final HealthRepository _repository = HealthRepository();
  final FavoritesService _favoritesService = FavoritesService();
  final TextEditingController _searchController = TextEditingController();

  List<Hospital> _allHospitals = [];
  Set<String> _favoriteHospitals = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final list =
          await _repository.getHospitalsWithDoctors(widget.specialty.url);
      final favorites = await _favoritesService.getFavoriteHospitals();
      setState(() {
        _allHospitals = list;
        _favoriteHospitals = favorites.toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки больниц: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  Future<void> _toggleFavorite(String name) async {
    await _favoritesService.toggleFavoriteHospital(name);
    setState(() {
      if (_favoriteHospitals.contains(name)) {
        _favoriteHospitals.remove(name);
      } else {
        _favoriteHospitals.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.specialty.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по врачу...',
                prefixIcon: const Icon(Icons.person_search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_allHospitals.isEmpty) {
      return const Center(child: Text('Больницы не найдены'));
    }

    List<HospitalDisplayData> displayList = [];

    for (var hospital in _allHospitals) {
      List<Doctor> matchingDoctors = [];
      List<Doctor> otherDoctors = [];

      for (var doctor in hospital.doctors) {
        final matchesName =
            doctor.name.toLowerCase().contains(_searchQuery);

        if (_searchQuery.isNotEmpty && matchesName) {
          matchingDoctors.add(doctor);
        } else {
          otherDoctors.add(doctor);
        }
      }

      final hasMatches = matchingDoctors.isNotEmpty;

      if (_searchQuery.isEmpty || hasMatches) {
        displayList.add(HospitalDisplayData(
          hospital: hospital,
          sortedDoctors: [...matchingDoctors, ...otherDoctors],
          hasMatches: hasMatches,
          isFavorite: _favoriteHospitals.contains(hospital.hospitalName),
        ));
      }
    }

    // --- СОРТИРОВКА БОЛЬНИЦ ---
    // 1. При поиске: сначала больницы с совпавшими врачами.
    // 2. Затем (или при отсутствии поиска): избранные больницы.
    displayList.sort((a, b) {
      if (_searchQuery.isNotEmpty) {
        if (a.hasMatches && !b.hasMatches) return -1;
        if (!a.hasMatches && b.hasMatches) return 1;
      }
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });

    if (displayList.isEmpty) {
      return const Center(child: Text('Врачи по вашему запросу не найдены'));
    }

    return ListView.builder(
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final item = displayList[index];
        final hospital = item.hospital;
        final isExpanded = _searchQuery.isNotEmpty && item.hasMatches;

        return Card(
          key: ValueKey('${hospital.hospitalName}_$_searchQuery'),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            initiallyExpanded: isExpanded,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    hospital.hospitalName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.hasMatches
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                    color: item.isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(hospital.hospitalName),
                ),
              ],
            ),
            children: item.sortedDoctors.map((doctor) {
              final isDoctorMatched = _searchQuery.isNotEmpty &&
                  doctor.name.toLowerCase().contains(_searchQuery);

              return Container(
                color: isDoctorMatched
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                    : null,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  title: Text(
                    doctor.name,
                    style: TextStyle(
                      fontWeight:
                          isDoctorMatched ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_month, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SlotsScreen(
                          hospitalName: hospital.hospitalName,
                          doctorName: doctor.name,
                          scheduleUrl: doctor.scheduleUrl,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class HospitalDisplayData {
  final Hospital hospital;
  final List<Doctor> sortedDoctors;
  final bool hasMatches;
  final bool isFavorite;

  HospitalDisplayData({
    required this.hospital,
    required this.sortedDoctors,
    required this.hasMatches,
    required this.isFavorite,
  });
}