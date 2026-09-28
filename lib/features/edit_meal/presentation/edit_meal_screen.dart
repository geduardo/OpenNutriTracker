import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:opennutritracker/pregnancy/pregnancy_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/custom_text_input_formatter.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/widgets/default_meal_image.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class EditMealScreen extends StatefulWidget {
  const EditMealScreen({super.key});

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final log = Logger('EditMealScreen');
  late MealEntity _mealEntity;
  bool _formInitialized = false;
  final _microControllers = {
    for (final ref in pregnancyMicroReferences) ref.key: TextEditingController()
  };
  @override
  void dispose() {
    for (final c in _microControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  late DateTime _day;
  late IntakeTypeEntity _intakeTypeEntity;
  late bool _usesImperialUnits;

  late EditMealBloc _editMealBloc;

  final _nameTextController = TextEditingController();
  final _brandsTextController = TextEditingController();
  final _mealQuantityTextController = TextEditingController();
  final _servingLabelTextController = TextEditingController();
  final _servingQuantityTextController = TextEditingController();
  final _baseQuantityTextController = TextEditingController();
  final _kcalTextController = TextEditingController();
  final _carbsTextController = TextEditingController();
  final _fatTextController = TextEditingController();
  final _proteinTextController = TextEditingController();

  final _units = ['g', 'ml', 'g/ml'];
  late String? selectedUnit;

  // late List<DropdownMenuItem> _mealUnitDropdownItems;
  late List<ButtonSegment<String>> _mealUnitButtonSegment;

  // TODO: Add base quantity and unit
  String baseQuantity = "100";
  String baseQuantityUnit = " g/ml";
  bool _showMoreDetails = false;

  @override
  void initState() {
    _editMealBloc = locator<EditMealBloc>();
    super.initState();

    _baseQuantityTextController.addListener(() {
      setState(() {
        baseQuantity = _baseQuantityTextController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    if (_formInitialized) {
      super.didChangeDependencies();
      return;
    }
    _formInitialized = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as EditMealScreenArguments;
    _mealEntity = args.mealEntity;
    for (final entry in _microControllers.entries) {
      entry.value.text =
          _mealEntity.nutriments.micronutrients100[entry.key]?.toString() ?? '';
    }
    _day = args.day;
    _intakeTypeEntity = args.intakeTypeEntity;
    _usesImperialUnits = args.usesImperialUnits;

    _nameTextController.text = _mealEntity.name ?? "";
    _brandsTextController.text = _mealEntity.brands ?? "";
    _mealQuantityTextController.text = _mealEntity.mealQuantity ?? "";
    _servingLabelTextController.text =
        MealPortionHelper.servingName(_mealEntity) ?? "";
    _servingQuantityTextController.text =
        _mealEntity.servingQuantity.toStringOrEmpty();
    _kcalTextController.text =
        _mealEntity.nutriments.energyKcal100.toStringOrEmpty();
    _carbsTextController.text =
        _mealEntity.nutriments.carbohydrates100.toStringOrEmpty();
    _fatTextController.text = _mealEntity.nutriments.fat100.toStringOrEmpty();
    _proteinTextController.text =
        _mealEntity.nutriments.proteins100.toStringOrEmpty();
    selectedUnit = _switchButtonUnit(_mealEntity.mealUnit);

    // Convert meal size to imperial units if necessary
    if (_usesImperialUnits) {
      _mealQuantityTextController.text = _convertToImperial(
          _mealQuantityTextController.text, _mealEntity.mealUnit ?? "0");
      _servingQuantityTextController.text = _convertToImperial(
          _servingQuantityTextController.text, _mealEntity.mealUnit ?? "0");
    }

    _mealUnitButtonSegment = [
      ButtonSegment(
        value: _units[0],
        label: AppText(
            _usesImperialUnits ? S.of(context).ozUnit : S.of(context).gramUnit),
      ),
      ButtonSegment(
        value: _units[1],
        label: AppText(_usesImperialUnits
            ? S.of(context).flOzUnit
            : S.of(context).milliliterUnit),
      ),
      ButtonSegment(
        value: _units[2],
        label: Text(S.of(context).gramMilliliterUnit),
      ),
    ];

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).editMealLabel),
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: FilledButton(
                  onPressed: () => _onSavePressed(_usesImperialUnits),
                  child: Text(S.of(context).buttonSaveLabel)),
            )
          ],
        ),
        body: BlocBuilder<EditMealBloc, EditMealState>(
          bloc: locator<EditMealBloc>()..add(InitializeEditMealEvent()),
          builder: (BuildContext context, EditMealState state) {
            if (state is EditMealLoadingState) {
              return _getLoadingContent();
            } else if (state is EditMealLoadedState) {
              return _getLoadedContent(state.usesImperialUnits);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _getLoadingContent() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _getLoadedContent(bool usesImperialUnits) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
            child: ClipOval(
          child: FoodImage(
            imageUrl: _mealEntity.mainImageUrl,
            width: 120,
            height: 120,
            placeholder: const DefaultMealImage(),
            errorWidget: const DefaultMealImage(),
          ),
        )),
        const SizedBox(height: 32),
        ExpansionTile(
            title: const AppText('Pregnancy nutrients (optional)'),
            subtitle:
                const AppText('Per 100 g/ml • leave missing values blank'),
            children: [
              const AppText(
                  'Enter amounts from a label or reliable food source. Folate must be µg DFE, not folic acid. These values always use 100 g/ml, independent of the macro base quantity below.'),
              for (final ref in pregnancyMicroReferences)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                        controller: _microControllers[ref.key],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: tr(ref.name), suffixText: ref.unit))),
            ]),
        // Essential fields: Name + Kcal
        TextFormField(
          controller: _nameTextController,
          decoration: InputDecoration(
              labelText: S.of(context).mealNameLabel,
              border: const OutlineInputBorder()),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _kcalTextController,
          inputFormatters: CustomTextInputFormatter.doubleOnly(),
          decoration: InputDecoration(
              labelText:
                  S.of(context).mealKcalLabel + baseQuantity + baseQuantityUnit,
              border: const OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        // Macros row (optional but visible)
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _carbsTextController,
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                    labelText: S.of(context).carbsLabel,
                    border: const OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _fatTextController,
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                    labelText: S.of(context).fatLabel,
                    border: const OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _proteinTextController,
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                    labelText: S.of(context).proteinLabel,
                    border: const OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Collapsible details section
        InkWell(
          onTap: () => setState(() => _showMoreDetails = !_showMoreDetails),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(_showMoreDetails ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 8),
                Text(S.of(context).additionalInfoLabel,
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ),
        if (_showMoreDetails) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _brandsTextController,
            decoration: InputDecoration(
                labelText: S.of(context).mealBrandsLabel,
                border: const OutlineInputBorder()),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mealQuantityTextController,
            decoration: InputDecoration(
                labelText: tr(_usesImperialUnits
                    ? S.of(context).mealSizeLabelImperial
                    : S.of(context).mealSizeLabel),
                border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _servingLabelTextController,
            decoration: InputDecoration(
                labelText: tr('Quantity label'),
                hintText: trOptional('cookie, slice, egg, piece...'),
                border: OutlineInputBorder()),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _servingQuantityTextController,
            inputFormatters: CustomTextInputFormatter.doubleOnly(),
            decoration: InputDecoration(
                labelText: tr(_usesImperialUnits
                    ? 'One quantity equals (${S.of(context).ozUnit}/${S.of(context).flOzUnit})'
                    : 'One quantity equals (${selectedUnit ?? _units[2]})'),
                border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: _mealUnitButtonSegment,
            selected: {selectedUnit ?? _units[2]},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                selectedUnit = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _baseQuantityTextController,
            inputFormatters: CustomTextInputFormatter.doubleOnly(),
            decoration: InputDecoration(
                labelText: S.of(context).baseQuantityLabel,
                border: const OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  void _onSavePressed(bool usesImperialUnits) {
    try {
      // Convert meal size back to metric units if necessary
      final mealQuantity = usesImperialUnits
          ? _convertToMetric(
              _mealQuantityTextController.text, selectedUnit ?? "0")
          : _mealQuantityTextController.text;
      final servingQuantity = usesImperialUnits
          ? _convertToMetric(
              _servingQuantityTextController.text, selectedUnit ?? "0")
          : _servingQuantityTextController.text;

      final micros = <String, double>{};
      for (final entry in _microControllers.entries) {
        final raw = entry.value.text.trim().replaceAll(',', '.');
        if (raw.isEmpty) continue;
        final value = double.tryParse(raw);
        if (value == null || !value.isFinite || value < 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: AppText(
                  'Nutrient amounts must be non-negative numbers, or left blank.')));
          return;
        }
        micros[entry.key] = value;
      }
      var newMealEntity = _editMealBloc.createNewMealEntity(
          _mealEntity,
          _nameTextController.text,
          _brandsTextController.text,
          mealQuantity,
          _servingLabelTextController.text,
          servingQuantity,
          _baseQuantityTextController.text,
          selectedUnit,
          _kcalTextController.text,
          _carbsTextController.text,
          _fatTextController.text,
          _proteinTextController.text);

      newMealEntity = newMealEntity.copyWith(
          nutriments: newMealEntity.nutriments.withMicronutrients(micros));
      // The scanner flow replaces the add-meal route, so fall back to the
      // first route instead of clearing the whole stack.
      Navigator.of(context).pushNamedAndRemoveUntil(
          NavigationOptions.mealDetailRoute,
          (route) =>
              route.settings.name == NavigationOptions.addMealRoute ||
              route.isFirst,
          arguments: MealDetailScreenArguments(
              newMealEntity, _intakeTypeEntity, _day, usesImperialUnits));
    } catch (exception, stacktrace) {
      log.warning("Error while creating new meal entity");
      Sentry.captureException(exception, stackTrace: stacktrace);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).errorMealSave)));
    }
  }

  String? _switchButtonUnit(String? unit) {
    String? selectedUnit;
    if (!_units.contains(unit)) {
      selectedUnit = _units[2]; // Default to g/ml
    } else {
      selectedUnit = unit;
    }
    return selectedUnit;
  }

  String _convertToImperial(String value, String unit) {
    final double quantityValue = value.toDoubleOrNull() ?? 0.0;
    switch (unit) {
      case 'g':
        return (UnitCalc.gToOz(quantityValue)).toStringAsFixed(2);
      case 'ml':
        return (UnitCalc.mlToFlOz(quantityValue)).toStringAsFixed(2);
      default:
        return value;
    }
  }

  String _convertToMetric(String value, String unit) {
    final double quantityValue = value.toDoubleOrNull() ?? 0.0;
    switch (unit) {
      case 'g':
        return (UnitCalc.ozToG(quantityValue)).toStringAsFixed(2);
      case 'ml':
        return (UnitCalc.flOzToMl(quantityValue)).toStringAsFixed(2);
      default:
        return value;
    }
  }
}

class EditMealScreenArguments {
  final DateTime day;
  final MealEntity mealEntity;
  final IntakeTypeEntity intakeTypeEntity;
  final bool usesImperialUnits;

  EditMealScreenArguments(
      this.day, this.mealEntity, this.intakeTypeEntity, this.usesImperialUnits);
}
