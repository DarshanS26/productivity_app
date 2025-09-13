// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArchivedTaskAdapter extends TypeAdapter<ArchivedTask> {
  @override
  final int typeId = 3;

  @override
  ArchivedTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArchivedTask(
      id: fields[0] as String,
      title: fields[1] as String,
      isDone: fields[2] as bool,
      createdAt: fields[3] as DateTime,
      dueTime: fields[4] as TimeOfDay?,
      plannedHours: fields[5] as double,
      completionDescription: fields[6] as String?,
      rating: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ArchivedTask obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isDone)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.dueTime)
      ..writeByte(5)
      ..write(obj.plannedHours)
      ..writeByte(6)
      ..write(obj.completionDescription)
      ..writeByte(7)
      ..write(obj.rating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArchivedTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
