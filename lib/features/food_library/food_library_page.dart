import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/food_library/food_detail_page.dart';
import 'package:opennutritracker/features/food_library/preset_detail_page.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodLibraryPage extends StatefulWidget {
  const FoodLibraryPage({super.key});

  @override
  State<FoodLibraryPage> createState() => _FoodLibraryPageState();
}

class _FoodLibraryPageState extends State<FoodLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MealEntity> _foods = [];
  List<MealPresetDBO> _presets = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load all unique foods from intake history
    final intakeDataSource = locator<IntakeDataSource>();
    final recentIntakes = await intakeDataSource.getRecentlyAddedIntake(number: 500);
    final foods = recentIntakes
        .map((dbo) => MealEntity.fromMealDBO(dbo.meal))
        .toList();

    // Load local food overrides
    final localFoodDataSource = locator<LocalFoodDataSource>();
    final localFoods = await localFoodDataSource.getAllLocalFoods();
    final localMeals = localFoods.map((dbo) => MealEntity.fromMealDBO(dbo)).toList();

    // Merge, deduplicate by code/name
    final seen = <String>{};
    final allFoods = <MealEntity>[];
    for (final meal in [...localMeals, ...foods]) {
      final key = meal.code ?? meal.name ?? '';
      if (key.isNotEmpty && seen.add(key)) {
        allFoods.add(meal);
      }
    }

    // Load presets
    final presetDataSource = locator<MealPresetDataSource>();
    final presets = await presetDataSource.getAllPresets();

    if (mounted) {
      setState(() {
        _foods = allFoods;
        _presets = presets;
        _isLoading = false;
      });
    }
  }

  List<MealEntity> get _filteredFoods {
    if (_searchQuery.isEmpty) return _foods;
    final q = _searchQuery.toLowerCase();
    return _foods
        .where((f) =>
            (f.name ?? '').toLowerCase().contains(q) ||
            (f.brands ?? '').toLowerCase().contains(q))
        .toList();
  }

  List<MealPresetDBO> get _filteredPresets {
    if (_searchQuery.isEmpty) return _presets;
    final q = _searchQuery.toLowerCase();
    return _presets.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: S.of(context).searchLabel,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              isDense: true,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Foods (${_filteredFoods.length})'),
            Tab(text: 'Presets (${_filteredPresets.length})'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFoodsList(),
                    _buildPresetsList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFoodsList() {
    final foods = _filteredFoods;
    if (foods.isEmpty) {
      return Center(
        child: Text('No foods yet',
            style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        final kcal = food.nutriments.energyKcal100;
        return ListTile(
          leading: Icon(
            food.source == MealSourceEntity.ai
                ? Icons.auto_awesome
                : food.source == MealSourceEntity.off
                    ? Icons.qr_code
                    : Icons.restaurant,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(food.name ?? '?'),
          subtitle: Text(
              '${kcal?.toInt() ?? '?'} kcal/100g${food.brands != null ? ' · ${food.brands}' : ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodDetailPage(food: food),
              ),
            );
            _loadData(); // Refresh in case something changed
          },
        );
      },
    );
  }

  Widget _buildPresetsList() {
    final presets = _filteredPresets;
    if (presets.isEmpty) {
      return Center(
        child: Text('No presets yet',
            style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return ListView.builder(
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final totalKcal = preset.items.fold<double>(0, (sum, item) {
          final meal = MealEntity.fromMealDBO(item.meal);
          return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
        });
        return ListTile(
          leading: Icon(Icons.playlist_play,
              color: Theme.of(context).colorScheme.primary),
          title: Text(preset.name),
          subtitle: Text(
              '${preset.items.length} items · ${totalKcal.toInt()} ${S.of(context).kcalLabel}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PresetDetailPage(preset: preset),
              ),
            );
            _loadData();
          },
        );
      },
    );
  }
}
