import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';

part 'diary_event.dart';

part 'diary_state.dart';

class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  static final _log = Logger('DiaryBloc');

  final GetTrackedDayUsecase _getDayTrackedUsecase;
  final GetConfigUsecase _getConfigUsecase;
  final GetIntakeUsecase _getIntakeUsecase;
  final AddTrackedDayUsecase _addTrackedDayUsecase;

  DateTime currentDay = DateTime.now();

  DiaryBloc(this._getDayTrackedUsecase, this._getConfigUsecase,
      this._getIntakeUsecase, this._addTrackedDayUsecase)
      : super(DiaryInitial()) {
    on<LoadDiaryYearEvent>((event, emit) async {
      emit(DiaryLoadingState());

      final usesImperialUnits =
          (await _getConfigUsecase.getConfig()).usesImperialUnits;

      currentDay = DateTime.now();
      const yearDuration = Duration(days: 356);

      final trackedDays = await _getDayTrackedUsecase.getTrackedDaysByRange(
          currentDay.subtract(yearDuration), currentDay.add(yearDuration));

      // Self-heal cache: rebuild aggregates from the authoritative intake
      // list. The increment/decrement bookkeeping done by the add/edit/delete
      // flows can drift over time (failed writes, crashes mid-update, legacy
      // records without macro fields). Rather than chasing down every
      // possible drift cause, we recompute on every diary load and write
      // back to Hive so all consumers (histogram, dashboard, TDEE estimator)
      // see the same correct values.
      final correctedMap = await _selfHealAggregates(trackedDays);

      emit(DiaryLoadedState(correctedMap, usesImperialUnits));
    });
  }

  /// Recomputes per-day aggregates from the actual intake list and persists
  /// any drifts back to Hive. Returns a date-keyed map of corrected entities
  /// for the diary view to render.
  Future<Map<String, TrackedDayEntity>> _selfHealAggregates(
      List<TrackedDayEntity> trackedDays) async {
    // Single Hive scan, then group by day for O(1) lookup per tracked day.
    final allIntakes = await _getIntakeUsecase.getAllIntakes();
    final intakesByDay = <String, List<IntakeEntity>>{};
    for (final intake in allIntakes) {
      final key = intake.dateTime.toParsedDay();
      (intakesByDay[key] ??= <IntakeEntity>[]).add(intake);
    }

    final correctedMap = <String, TrackedDayEntity>{};
    for (final tracked in trackedDays) {
      final key = tracked.day.toParsedDay();
      final dayIntakes = intakesByDay[key] ?? const <IntakeEntity>[];

      double kcal = 0, carbs = 0, fat = 0, protein = 0, sodium = 0, caffeine = 0;
      for (final i in dayIntakes) {
        kcal += i.totalKcal;
        carbs += i.totalCarbsGram;
        fat += i.totalFatsGram;
        protein += i.totalProteinsGram;
        sodium += i.totalSodiumMg;
        caffeine += i.totalCaffeineMg;
      }

      // Detect drift with a small tolerance to ignore floating-point noise.
      const eps = 0.5;
      final drifted = (tracked.caloriesTracked - kcal).abs() > eps ||
          ((tracked.carbsTracked ?? 0) - carbs).abs() > eps ||
          ((tracked.fatTracked ?? 0) - fat).abs() > eps ||
          ((tracked.proteinTracked ?? 0) - protein).abs() > eps ||
          ((tracked.sodiumTracked ?? 0) - sodium).abs() > eps ||
          ((tracked.caffeineTracked ?? 0) - caffeine).abs() > eps;

      if (drifted) {
        _log.info('Self-healing aggregate drift on $key: '
            'kcal ${tracked.caloriesTracked.toInt()} → ${kcal.toInt()}');
        await _addTrackedDayUsecase.setDayAggregates(
          tracked.day,
          caloriesTracked: kcal,
          carbsTracked: carbs,
          fatTracked: fat,
          proteinTracked: protein,
          sodiumTracked: sodium,
          caffeineTracked: caffeine,
        );
      }

      correctedMap[key] = TrackedDayEntity(
        day: tracked.day,
        calorieGoal: tracked.calorieGoal,
        caloriesTracked: kcal,
        carbsGoal: tracked.carbsGoal,
        carbsTracked: carbs,
        fatGoal: tracked.fatGoal,
        fatTracked: fat,
        proteinGoal: tracked.proteinGoal,
        proteinTracked: protein,
        sodiumGoal: tracked.sodiumGoal,
        sodiumTracked: sodium,
        caffeineGoal: tracked.caffeineGoal,
        caffeineTracked: caffeine,
      );
    }
    return correctedMap;
  }

  void updateHomePage() {
    locator<HomeBloc>().add(const LoadItemsEvent());
  }
}
