import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/features/strategy/domain/usecase/get_adaptive_strategy_snapshot_usecase.dart';

class GetKcalGoalUsecase {
  final GetAdaptiveStrategySnapshotUsecase _getAdaptiveStrategySnapshotUsecase;
  final UserRepository _userRepository;

  GetKcalGoalUsecase(
      this._getAdaptiveStrategySnapshotUsecase, this._userRepository);

  Future<double> getKcalGoal(
      {UserEntity? userEntity, double? kcalUserAdjustment}) async {
    final snapshot = await _getAdaptiveStrategySnapshotUsecase.getSnapshot(
      userEntity: userEntity,
    );
    return snapshot.calorieTarget;
  }

  Future<double> getStaticTdee({UserEntity? userEntity}) async {
    final user = userEntity ?? await _userRepository.getUserData();
    return CalorieGoalCalc.getTdee(user);
  }
}
