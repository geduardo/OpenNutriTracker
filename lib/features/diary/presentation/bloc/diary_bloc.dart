import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/reconcile_tracked_days_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';

part 'diary_event.dart';

part 'diary_state.dart';

class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  final GetConfigUsecase _getConfigUsecase;
  final ReconcileTrackedDaysUsecase _reconcileTrackedDaysUsecase;

  DateTime currentDay = DateTime.now();

  DiaryBloc(this._getConfigUsecase, this._reconcileTrackedDaysUsecase)
      : super(DiaryInitial()) {
    on<LoadDiaryYearEvent>((event, emit) async {
      emit(DiaryLoadingState());

      final usesImperialUnits =
          (await _getConfigUsecase.getConfig()).usesImperialUnits;

      currentDay = DateTime.now();
      const yearDuration = Duration(days: 365);
      final correctedDays =
          await _reconcileTrackedDaysUsecase.reconcileTrackedDaysByRange(
        currentDay.subtract(yearDuration),
        currentDay.add(yearDuration),
      );
      final correctedMap = {
        for (final trackedDay in correctedDays)
          trackedDay.day.toParsedDay(): trackedDay
      };

      emit(DiaryLoadedState(correctedMap, usesImperialUnits));
    });
  }

  void updateHomePage() {
    locator<HomeBloc>().add(const LoadItemsEvent());
  }
}
