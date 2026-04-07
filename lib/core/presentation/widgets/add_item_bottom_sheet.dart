import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/meal_entry_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddItemBottomSheet extends StatefulWidget {
  final DateTime day;

  const AddItemBottomSheet({super.key, required this.day});

  @override
  State<AddItemBottomSheet> createState() => _AddItemBottomSheetState();
}

class _AddItemBottomSheetState extends State<AddItemBottomSheet> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateUtils.dateOnly(widget.day);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              S.of(context).addItemLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Log for day'),
            subtitle: Text(DateFormat.yMMMMEEEEd().format(_selectedDay)),
            trailing: TextButton(
              onPressed: _pickDay,
              child: const Text('Change'),
            ),
          ),
          ListTile(
            title: Text(
              S.of(context).breakfastLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: Text(
              S.of(context).breakfastExample,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            // ignore: sized_box_for_whitespace
            leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.breakfast.getIconData())),
            onTap: () {
              _showAddItemScreen(context, AddMealType.breakfastType);
            },
          ),
          ListTile(
            title: Text(
              S.of(context).lunchLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: Text(
              S.of(context).lunchExample,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            // ignore: sized_box_for_whitespace
            leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.lunch.getIconData())),
            onTap: () {
              _showAddItemScreen(context, AddMealType.lunchType);
            },
          ),
          ListTile(
            title: Text(
              S.of(context).dinnerLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: Text(
              S.of(context).dinnerExample,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            // ignore: sized_box_for_whitespace
            leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.dinner.getIconData())),
            onTap: () {
              _showAddItemScreen(context, AddMealType.dinnerType);
            },
          ),
          ListTile(
            title: Text(
              S.of(context).snackLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: Text(
              S.of(context).snackExample,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            // ignore: sized_box_for_whitespace
            leading: Container(
                height: double.infinity,
                child: Icon(IntakeTypeEntity.snack.getIconData())),
            onTap: () {
              _showAddItemScreen(context, AddMealType.snackType);
            },
          ),
        ],
      ),
    );
  }

  void _showAddItemScreen(BuildContext context, AddMealType itemType) {
    Navigator.of(context).pop(); // Close bottom sheet
    Navigator.of(context).pushNamed(NavigationOptions.mealEntryRoute,
        arguments: MealEntryScreenArguments(
          itemType,
          _selectedDay,
        ));
  }

  Future<void> _pickDay() async {
    final pickedDay = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
    );

    if (pickedDay == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDay = DateUtils.dateOnly(pickedDay);
    });
  }
}
