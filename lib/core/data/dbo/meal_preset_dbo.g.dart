// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_preset_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealPresetDBOAdapter extends TypeAdapter<MealPresetDBO> {
  @override
  final int typeId = 15;

  @override
  MealPresetDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPresetDBO(
      id: fields[0] as String,
      name: fields[1] as String,
      items: (fields[2] as List).cast<MealPresetItemDBO>(),
    );
  }

  @override
  void write(BinaryWriter writer, MealPresetDBO obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPresetDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealPresetItemDBOAdapter extends TypeAdapter<MealPresetItemDBO> {
  @override
  final int typeId = 16;

  @override
  MealPresetItemDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPresetItemDBO(
      meal: fields[0] as MealDBO,
      amount: fields[1] as double,
      unit: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MealPresetItemDBO obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.meal)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPresetItemDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
