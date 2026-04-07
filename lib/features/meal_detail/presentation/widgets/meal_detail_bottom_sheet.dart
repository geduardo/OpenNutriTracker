import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/core/utils/custom_text_input_formatter.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailBottomSheet extends StatelessWidget {
  final MealEntity product;
  final DateTime day;
  final IntakeTypeEntity intakeTypeEntity;
  final TextEditingController quantityTextController;
  final MealDetailBloc mealDetailBloc;

  final String selectedUnit;

  final Function(String?, String?) onQuantityOrUnitChanged;

  const MealDetailBottomSheet(
      {super.key,
      required this.product,
      required this.day,
      required this.intakeTypeEntity,
      required this.quantityTextController,
      required this.onQuantityOrUnitChanged,
      required this.mealDetailBloc,
      required this.selectedUnit});

  @override
  Widget build(BuildContext context) {
    final productMissingRequiredInfo = _hasRequiredProductInfoMissing();
    return BottomSheet(
        elevation: 10,
        onClosing: () {},
        enableDrag: false,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 0.5,
              ),
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              enabled: !productMissingRequiredInfo,
                              controller: quantityTextController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: CustomTextInputFormatter.doubleOnly(),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: S.of(context).quantityLabel,
                              ),
                              onChanged: (value) =>
                                  onQuantityOrUnitChanged(value, selectedUnit),
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                              child: DropdownButtonFormField(
                                  key: ValueKey(selectedUnit),
                                  isExpanded: true,
                                  initialValue: selectedUnit,
                                  decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      labelText: S.of(context).unitLabel),
                                  items: <DropdownMenuItem<String>>[
                                    if (product.hasServingValues)
                                      _getServingDropdownItem(context),
                                    if (MealPortionHelper.supportsSpoonUnits(
                                        product)) ...[
                                      _getTablespoonDropdownItem(),
                                      _getTeaspoonDropdownItem(),
                                    ],
                                    if (product.isSolid ||
                                        !product.isLiquid && !product.isSolid)
                                      ..._getSolidUnitDropdownItems(context),
                                    if (product.isLiquid ||
                                        !product.isLiquid && !product.isSolid)
                                      ..._getLiquidUnitDropdownItems(context),
                                    ..._getOtherDropdownItems(context)
                                  ],
                                  onChanged: (value) {
                                    onQuantityOrUnitChanged(
                                        quantityTextController.text, value);
                                  }))
                        ],
                      ),
                      SizedBox(
                        width: double.infinity, // Make button full width
                        child: ElevatedButton.icon(
                            onPressed: !productMissingRequiredInfo
                                ? () {
                                    onAddButtonPressed(context);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            ).copyWith(
                                elevation: ButtonStyleButton.allOrNull(0.0)),
                            icon: const Icon(Icons.add_outlined),
                            label: Text(S.of(context).addLabel)),
                      ),
                      productMissingRequiredInfo
                          ? Text(S.of(context).missingProductInfo,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.error))
                          : const SizedBox()
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }

  bool _hasRequiredProductInfoMissing() {
    final productNutriments = product.nutriments;
    if (productNutriments.energyKcal100 == null ||
        productNutriments.carbohydrates100 == null ||
        productNutriments.fat100 == null ||
        productNutriments.proteins100 == null) {
      return true;
    } else {
      return false;
    }
  }

  void onAddButtonPressed(BuildContext context) async {
    // Await the DB write so the refresh events below see the new row.
    // (Previously this was fire-and-forget, so the diary/home would re-query
    // before the intake had actually been persisted and the page would
    // appear unchanged after adding an item to a past day.)
    await mealDetailBloc.addIntake(
        context,
        mealDetailBloc.state.selectedUnit,
        mealDetailBloc.state.totalQuantityConverted,
        intakeTypeEntity,
        product,
        day);

    if (!context.mounted) return;

    // Refresh Home Page
    locator<HomeBloc>().add(const LoadItemsEvent());

    // Refresh Diary Page — load the actual day the intake was added to so
    // the diary's calendar-day bloc is in sync with that day, not whatever
    // it happened to be cached on.
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(LoadCalendarDayEvent(day));

    // Show snackbar and pop just this detail screen, leaving the user on
    // whichever screen they came from (search / recently added / saved
    // meals / scanner). That way logging multiple items in a row only
    // requires one tap-back per item instead of re-navigating from main.
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).infoAddedIntakeLabel)));
    Navigator.of(context).pop();
  }

  DropdownMenuItem<String> _getServingDropdownItem(BuildContext context) {
    return DropdownMenuItem(
      value: UnitDropdownItem.serving.toString(),
      child: Text(
          MealPortionHelper.dropdownLabel(
              product, UnitDropdownItem.serving.toString()),
          overflow: TextOverflow.ellipsis,
          maxLines: 1),
    );
  }

  DropdownMenuItem<String> _getTablespoonDropdownItem() {
    return DropdownMenuItem(
      value: UnitDropdownItem.tbsp.toString(),
      child: Text(
        MealPortionHelper.dropdownLabel(product, UnitDropdownItem.tbsp.toString()),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  DropdownMenuItem<String> _getTeaspoonDropdownItem() {
    return DropdownMenuItem(
      value: UnitDropdownItem.tsp.toString(),
      child: Text(
        MealPortionHelper.dropdownLabel(product, UnitDropdownItem.tsp.toString()),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  List<DropdownMenuItem<String>> _getSolidUnitDropdownItems(
      BuildContext context) {
    return [
      DropdownMenuItem(
          value: UnitDropdownItem.g.toString(),
          child: Text(S.of(context).gramUnit,
              overflow: TextOverflow.ellipsis, maxLines: 1)),
      DropdownMenuItem(
          value: UnitDropdownItem.oz.toString(),
          child: Text(S.of(context).ozUnit,
              overflow: TextOverflow.ellipsis, maxLines: 1)),
    ];
  }

  List<DropdownMenuItem<String>> _getLiquidUnitDropdownItems(
      BuildContext context) {
    return [
      DropdownMenuItem(
          value: UnitDropdownItem.ml.toString(),
          child: Text(S.of(context).milliliterUnit,
              overflow: TextOverflow.ellipsis, maxLines: 1)),
      DropdownMenuItem(
          value: UnitDropdownItem.flOz.toString(),
          child: Text(S.of(context).flOzUnit,
              overflow: TextOverflow.ellipsis, maxLines: 1)),
    ];
  }

  List<DropdownMenuItem<String>> _getOtherDropdownItems(BuildContext context) {
    return [
      DropdownMenuItem(
          value: UnitDropdownItem.gml.toString(),
          child: Text(
              "${S.of(context).notAvailableLabel} (${S.of(context).gramMilliliterUnit})",
              overflow: TextOverflow.ellipsis,
              maxLines: 1)),
    ];
  }
}
