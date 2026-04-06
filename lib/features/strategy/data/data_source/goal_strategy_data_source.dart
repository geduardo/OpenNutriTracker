import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';

class GoalStrategyDataSource {
  static const _strategyKey = 'CurrentGoalStrategy';

  final _log = Logger('GoalStrategyDataSource');
  final Box<GoalStrategyDBO> _box;

  GoalStrategyDataSource(this._box);

  Future<GoalStrategyDBO?> getCurrentStrategy() async {
    return _box.get(_strategyKey);
  }

  Future<void> saveCurrentStrategy(GoalStrategyDBO strategy) async {
    _log.fine('Saving current goal strategy');
    await _box.put(_strategyKey, strategy);
  }

  Future<void> clear() async {
    await _box.delete(_strategyKey);
  }
}
