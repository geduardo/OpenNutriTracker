import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_all_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/presentation/widgets/placeholder_card.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/vertical_list_popup_menu_selections.dart';
import 'package:opennutritracker/features/add_meal/presentation/meal_entry_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class IntakeVerticalList extends StatefulWidget {
  final DateTime day;
  final String title;
  final IconData listIcon;
  final AddMealType addMealType;
  final List<IntakeEntity> intakeList;
  final bool usesImperialUnits;
  final Function(IntakeEntity intake, TrackedDayEntity? trackedDayEntity)
      onDeleteIntakeCallback;
  final Function(BuildContext, IntakeEntity)? onItemLongPressedCallback;
  final Function(bool)? onItemDragCallback;
  final Function(BuildContext, IntakeEntity, bool)? onItemTappedCallback;
  final Function(IntakeEntity intake, TrackedDayEntity? trackedDayEntity,
      AddMealType? type)? onCopyIntakeCallback;
  final TrackedDayEntity? trackedDayEntity;

  const IntakeVerticalList({
    super.key,
    required this.day,
    required this.title,
    required this.listIcon,
    required this.addMealType,
    required this.intakeList,
    required this.usesImperialUnits,
    required this.onDeleteIntakeCallback,
    this.onItemLongPressedCallback,
    this.onItemDragCallback,
    this.onItemTappedCallback,
    this.onCopyIntakeCallback,
    this.trackedDayEntity,
  });

  @override
  State<IntakeVerticalList> createState() => _IntakeVerticalListState();
}

class _IntakeVerticalListState extends State<IntakeVerticalList> {
  late MealDetailBloc _mealDetailBloc;
  late HomeBloc _homeBloc;

  @override
  void initState() {
    _mealDetailBloc = locator<MealDetailBloc>();
    _homeBloc = locator<HomeBloc>();
    super.initState();
  }

  double get totalKcal {
    return widget.intakeList
        .fold(0, (previousValue, element) => previousValue + element.totalKcal);
  }

