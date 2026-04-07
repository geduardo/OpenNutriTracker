import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/day_navigation_bar.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_histogram_chart.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/day_info_widget.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> with WidgetsBindingObserver {
  final log = Logger('DiaryPage');

  late DiaryBloc _diaryBloc;
  late CalendarDayBloc _calendarDayBloc;
  late MealDetailBloc _mealDetailBloc;

  var _selectedDate = DateUtils.dateOnly(DateTime.now());
  // +1 = new day is later than previous (slide in from right)
  // -1 = new day is earlier than previous (slide in from left)
  // 0 = first build / no animation
  int _slideDirection = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _diaryBloc = locator<DiaryBloc>();
    _calendarDayBloc = locator<CalendarDayBloc>();
    _mealDetailBloc = locator<MealDetailBloc>();
    // Both blocs are lazy singletons (see locator.dart) so they survive page
    // recreations. Always force a fresh load on entry to avoid showing stale
    // data from a previous diary visit (e.g. after meals were added via the
    // home page in between).
    _diaryBloc.add(const LoadDiaryYearEvent());
    _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiaryBloc, DiaryState>(
      bloc: _diaryBloc,
      // Don't flash a full-screen spinner during silent refreshes — keep the
      // previous loaded frame visible until the new data arrives.
      buildWhen: (previous, current) {
        if (current is DiaryLoadingState && previous is DiaryLoadedState) {
          return false;
        }
        return true;
      },
      builder: (context, state) {
        if (state is DiaryLoadingState || state is DiaryInitial) {
          return _getLoadingContent();
        } else if (state is DiaryLoadedState) {
          return _getLoadedContent(
              context, state.trackedDayMap, state.usesImperialUnits);
        }
        return const SizedBox();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log.info('App resumed');
      // Snap back to today on resume — handles overnight rollover where the
      // user left the app on "today" and the calendar day has since changed.
      final today = DateUtils.dateOnly(DateTime.now());
      setState(() {
        _slideDirection = 0;
        _selectedDate = today;
      });
      _calendarDayBloc.add(LoadCalendarDayEvent(today));
      _diaryBloc.add(const LoadDiaryYearEvent());
    }
    super.didChangeAppLifecycleState(state);
  }

  Widget _getLoadingContent() =>
      const Center(child: CircularProgressIndicator());

  Widget _getLoadedContent(BuildContext context,
      Map<String, TrackedDayEntity> trackedDaysMap, bool usesImperialUnits) {
    return ListView(
      children: [
        DayNavigationBar(
          selectedDate: _selectedDate,
          onDateChanged: _selectDate,
        ),
        BlocBuilder<CalendarDayBloc, CalendarDayState>(
          bloc: _calendarDayBloc,
          // Same trick as the outer DiaryBloc — keep the previous loaded
          // frame visible during a silent refresh on tab re-entry.
          buildWhen: (previous, current) {
            if (current is CalendarDayLoading && previous is CalendarDayLoaded) {
              return false;
            }
            return true;
          },
          builder: (context, state) {
            if (state is CalendarDayLoading || state is CalendarDayInitial) {
              // Fixed-height placeholder to prevent the histogram below from
              // popping up during the first load.
              return const SizedBox(
                height: 480,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (state is CalendarDayLoaded) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _onMealsHorizontalDragEnd,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final dir = _slideDirection;
                    final beginOffset = dir == 0
                        ? Offset.zero
                        : Offset(dir.toDouble() * 0.15, 0);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
                    child: DayInfoWidget(
                      trackedDayEntity: state.trackedDayEntity,
                      selectedDay: _selectedDate,
                      breakfastIntake: state.breakfastIntakeList,
                      lunchIntake: state.lunchIntakeList,
                      dinnerIntake: state.dinnerIntakeList,
                      snackIntake: state.snackIntakeList,
                      onDeleteIntake: _onDeleteIntakeItem,
                      onCopyIntake: _onCopyIntakeItem,
                      usesImperialUnits: usesImperialUnits,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: DiaryHistogramChart(
            trackedDaysMap: trackedDaysMap,
            selectedDate: _selectedDate,
            onDateSelected: _selectDate,
          ),
        ),
      ],
    );
  }

  void _onDeleteIntakeItem(
      IntakeEntity intakeEntity, TrackedDayEntity? trackedDayEntity) async {
    await _calendarDayBloc.deleteIntakeItem(
        context, intakeEntity, trackedDayEntity?.day ?? DateTime.now());
    _diaryBloc.add(const LoadDiaryYearEvent());
    _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
    _diaryBloc.updateHomePage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemDeletedSnackbar)));
    }
  }

  void _onCopyIntakeItem(IntakeEntity intakeEntity,
      TrackedDayEntity? trackedDayEntity, AddMealType? type) async {
    IntakeTypeEntity finalType;
    if (type == null) {
      finalType = intakeEntity.type;
    } else {
      finalType = type.getIntakeType();
    }
    await _mealDetailBloc.addIntake(
        context,
        intakeEntity.unit,
        intakeEntity.amount.toString(),
        finalType,
        intakeEntity.meal,
        DateTime.now());
    _diaryBloc.add(const LoadDiaryYearEvent());
    _calendarDayBloc.add(LoadCalendarDayEvent(_selectedDate));
    _diaryBloc.updateHomePage();
  }

  void _selectDate(DateTime newDate) {
    final normalized = DateUtils.dateOnly(newDate);
    if (DateUtils.isSameDay(normalized, _selectedDate)) {
      return;
    }
    final direction = normalized.isAfter(_selectedDate) ? 1 : -1;
    setState(() {
      _slideDirection = direction;
      _selectedDate = normalized;
    });
    _calendarDayBloc.add(LoadCalendarDayEvent(normalized));
  }

  void _onMealsHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity.abs() < 250) {
      return;
    }
    // Swipe left (negative velocity) → next day; swipe right → previous day.
    final delta = velocity < 0 ? 1 : -1;
    final today = DateUtils.dateOnly(DateTime.now());
    if (delta > 0 && DateUtils.isSameDay(_selectedDate, today)) {
      // Don't allow swiping into the future.
      return;
    }
    final next = DateUtils.addDaysToDate(_selectedDate, delta);
    _selectDate(next);
  }
}
