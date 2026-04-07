import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_multiplier_dialog.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/features/food_library/food_detail_page.dart';
import 'package:opennutritracker/features/food_library/meal_builder_page.dart';
import 'package:opennutritracker/features/food_library/preset_detail_page.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodLibraryPage extends StatefulWidget {
  const FoodLibraryPage({super.key});

  @override
  State<FoodLibraryPage> createState() => _FoodLibraryPageState();
}

class _FoodLibraryPageState extends State<FoodLibraryPage>
    with SingleTickerProviderStateMixin {
  static const _creationMealType = AddMealType.breakfastType;
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
    final recentIntakes =
        await intakeDataSource.getRecentlyAddedIntake(number: 500);
    final allIntakes = await intakeDataSource.getAllIntakes();
    final foods =
        recentIntakes.map((dbo) => MealEntity.fromMealDBO(dbo.meal)).toList();

    // Load local food overrides
    final localFoodDataSource = locator<LocalFoodDataSource>();
    final localFoods = await localFoodDataSource.getAllFoodRecords();
    final localMeals = localFoods
        .map((record) => MealEntity.fromLocalFoodRecord(record))
        .toList();

    // Merge, deduplicate by code/name
    final seen = <String>{};
    final allFoods = <MealEntity>[];
    for (final meal in [...localMeals, ...foods]) {
      final key = _libraryKey(meal);
      if (key.isNotEmpty && seen.add(key)) {
        allFoods.add(meal);
      }
    }

    // Load presets
    final presetDataSource = locator<MealPresetDataSource>();
    final presets = await presetDataSource.getAllPresets();
    final latestUseByPresetName = <String, DateTime>{};

    for (final intake in allIntakes) {
      final groupName = intake.groupName?.trim();
      if (groupName == null || groupName.isEmpty) {
        continue;
      }

      final baseName = parseMealGroupName(groupName).baseName.toLowerCase();
      final previousUse = latestUseByPresetName[baseName];
      if (previousUse == null || intake.dateTime.isAfter(previousUse)) {
        latestUseByPresetName[baseName] = intake.dateTime;
      }
    }

    final sortedPresets = List<MealPresetDBO>.from(presets)
      ..sort((a, b) {
        final aUsed = latestUseByPresetName[a.name.toLowerCase()];
        final bUsed = latestUseByPresetName[b.name.toLowerCase()];
        if (aUsed != null && bUsed != null) {
          return bUsed.compareTo(aUsed);
        }
        if (aUsed != null) {
          return -1;
        }
        if (bUsed != null) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (mounted) {
      setState(() {
        _foods = allFoods;
        _presets = sortedPresets;
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createFood,
                  icon: const Icon(Icons.restaurant),
                  label: const Text('New food'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _createMeal,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('New meal'),
                ),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Foods (${_filteredFoods.length})'),
            Tab(text: 'Saved meals (${_filteredPresets.length})'),
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
        child:
            Text('No foods yet', style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        final kcal = food.nutriments.energyKcal100;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FoodImage(
              imageUrl: food.thumbnailImageUrl,
              width: 48,
              height: 48,
              placeholder: Container(
                width: 48,
                height: 48,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  food.source == MealSourceEntity.ai
                      ? Icons.auto_awesome
                      : food.source == MealSourceEntity.off
                          ? Icons.qr_code
                          : Icons.restaurant,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
          ),
          title: Text(food.name ?? '?'),
          subtitle: Text(
              '${kcal?.toInt() ?? '?'} kcal/100g${food.brands != null ? ' · ${food.brands}' : ''}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Log this food',
                onPressed: () => _quickLogFood(food),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodDetailPage(food: food),
              ),
            );
            _loadData();
          },
        );
      },
    );
  }

  Widget _buildPresetsList() {
    final presets = _filteredPresets;
    if (presets.isEmpty) {
      return Center(
        child: Text('No saved meals yet',
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
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FoodImage(
              imageUrl: preset.imagePath,
              width: 48,
              height: 48,
              placeholder: Container(
                width: 48,
                height: 48,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.playlist_play,
                    color: Theme.of(context).colorScheme.primary, size: 24),
              ),
            ),
          ),
          title: Text(preset.name),
          subtitle: Text(
              '${_foodCountLabel(preset.items.length)} · ${totalKcal.toInt()} ${S.of(context).kcalLabel}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Log this saved meal',
                onPressed: () => _quickLogPreset(preset),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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

  Future<AddMealType?> _pickMealCategory() async {
    return showModalBottomSheet<AddMealType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.free_breakfast),
              title: Text(S.of(ctx).breakfastLabel),
              onTap: () => Navigator.pop(ctx, AddMealType.breakfastType),
            ),
            ListTile(
              leading: const Icon(Icons.lunch_dining),
              title: Text(S.of(ctx).lunchLabel),
              onTap: () => Navigator.pop(ctx, AddMealType.lunchType),
            ),
            ListTile(
              leading: const Icon(Icons.dinner_dining),
              title: Text(S.of(ctx).dinnerLabel),
              onTap: () => Navigator.pop(ctx, AddMealType.dinnerType),
            ),
            ListTile(
              leading: const Icon(Icons.icecream),
              title: Text(S.of(ctx).snackLabel),
              onTap: () => Navigator.pop(ctx, AddMealType.snackType),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureTrackedDay(DateTime day) async {
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final hasTrackedDay = await addTrackedDayUsecase.hasTrackedDay(day);
    if (!hasTrackedDay) {
      final getKcalGoalUsecase = locator<GetKcalGoalUsecase>();
      final getMacroGoalUsecase = locator<GetMacroGoalUsecase>();
      final totalKcalGoal = await getKcalGoalUsecase.getKcalGoal();
      final totalCarbsGoal =
          await getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
      final totalFatGoal = await getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
      final totalProteinGoal =
          await getMacroGoalUsecase.getProteinsGoal(totalKcalGoal);
      await addTrackedDayUsecase.addNewTrackedDay(
          day, totalKcalGoal, totalCarbsGoal, totalFatGoal, totalProteinGoal);
    }
  }

  Future<void> _quickLogFood(MealEntity food) async {
    final mealType = await _pickMealCategory();
    if (mealType == null || !mounted) return;

    final day = DateTime.now();
    final addIntakeUsecase = locator<AddIntakeUsecase>();
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();

    await _ensureTrackedDay(day);

    final intake = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: 'g',
      amount: 100,
      type: mealType.getIntakeType(),
      meal: food,
      dateTime: day,
    );

    await addIntakeUsecase.addIntake(intake);
    addTrackedDayUsecase.addDayCaloriesTracked(day, intake.totalKcal);
    addTrackedDayUsecase.addDayMacrosTracked(day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
        sodiumTracked: intake.totalSodiumMg,
        caffeineTracked: intake.totalCaffeineMg);

    locator<HomeBloc>().add(const LoadItemsEvent());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${food.name} added to ${mealType.getTypeName(context)}')),
      );
    }
  }

  Future<void> _quickLogPreset(MealPresetDBO preset) async {
    final mealType = await _pickMealCategory();
    if (mealType == null || !mounted) return;

    final baseKcal = preset.items.fold<double>(0, (sum, item) {
      final meal = MealEntity.fromMealDBO(item.meal);
      return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
    });
    final multiplier = await showMealMultiplierDialog(
      context,
      mealName: preset.name,
      totalKcal: baseKcal,
      confirmLabel: 'Log meal',
    );
    if (multiplier == null || !mounted) {
      return;
    }

    final day = DateTime.now();
    final addIntakeUsecase = locator<AddIntakeUsecase>();
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final groupId = IdGenerator.getUniqueID();
    final groupName = buildMealGroupName(preset.name, multiplier);

    await _ensureTrackedDay(day);

    for (final item in preset.items) {
      final meal = MealEntity.fromMealDBO(item.meal);
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
        unit: item.unit,
        amount: item.amount * multiplier,
        type: mealType.getIntakeType(),
        meal: meal,
        dateTime: day,
        groupId: groupId,
        groupName: groupName,
      );

      await addIntakeUsecase.addIntake(intake);
      addTrackedDayUsecase.addDayCaloriesTracked(day, intake.totalKcal);
      addTrackedDayUsecase.addDayMacrosTracked(day,
          carbsTracked: intake.totalCarbsGram,
          fatTracked: intake.totalFatsGram,
          proteinTracked: intake.totalProteinsGram,
          sodiumTracked: intake.totalSodiumMg,
          caffeineTracked: intake.totalCaffeineMg);
    }

    locator<HomeBloc>().add(const LoadItemsEvent());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$groupName added to ${mealType.getTypeName(context)}')),
      );
    }
  }

  String _libraryKey(MealEntity meal) {
    if (meal.code != null && meal.code!.trim().isNotEmpty) {
      return 'code:${meal.code!.trim().toLowerCase()}';
    }
    if (meal.name != null && meal.name!.trim().isNotEmpty) {
      return 'name:${meal.name!.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
    }
    return '';
  }

  Future<void> _createFood() async {
    final source = await _pickFoodCreationSource();
    if (source == null || !mounted) {
      return;
    }

    final meal = await _createFoodFromSource(source);
    if (!mounted || meal == null) {
      return;
    }

    await _openFoodEditor(meal);
  }

  Future<void> _createMeal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MealBuilderPage()),
    );
    _loadData();
  }

  String _foodCountLabel(int count) {
    if (count == 1) {
      return '1 food';
    }
    return '$count foods';
  }

  Future<_FoodCreationSource?> _pickFoodCreationSource() {
    return showModalBottomSheet<_FoodCreationSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search database'),
              subtitle: const Text('USDA, products, and recent foods'),
              onTap: () => Navigator.pop(ctx, _FoodCreationSource.search),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan barcode'),
              subtitle: const Text('Create from a product scan'),
              onTap: () => Navigator.pop(ctx, _FoodCreationSource.barcode),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Magic'),
              subtitle: const Text('Photo or text estimate'),
              onTap: () => Navigator.pop(ctx, _FoodCreationSource.magic),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Create manually'),
              subtitle: const Text('Start from an empty food'),
              onTap: () => Navigator.pop(ctx, _FoodCreationSource.manual),
            ),
          ],
        ),
      ),
    );
  }

  Future<MealEntity?> _createFoodFromSource(_FoodCreationSource source) async {
    switch (source) {
      case _FoodCreationSource.manual:
        return _buildEmptyFood();
      case _FoodCreationSource.search:
        return await _pickFoodFromSearch();
      case _FoodCreationSource.barcode:
        return await _pickFoodFromBarcode();
      case _FoodCreationSource.magic:
        return await _pickFoodFromMagic();
    }
  }

  Future<void> _openFoodEditor(MealEntity meal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailPage(
          food: meal,
          title: 'Create food',
          popOnSave: true,
        ),
      ),
    );
    _loadData();
  }

  MealEntity _buildEmptyFood() {
    return const MealEntity(
      code: null,
      name: null,
      localFoodId: null,
      brands: null,
      thumbnailImageUrl: null,
      mainImageUrl: null,
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: MealNutrimentsEntity(
        energyKcal100: null,
        carbohydrates100: null,
        fat100: null,
        proteins100: null,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
        sodiumMg100: null,
      ),
      source: MealSourceEntity.custom,
    );
  }

  Future<MealEntity?> _pickFoodFromSearch() async {
    final result = await Navigator.of(context).pushNamed(
      NavigationOptions.addMealRoute,
      arguments: AddMealScreenArguments(
        _creationMealType,
        DateTime.now(),
        selectionMode: true,
      ),
    );
    return result is MealEntity ? result : null;
  }

  Future<MealEntity?> _pickFoodFromBarcode() async {
    final result = await Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments(
        DateTime.now(),
        _creationMealType.getIntakeType(),
        selectionMode: true,
      ),
    );
    return result is MealEntity ? result : null;
  }

  Future<MealEntity?> _pickFoodFromMagic() async {
    final result = await Navigator.of(context).pushNamed(
      NavigationOptions.magicRoute,
      arguments: MagicScreenArguments(
        DateTime.now(),
        _creationMealType,
        selectionMode: true,
      ),
    );

    if (result is! List<MealPresetItemDBO>) {
      return null;
    }
    if (result.isEmpty) {
      return null;
    }
    if (result.length > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New food accepts one AI food. Use New meal for multi-item results.'),
          ),
        );
      }
      return null;
    }
    return MealEntity.fromMealDBO(result.first.meal);
  }
}

enum _FoodCreationSource { search, barcode, magic, manual }
