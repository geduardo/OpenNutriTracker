part of 'check_in_record_dbo.dart';

class CheckInRecordDBOAdapter extends TypeAdapter<CheckInRecordDBO> {
  @override
  final int typeId = 27;

  @override
  CheckInRecordDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CheckInRecordDBO(
      weekStart: fields[0] as DateTime,
      previousCalorieTarget: fields[1] as double,
      proposedCalorieTarget: fields[2] as double,
      appliedCalorieTarget: fields[3] as double,
      dismissed: fields[4] as bool,
      expenditureAtCheckIn: fields[5] as double,
      trendWeightAtCheckIn: fields[6] as double,
      confidenceAtCheckIn: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CheckInRecordDBO obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.weekStart)
      ..writeByte(1)
      ..write(obj.previousCalorieTarget)
      ..writeByte(2)
      ..write(obj.proposedCalorieTarget)
      ..writeByte(3)
      ..write(obj.appliedCalorieTarget)
      ..writeByte(4)
      ..write(obj.dismissed)
      ..writeByte(5)
      ..write(obj.expenditureAtCheckIn)
      ..writeByte(6)
      ..write(obj.trendWeightAtCheckIn)
      ..writeByte(7)
      ..write(obj.confidenceAtCheckIn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInRecordDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
