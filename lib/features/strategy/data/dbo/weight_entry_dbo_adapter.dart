part of 'weight_entry_dbo.dart';

class WeightEntryDBOAdapter extends TypeAdapter<WeightEntryDBO> {
  @override
  final int typeId = 19;

  @override
  WeightEntryDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeightEntryDBO(
      day: fields[0] as DateTime,
      weightKg: fields[1] as double,
      note: fields[2] as String?,
      source: fields[3] as WeightEntrySourceDBO,
    );
  }

  @override
  void write(BinaryWriter writer, WeightEntryDBO obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.weightKg)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightEntryDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeightEntrySourceDBOAdapter extends TypeAdapter<WeightEntrySourceDBO> {
  @override
  final int typeId = 20;

  @override
  WeightEntrySourceDBO read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WeightEntrySourceDBO.manual;
      case 1:
        return WeightEntrySourceDBO.migratedProfileWeight;
      case 2:
        return WeightEntrySourceDBO.healthConnect;
      default:
        return WeightEntrySourceDBO.manual;
    }
  }

  @override
  void write(BinaryWriter writer, WeightEntrySourceDBO obj) {
    switch (obj) {
      case WeightEntrySourceDBO.manual:
        writer.writeByte(0);
        break;
      case WeightEntrySourceDBO.migratedProfileWeight:
        writer.writeByte(1);
        break;
      case WeightEntrySourceDBO.healthConnect:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightEntrySourceDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
