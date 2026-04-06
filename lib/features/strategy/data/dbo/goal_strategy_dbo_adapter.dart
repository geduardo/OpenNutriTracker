part of 'goal_strategy_dbo.dart';

class GoalStrategyDBOAdapter extends TypeAdapter<GoalStrategyDBO> {
  @override
  final int typeId = 24;

  @override
  GoalStrategyDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalStrategyDBO(
      mode: fields[0] as StrategyGoalModeDBO,
      targetWeightKg: fields[1] as double?,
      targetRatePctPerWeek: fields[2] as double,
      macroStyle: fields[3] as MacroProgramStyleDBO,
      adaptiveEnabled: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GoalStrategyDBO obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.mode)
      ..writeByte(1)
      ..write(obj.targetWeightKg)
      ..writeByte(2)
      ..write(obj.targetRatePctPerWeek)
      ..writeByte(3)
      ..write(obj.macroStyle)
      ..writeByte(4)
      ..write(obj.adaptiveEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalStrategyDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StrategyGoalModeDBOAdapter extends TypeAdapter<StrategyGoalModeDBO> {
  @override
  final int typeId = 25;

  @override
  StrategyGoalModeDBO read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return StrategyGoalModeDBO.lose;
      case 1: return StrategyGoalModeDBO.maintain;
      case 2: return StrategyGoalModeDBO.gain;
      default: return StrategyGoalModeDBO.maintain;
    }
  }

  @override
  void write(BinaryWriter writer, StrategyGoalModeDBO obj) {
    switch (obj) {
      case StrategyGoalModeDBO.lose: writer.writeByte(0); break;
      case StrategyGoalModeDBO.maintain: writer.writeByte(1); break;
      case StrategyGoalModeDBO.gain: writer.writeByte(2); break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrategyGoalModeDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MacroProgramStyleDBOAdapter extends TypeAdapter<MacroProgramStyleDBO> {
  @override
  final int typeId = 26;

  @override
  MacroProgramStyleDBO read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return MacroProgramStyleDBO.balanced;
      case 1: return MacroProgramStyleDBO.highCarbLowFat;
      case 2: return MacroProgramStyleDBO.lowCarbHighFat;
      case 3: return MacroProgramStyleDBO.manual;
      default: return MacroProgramStyleDBO.balanced;
    }
  }

  @override
  void write(BinaryWriter writer, MacroProgramStyleDBO obj) {
    switch (obj) {
      case MacroProgramStyleDBO.balanced: writer.writeByte(0); break;
      case MacroProgramStyleDBO.highCarbLowFat: writer.writeByte(1); break;
      case MacroProgramStyleDBO.lowCarbHighFat: writer.writeByte(2); break;
      case MacroProgramStyleDBO.manual: writer.writeByte(3); break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroProgramStyleDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
