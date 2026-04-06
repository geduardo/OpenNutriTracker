import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';

class GetKcalGoalUsecase {
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;

  GetKcalGoalUsecase(this._userRepository, this._configRepository);

  Future<double> getKcalGoal(
      {UserEntity? userEntity, double? kcalUserAdjustment}) async {
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();
    return CalorieGoalCalc.getTotalKcalGoal(user, 0,
        kcalUserAdjustment: config.userKcalAdjustment);
  }
}
