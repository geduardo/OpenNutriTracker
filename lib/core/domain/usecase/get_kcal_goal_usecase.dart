import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';

class GetKcalGoalUsecase {
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;
  final ExpenditureStateDataSource _expenditureDataSource;

  GetKcalGoalUsecase(
      this._userRepository, this._configRepository, this._expenditureDataSource);

  /// Returns the current calorie goal.
  /// If adaptive mode is active and has a usable estimate, returns that.
  /// Otherwise falls back to static TDEE calculation.
  Future<double> getKcalGoal(
      {UserEntity? userEntity, double? kcalUserAdjustment}) async {
    // Try adaptive first
    final latestState = await _expenditureDataSource.getLatestState();
    if (latestState != null) {
      final state = ExpenditureStateEntity.fromDBO(latestState);
      if (state.status == ExpenditureStatus.updating) {
        // Use the estimated expenditure as the base
        // The weekly controller adjusts this; here we just return what's set
        return state.estimatedExpenditureKcal;
      }
    }

    // Fall back to static TDEE
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();
    return CalorieGoalCalc.getTotalKcalGoal(user, 0,
        kcalUserAdjustment: config.userKcalAdjustment);
  }

  /// Returns the static TDEE regardless of adaptive state.
  /// Used for seeding the expenditure estimator.
  Future<double> getStaticTdee({UserEntity? userEntity}) async {
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();
    return CalorieGoalCalc.getTotalKcalGoal(user, 0,
        kcalUserAdjustment: config.userKcalAdjustment);
  }
}