  /// Groups intakes by groupId. Ungrouped items become single-item lists.
  List<_IntakeGroup> get _groupedIntakes {
    final groups = <String, List<IntakeEntity>>{};
    final ungrouped = <IntakeEntity>[];

    for (final intake in widget.intakeList) {
      if (intake.groupId != null) {
        groups.putIfAbsent(intake.groupId!, () => []).add(intake);
      } else {
        ungrouped.add(intake);
      }
    }

    return [
      ...groups.entries.map((e) => _IntakeGroup(
            name: e.value.first.groupName ?? e.value.map((i) => i.meal.name ?? '?').join(' + '),
            intakes: e.value,
          )),
      ...ungrouped.map((i) => _IntakeGroup(name: null, intakes: [i])),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(widget.listIcon,
                  size: 24, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 4.0),
              Text(
                widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const Spacer(),
              if (totalKcal > 0) ...[
                Text(
                  '${totalKcal.toInt()} ${S.of(context).kcalLabel}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7)),
                ),
                PopupMenuButton<VerticalListPopupMenuSelections>(
                    onSelected:
                        (VerticalListPopupMenuSelections selection) async {
                      switch (selection) {
                        case VerticalListPopupMenuSelections.onCopy:
                          const copyDialog = CopyDialog();
                          final selectedMealType =
                              await showDialog<AddMealType>(
                                  context: context,
                                  builder: (context) => copyDialog);
                          if (selectedMealType != null) {
                            for (IntakeEntity intake in widget.intakeList) {
                              widget.onCopyIntakeCallback!(
                                  intake, null, selectedMealType);
                            }
                          }
                          break;
                        case VerticalListPopupMenuSelections.onDelete:
                          final shouldDeleteIntakes = await showDialog<bool>(
                              context: context,
                              builder: (context) => const DeleteAllDialog());
                          if (shouldDeleteIntakes != null) {
                            for (IntakeEntity intake in widget.intakeList) {
                              widget.onDeleteIntakeCallback(
                                  intake, widget.trackedDayEntity);
                            }
                            break;
                          }
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<VerticalListPopupMenuSelections>>[
                          if (widget.onCopyIntakeCallback != null)
                            PopupMenuItem<VerticalListPopupMenuSelections>(
                                value: VerticalListPopupMenuSelections.onCopy,
                                child: Text(S.of(context).dialogCopyLabel)),
                          PopupMenuItem<VerticalListPopupMenuSelections>(
                              value: VerticalListPopupMenuSelections.onDelete,
                              child: Text(S.of(context).deleteAllLabel)),
                        ]),
              ],
            ],
          ),
        ),
        DragTarget<IntakeEntity>(
          onAcceptWithDetails: (intake) {
            _onItemDropped(intake.data);
          },
          builder: (context, candidateData, rejectedData) {
            final groups = _groupedIntakes;
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  final firstListElement = index == 0;
                  if (index == groups.length) {
                    return PlaceholderCard(
                        day: widget.day,
                        onTap: () => _onPlaceholderCardTapped(context),
                        firstListElement: firstListElement);
                  }

                  final group = groups[index];

                  if (group.isGrouped) {
                    // Grouped meal — show as single card with group name
                    return _buildGroupedCard(
                        group, firstListElement);
                  }

                  // Single item
                  final intakeEntity = group.primary;
                  return LongPressDraggable<IntakeEntity>(
                    onDragStarted: () {
                      widget.onItemDragCallback?.call(true);
                    },
                    onDragEnd: (details) {
                      widget.onItemDragCallback?.call(false);
                    },
                    data: intakeEntity,
                    feedback: Material(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Opacity(
                        opacity: 0.7,
                        child: IntakeCard(
                          key: ValueKey(intakeEntity.meal.code),
                          intake: intakeEntity,
                          firstListElement: false,
                          usesImperialUnits: widget.usesImperialUnits,
                        ),
                      ),
                    ),
                    childWhenDragging: Row(
                      children: [
                        SizedBox(width: firstListElement ? 16 : 0),
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            color: Theme.of(context).cardColor,
                          ),
                        ),
                      ],
                    ),
                    child: IntakeCard(
                      key: ValueKey(intakeEntity.meal.code),
                      intake: intakeEntity,
                      onItemLongPressed: widget.onItemLongPressedCallback,
                      onItemTapped: widget.onItemTappedCallback,
                      firstListElement: firstListElement,
                      usesImperialUnits: widget.usesImperialUnits,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGroupedCard(_IntakeGroup group, bool firstListElement) {
    return GestureDetector(
      onTap: () => _showGroupDetail(group),
      child: Row(
        children: [
          SizedBox(width: firstListElement ? 16 : 0),
          SizedBox(
            width: 120,
            height: 120,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 24,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(height: 4),
                    Text(
                      group.name ?? '?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.totalKcal.toInt()} ${S.of(context).kcalLabel}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupDetail(_IntakeGroup group) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name ?? 'Meal',
                  style: Theme.of(ctx).textTheme.titleLarge),
              Text('${group.totalKcal.toInt()} ${S.of(ctx).kcalLabel}',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              const Divider(),
              ...group.intakes.map((intake) => ListTile(
                    dense: true,
                    title: Text(intake.meal.name ?? '?'),
                    trailing: Text(
                        '${intake.amount.toInt()}g · ${intake.totalKcal.toInt()} kcal'),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _onPlaceholderCardTapped(BuildContext context) {
    Navigator.pushNamed(context, NavigationOptions.mealEntryRoute,
        arguments: MealEntryScreenArguments(widget.addMealType, widget.day));
  }

  void _onItemDropped(IntakeEntity entity) {
    _mealDetailBloc.addIntake(context, entity.unit, entity.amount.toString(),
        widget.addMealType.getIntakeType(), entity.meal, entity.dateTime);
    _homeBloc.deleteIntakeItem(entity);

    // Refresh Home Page
    locator<HomeBloc>().add(const LoadItemsEvent());

    // Refresh Diary Page
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }
}

class _IntakeGroup {
  final String? name;
  final List<IntakeEntity> intakes;

  _IntakeGroup({required this.name, required this.intakes});

  bool get isGrouped => intakes.length > 1 && name != null;

  double get totalKcal =>
      intakes.fold(0, (sum, i) => sum + i.totalKcal);

  /// Returns the first intake (used for display when collapsed)
  IntakeEntity get primary => intakes.first;
}
