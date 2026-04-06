part of 'local_food_record_dbo.dart';

class LocalFoodRecordDBOAdapter extends TypeAdapter<LocalFoodRecordDBO> {
  @override
  final int typeId = 28;

  @override
  LocalFoodRecordDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalFoodRecordDBO(
      id: fields[0] as String,
      meal: fields[1] as MealDBO,
      aliases: (fields[2] as List).cast<String>(),
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LocalFoodRecordDBO obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.meal)
      ..writeByte(2)
      ..write(obj.aliases)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalFoodRecordDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
