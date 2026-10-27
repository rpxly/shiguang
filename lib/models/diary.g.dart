// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiaryEntryAdapter extends TypeAdapter<DiaryEntry> {
  @override
  final int typeId = 1;

  @override
  DiaryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      location: fields[2] as String,
      content: fields[3] as String,
      tags: (fields[4] as List).cast<String>(),
      isHighlight: fields[5] as bool,
      imagePath: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.isHighlight)
      ..writeByte(6)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeeklySummaryAdapter extends TypeAdapter<WeeklySummary> {
  @override
  final int typeId = 2;

  @override
  WeeklySummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklySummary(
      weekNumber: fields[0] as int,
      photoCount: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WeeklySummary obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.weekNumber)
      ..writeByte(1)
      ..write(obj.photoCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklySummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MonthlyDiaryAdapter extends TypeAdapter<MonthlyDiary> {
  @override
  final int typeId = 3;

  @override
  MonthlyDiary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyDiary(
      year: fields[0] as int,
      month: fields[1] as int,
      narrative: fields[2] as String,
      entryIds: (fields[3] as List).cast<String>(),
      photosCount: fields[4] as int,
      travelDays: fields[5] as int,
      eventsCount: fields[6] as int,
      mood: fields[7] as String,
      weather: fields[8] as String,
      totalSteps: fields[9] as int,
      monthlySummary: fields[10] as String,
      keywords: (fields[11] as List).cast<String>(),
      weeks: (fields[12] as List).cast<WeeklySummary>(),
      entries: (fields[13] as List).cast<DiaryEntry>(),
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyDiary obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.month)
      ..writeByte(2)
      ..write(obj.narrative)
      ..writeByte(3)
      ..write(obj.entryIds)
      ..writeByte(4)
      ..write(obj.photosCount)
      ..writeByte(5)
      ..write(obj.travelDays)
      ..writeByte(6)
      ..write(obj.eventsCount)
      ..writeByte(7)
      ..write(obj.mood)
      ..writeByte(8)
      ..write(obj.weather)
      ..writeByte(9)
      ..write(obj.totalSteps)
      ..writeByte(10)
      ..write(obj.monthlySummary)
      ..writeByte(11)
      ..write(obj.keywords)
      ..writeByte(12)
      ..write(obj.weeks)
      ..writeByte(13)
      ..write(obj.entries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyDiaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
