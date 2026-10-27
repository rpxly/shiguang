// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuoteAdapter extends TypeAdapter<Quote> {
  @override
  final int typeId = 19;

  @override
  Quote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Quote(
      id: fields[0] as String,
      text: fields[1] as String,
      author: fields[2] as String?,
      source: fields[3] as String?,
      category: fields[4] as String,
      isAiGenerated: fields[5] as bool,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Quote obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.isAiGenerated)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
