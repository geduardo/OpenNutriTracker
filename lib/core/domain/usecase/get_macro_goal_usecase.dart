import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/features/strategy/data/data_source/goal_strategy_data_source.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/service/macro_program_service.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';

class GetMacroGoalUsecase {
  final ConfigRepository _configRepository;
  final GoalStrategyDataSource _goalStrategyDataSource;
  final WeightEntryRepository _weightEntryRepository;
  final UserRepository _userRepository;

  GetMacroGoalUsecase(this._configRepository, this._goalStrategyDataSource,
      this._weightEntryRepository, this._userRepository);

  Future<double> getCarbsGoal(double totalCalorieGoal) async {
    final adaptiveTargets = await _getAdaptiveTargets(totalCalorieGoal);
    if (adaptiveTargets != null) {
      return adaptiveTargets.carbsG;
    }

    final config = await _configRepository.getConfig();
    return MacroCalc.getTotalCarbsGoal(totalCalorieGoal,
        userCarbsGoal: config.userCarbGoalPct);
  }

  Future<double> getFatsGoal(double totalCalorieGoal) async {
    final adaptiveTargets = await _getAdaptiveTargets(totalCalorieGoal);
    if (adaptiveTargets != null) {
      return adaptiveTargets.fatG;
    }

    final config = await _configRepository.getConfig();
    return MacroCalc.getTotalFatsGoal(totalCalorieGoal,
        userFatsGoal: config.userFatGoalPct);
  }

  Future<double> getProteinsGoal(double totalCalorieGoal) async {
    final adaptiveTargets = await _getAdaptiveTargets(totalCalorieGoal);
    if (adaptiveTargets != null) {
      return adaptiveTargets.proteinG;
    }

    final config = await _configRepository.getConfig();
    return MacroCalc.getTotalProteinsGoal(totalCalorieGoal,
        userProteinsGoal: config.userProteinGoalPct);
  }

  Future<MacroTargets?> _getAdaptiveTargets(double totalCalorieGoal) async {
    final strategy = await _goalStrategyDataSource.getCurrentStrategy();
    if (strategy == null ||
        strategy.macroStyle == MacroProgramStyleDBO.manual) {
      return null;
    }

    final entries = await _weightEntryRepository.getAllEntries();
    final latestTrendWeight = TrendWeightService.getLatestTrendWeight(entries);
    final latestEntry = entries.isNotEmpty ? entries.last.weightKg : null;
    final currentWeightKg = latestTrendWeight ??
        latestEntry ??
        (await _userRepository.getUserData()).weightKG;

    return MacroProgramService.computeMacros(
      calorieTarget: totalCalorieGoal,
      bodyWeightKg: currentWeightKg,
      style: _mapStyle(strategy.macroStyle),
    );
  }

  MacroStyle _mapStyle(MacroProgramStyleDBO style) => switch (style) {
        MacroProgramStyleDBO.balanced => MacroStyle.balanced,
        MacroProgramStyleDBO.highCarbLowFat => MacroStyle.highCarbLowFat,
        MacroProgramStyleDBO.lowCarbHighFat => MacroStyle.lowCarbHighFat,
        MacroProgramStyleDBO.manual => MacroStyle.manual,
      };
}
