// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoAdapter extends TypeAdapter<Photo> {
  @override
  final int typeId = 0;

  @override
  Photo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Photo(
      id: fields[0] as String,
      path: fields[1] as String,
      thumbnailPath: fields[2] as String,
      date: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      location: fields[4] as String?,
      category: fields[5] as String?,
      fileSize: fields[6] as int,
      isSelected: fields[7] as bool,
      mlKitLabels: (fields[8] as List).cast<String>(),
      hasFace: fields[9] as bool,
      faceCount: fields[10] as int,
      mlKitConfidence: fields[11] as double,
      isFavorite: fields[12] as bool,
      qualityScore: fields[13] as int,
      userMark: fields[14] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Photo obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.thumbnailPath)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.fileSize)
      ..writeByte(7)
      ..write(obj.isSelected)
      ..writeByte(8)
      ..write(obj.mlKitLabels)
      ..writeByte(9)
      ..write(obj.hasFace)
      ..writeByte(10)
      ..write(obj.faceCount)
      ..writeByte(11)
      ..write(obj.mlKitConfidence)
      ..writeByte(12)
      ..write(obj.isFavorite)
      ..writeByte(13)
      ..write(obj.qualityScore)
      ..writeByte(14)
      ..write(obj.userMark);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
