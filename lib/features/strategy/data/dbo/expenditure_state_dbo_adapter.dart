part of 'expenditure_state_dbo.dart';

class ExpenditureStateDBOAdapter extends TypeAdapter<ExpenditureStateDBO> {
  @override
  final int typeId = 22;

  @override
  ExpenditureStateDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenditureStateDBO(
      day: fields[0] as DateTime,
      estimatedExpenditureKcal: fields[1] as double,
      rawExpenditureKcal: fields[2] as double,
      confidence: fields[3] as double,
      status: fields[4] as ExpenditureStatusDBO,
      validNutritionDays: fields[5] as int,
      recentWeighInCount: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenditureStateDBO obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.estimatedExpenditureKcal)
      ..writeByte(2)
      ..write(obj.rawExpenditureKcal)
      ..writeByte(3)
      ..write(obj.confidence)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.validNutritionDays)
      ..writeByte(6)
      ..write(obj.recentWeighInCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenditureStateDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExpenditureStatusDBOAdapter extends TypeAdapter<ExpenditureStatusDBO> {
  @override
  final int typeId = 23;

  @override
  ExpenditureStatusDBO read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpenditureStatusDBO.seeded;
      case 1:
        return ExpenditureStatusDBO.holding;
      case 2:
        return ExpenditureStatusDBO.updating;
      default:
        return ExpenditureStatusDBO.seeded;
    }
  }

  @override
  void write(BinaryWriter writer, ExpenditureStatusDBO obj) {
    switch (obj) {
      case ExpenditureStatusDBO.seeded:
        writer.writeByte(0);
        break;
      case ExpenditureStatusDBO.holding:
        writer.writeByte(1);
        break;
      case ExpenditureStatusDBO.updating:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenditureStatusDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
