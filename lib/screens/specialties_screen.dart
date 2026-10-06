import 'package:flutter/material.dart';
import '../models/specialty.dart';
import '../repositories/health_repository.dart';
import '../services/favorites_service.dart';
import 'account_screen.dart';
import 'hospitals_screen.dart';

class SpecialtiesScreen extends StatefulWidget {
  const SpecialtiesScreen({super.key});

  @override
  State<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends State<SpecialtiesScreen> {
  final HealthRepository _repository = HealthRepository();
  final FavoritesService _favoritesService = FavoritesService();
  final TextEditingController _searchController = TextEditingController();

  List<Specialty> _allSpecialties = [];
  Set<String> _favoriteTitles = {};
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
      final list = await _repository.getSpecialties();
      final favorites = await _favoritesService.getFavoriteSpecialties();
      setState(() {
        _allSpecialties = list;
        _favoriteTitles = favorites.toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки данных: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  Future<void> _toggleFavorite(String title) async {
    await _favoritesService.toggleFavoriteSpecialty(title);
    setState(() {
      if (_favoriteTitles.contains(title)) {
        _favoriteTitles.remove(title);
      } else {
        _favoriteTitles.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Специальности'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Личный кабинет',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const AccountScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск специальности...',
                prefixIcon: const Icon(Icons.search),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadData();
                },
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    // --- СОРТИРОВКА И ФИЛЬТРАЦИЯ ---
    // При поиске: совпадения вверху, внутри совпадений — избранное выше.
    // Без поиска: сначала все избранные, затем остальные.
    List<Specialty> sortedList = List.from(_allSpecialties);

    if (_searchQuery.isNotEmpty) {
      sortedList = sortedList.where((spec) {
        return spec.title.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    sortedList.sort((a, b) {
      final isFavA = _favoriteTitles.contains(a.title);
      final isFavB = _favoriteTitles.contains(b.title);

      if (isFavA && !isFavB) return -1;
      if (!isFavA && isFavB) return 1;
      return 0;
    });

    if (sortedList.isEmpty) {
      return const Center(
        child: Text('Специальности не найдены'),
      );
    }

    return ListView.builder(
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final specialty = sortedList[index];
        final isFavorite = _favoriteTitles.contains(specialty.title);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(
              specialty.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(specialty.title),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HospitalsScreen(specialty: specialty),
                ),
              );
            },
          ),
        );
      },
    );
  }
}