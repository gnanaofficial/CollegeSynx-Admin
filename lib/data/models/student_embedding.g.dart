// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_embedding.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentEmbeddingAdapter extends TypeAdapter<StudentEmbedding> {
  @override
  final int typeId = 0;

  @override
  StudentEmbedding read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentEmbedding(
      rollNo: fields[0] as String,
      name: fields[1] as String,
      dept: fields[2] as String,
      batch: fields[3] as String,
      branch: fields[4] as String,
      embedding1: (fields[5] as List).cast<double>(),
      embedding2: (fields[6] as List).cast<double>(),
      embedding3: (fields[7] as List).cast<double>(),
      lastUpdated: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StudentEmbedding obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.rollNo)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dept)
      ..writeByte(3)
      ..write(obj.batch)
      ..writeByte(4)
      ..write(obj.branch)
      ..writeByte(5)
      ..write(obj.embedding1)
      ..writeByte(6)
      ..write(obj.embedding2)
      ..writeByte(7)
      ..write(obj.embedding3)
      ..writeByte(8)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentEmbeddingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
