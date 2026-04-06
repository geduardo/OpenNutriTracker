part of 'day_log_quality_dbo.dart';

class DayLogQualityDBOAdapter extends TypeAdapter<DayLogQualityDBO> {
  @override
  final int typeId = 21;

  @override
  DayLogQualityDBO read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DayLogQualityDBO.complete;
      case 1:
        return DayLogQualityDBO.partial;
      case 2:
        return DayLogQualityDBO.unlogged;
      case 3:
        return DayLogQualityDBO.fasted;
      default:
        return DayLogQualityDBO.unlogged;
    }
  }

  @override
  void write(BinaryWriter writer, DayLogQualityDBO obj) {
    switch (obj) {
      case DayLogQualityDBO.complete:
        writer.writeByte(0);
        break;
      case DayLogQualityDBO.partial:
        writer.writeByte(1);
        break;
      case DayLogQualityDBO.unlogged:
        writer.writeByte(2);
        break;
      case DayLogQualityDBO.fasted:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayLogQualityDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
