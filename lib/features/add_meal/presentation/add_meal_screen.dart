import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_multiplier_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/default_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_search_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<String> _searchStringListener = ValueNotifier('');

  late AddMealType _mealType;
  late DateTime _day;
  late bool _selectionMode;

  late ProductsBloc _productsBloc;
  late FoodBloc _foodBloc;
  late RecentMealBloc _recentMealBloc;

  late TabController _tabController;
  Timer? _debounceTimer;

  @override
  void initState() {
    _productsBloc = locator<ProductsBloc>();
    _foodBloc = locator<FoodBloc>();
    _recentMealBloc = locator<RecentMealBloc>();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Update search results when tab changes
      _onSearchSubmit(_searchStringListener.value);
    });
    _searchStringListener.addListener(_onSearchStringChanged);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    _selectionMode = args.selectionMode;
    if (_tabController.index != args.initialTab) {
      _tabController.index = args.initialTab;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchStringListener.removeListener(_onSearchStringChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchStringChanged() {
    _debounceTimer?.cancel();
    final query = _searchStringListener.value;
    if (query.isEmpty) return;
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _onSearchSubmit(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(_selectionMode ? 'Select food' : _mealType.getTypeName(context)),
          actions: [
            if (!_selectionMode)
              BlocBuilder<AddMealBloc, AddMealState>(
                bloc: locator<AddMealBloc>()..add(InitializeAddMealEvent()),
                builder: (BuildContext context, AddMealState state) {
                  if (state is AddMealLoadedState) {
                    return IconButton(
                      onPressed: () =>
                          _onCustomAddButtonPressed(state.usesImperialUnits),
                      icon: const Icon(Icons.add_circle_outline),
                    );
                  }
                  return const SizedBox();
                },
              )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              MealSearchBar(
                searchStringListener: _searchStringListener,
                onSearchSubmit: _onSearchSubmit,
                onBarcodePressed: _onBarcodeIconPressed,
              ),
              const SizedBox(height: 16.0),
              TabBar(
                  tabs: [
                    Tab(text: S.of(context).searchProductsPage),
                    Tab(text: S.of(context).searchFoodPage),
                    Tab(text: S.of(context).recentlyAddedLabel)
                  ],
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(controller: _tabController, children: [
                  Column(
                    children: [
                      Container(
                          padding: const EdgeInsets.only(left: 8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(S.of(context).searchResultsLabel,
                              style:
                                  Theme.of(context).textTheme.headlineSmall)),
                      BlocBuilder<ProductsBloc, ProductsState>(
                        bloc: _productsBloc,
                        builder: (context, state) {
                          if (state is ProductsInitial) {
                            return const DefaultsResultsWidget();
                          } else if (state is ProductsLoadingState) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: CircularProgressIndicator(),
                            );
                          } else if (state is ProductsLoadedState) {
                            return state.products.isNotEmpty
                                ? Flexible(
                                    child: ListView.builder(
                                        itemCount: state.products.length,
                                        itemBuilder: (context, index) {
                                          return MealItemCard(
                                            day: _day,
                                            mealEntity: state.products[index],
                                            addMealType: _mealType,
                                            usesImperialUnits:
                                                state.usesImperialUnits,
                                            selectionMode: _selectionMode,
                                            onSelected:
                                                _selectionMode ? _selectMeal : null,
                                          );
                                        }))
                                : const NoResultsWidget();
                          } else if (state is ProductsFailedState) {
                            return ErrorDialog(
                              errorText: S.of(context).errorFetchingProductData,
                              onRefreshPressed: _onProductsRefreshButtonPressed,
                            );
                          } else {
                            return const SizedBox();
                          }
                        },
                      )
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                          padding: const EdgeInsets.only(left: 8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(S.of(context).searchResultsLabel,
                              style:
                                  Theme.of(context).textTheme.headlineSmall)),
                      BlocBuilder<FoodBloc, FoodState>(
                        bloc: _foodBloc,
                        builder: (context, state) {
                          if (state is FoodInitial) {
                            return const DefaultsResultsWidget();
                          } else if (state is FoodLoadingState) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: CircularProgressIndicator(),
                            );
                          } else if (state is FoodLoadedState) {
                            return state.food.isNotEmpty
                                ? Flexible(
                                    child: ListView.builder(
                                        itemCount: state.food.length,
                                        itemBuilder: (context, index) {
                                          return MealItemCard(
                                            day: _day,
                                            mealEntity: state.food[index],
                                            addMealType: _mealType,
                                            usesImperialUnits:
                                                state.usesImperialUnits,
                                            selectionMode: _selectionMode,
                                            onSelected:
                                                _selectionMode ? _selectMeal : null,
                                          );
                                        }))
                                : const NoResultsWidget();
                          } else if (state is FoodFailedState) {
                            return ErrorDialog(
                              errorText: S.of(context).errorFetchingProductData,
                              onRefreshPressed: _onFoodRefreshButtonPressed,
                            );
                          } else {
                            return const SizedBox();
                          }
                        },
                      )
                    ],
                  ),
                  Column(
                    children: [
                      BlocBuilder<RecentMealBloc, RecentMealState>(
                          bloc: _recentMealBloc,
                          builder: (context, state) {
                            if (state is RecentMealInitial) {
                              _recentMealBloc.add(
                                  const LoadRecentMealEvent(searchString: ""));
                              return const SizedBox();
                            } else if (state is RecentMealLoadingState) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 32),
                                child: CircularProgressIndicator(),
                              );
                            } else if (state is RecentMealLoadedState) {
                              return _buildRecentResults(state);
                            } else if (state is RecentMealFailedState) {
                              return ErrorDialog(
                                errorText:
                                    S.of(context).noMealsRecentlyAddedLabel,
                                onRefreshPressed:
                                    _onRecentMealsRefreshButtonPressed,
                              );
                            }
                            return const SizedBox();
                          })
                    ],
                  )
                ]),
              )
            ],
          ),
        ));
  }

  void _onProductsRefreshButtonPressed() {
    _productsBloc.add(const RefreshProductsEvent());
  }

  void _onFoodRefreshButtonPressed() {
    _foodBloc.add(const RefreshFoodEvent());
  }

  void _onRecentMealsRefreshButtonPressed() {
    _recentMealBloc.add(const LoadRecentMealEvent(searchString: ""));
  }

  void _onSearchSubmit(String inputText) {
    switch (_tabController.index) {
      case 0:
        _productsBloc.add(LoadProductsEvent(searchString: inputText));
      case 1:
        _foodBloc.add(LoadFoodEvent(searchString: inputText));
      case 2:
        _recentMealBloc.add(LoadRecentMealEvent(searchString: inputText));
    }
  }

  void _onBarcodeIconPressed() {
    if (_selectionMode) {
      Navigator.of(context)
          .pushNamed(NavigationOptions.scannerRoute,
              arguments: ScannerScreenArguments(
                _day,
                _mealType.getIntakeType(),
                selectionMode: true,
              ))
          .then((value) {
        if (value is MealEntity && mounted) {
          Navigator.of(context).pop(value);
        }
      });
      return;
    }
    Navigator.of(context).pushNamed(NavigationOptions.scannerRoute,
        arguments: ScannerScreenArguments(_day, _mealType.getIntakeType()));
  }

  void _onCustomAddButtonPressed(bool usesImperialUnits) {
    _openEditMealScreen(usesImperialUnits);
  }

  void _openEditMealScreen(bool usesImperialUnits) {
    // TODO
    Navigator.of(context).pushNamed(NavigationOptions.editMealRoute,
        arguments: EditMealScreenArguments(
          _day,
          MealEntity.empty(),
          _mealType.getIntakeType(),
          usesImperialUnits,
        ));
  }

  void _selectMeal(MealEntity meal) {
    Navigator.of(context).pop(meal);
  }

  Widget _buildRecentResults(RecentMealLoadedState state) {
    final recentPresets =
        _selectionMode ? const <MealPresetDBO>[] : state.recentPresets;
    final recentFoods = state.recentFoods;

    if (recentPresets.isEmpty && recentFoods.isEmpty) {
      return const NoResultsWidget();
    }

    return Flexible(
      child: ListView(
        children: [
          if (recentPresets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Recent meals',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...recentPresets.map(_buildRecentPresetCard),
          ],
          if (recentFoods.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Text(
                recentPresets.isNotEmpty ? 'Recent foods' : 'Recently used foods',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...recentFoods.map((meal) => MealItemCard(
                  day: _day,
                  mealEntity: meal,
                  addMealType: _mealType,
                  usesImperialUnits: state.usesImperialUnits,
                  selectionMode: _selectionMode,
                  onSelected: _selectionMode ? _selectMeal : null,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentPresetCard(MealPresetDBO preset) {
    final totalKcal = preset.items.fold<double>(0, (sum, item) {
      final meal = MealEntity.fromMealDBO(item.meal);
      return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: InkWell(
        onTap: () => _logPreset(preset),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FoodImage(
              imageUrl: preset.imagePath,
              width: 56,
              height: 56,
              placeholder: Container(
                width: 56,
                height: 56,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Icon(Icons.playlist_play),
              ),
            ),
          ),
          title: Text(preset.name),
          subtitle: Text(
            '${_foodCountLabel(preset.items.length)} · ${totalKcal.toInt()} ${S.of(context).kcalLabel}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Log meal',
            onPressed: () => _logPreset(preset),
          ),
        ),
      ),
    );
  }

  Future<void> _ensureTrackedDay(DateTime day) async {
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final hasTrackedDay = await addTrackedDayUsecase.hasTrackedDay(day);
    if (!hasTrackedDay) {
      final totalKcalGoal = await locator<GetKcalGoalUsecase>().getKcalGoal();
      final totalCarbsGoal =
          await locator<GetMacroGoalUsecase>().getCarbsGoal(totalKcalGoal);
      final totalFatGoal =
          await locator<GetMacroGoalUsecase>().getFatsGoal(totalKcalGoal);
      final totalProteinGoal =
          await locator<GetMacroGoalUsecase>().getProteinsGoal(totalKcalGoal);
      await addTrackedDayUsecase.addNewTrackedDay(
        day,
        totalKcalGoal,
        totalCarbsGoal,
        totalFatGoal,
        totalProteinGoal,
      );
    }
  }

  Future<void> _logPreset(MealPresetDBO preset) async {
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

    final addIntakeUsecase = locator<AddIntakeUsecase>();
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final intakeType = _mealType.getIntakeType();
    final groupId = IdGenerator.getUniqueID();
    final groupName = buildMealGroupName(preset.name, multiplier);

    await _ensureTrackedDay(_day);

    for (final item in preset.items) {
      final meal = MealEntity.fromMealDBO(item.meal);
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
        unit: item.unit,
        amount: item.amount * multiplier,
        type: intakeType,
        meal: meal,
        dateTime: _day,
        groupId: groupId,
        groupName: groupName,
      );

      await addIntakeUsecase.addIntake(intake);
      await addTrackedDayUsecase.addDayCaloriesTracked(_day, intake.totalKcal);
      await addTrackedDayUsecase.addDayMacrosTracked(
        _day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
        sodiumTracked: intake.totalSodiumMg,
      );
    }

    locator<HomeBloc>().add(const LoadItemsEvent());

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$groupName logged!')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _foodCountLabel(int count) {
    if (count == 1) {
      return '1 food';
    }
    return '$count foods';
  }
}

class AddMealScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  final int initialTab;
  final bool selectionMode;

  AddMealScreenArguments(this.mealType, this.day,
      {this.initialTab = 0, this.selectionMode = false});
}
