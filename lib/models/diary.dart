import 'package:hive/hive.dart';

part 'diary.g.dart';

@HiveType(typeId: 1)
class DiaryEntry {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final String location;
  @HiveField(3)
  final String content;
  @HiveField(4)
  final List<String> tags;
  @HiveField(5)
  final bool isHighlight;
  @HiveField(6)
  final String? imagePath;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.location,
    required this.content,
    required this.tags,
    this.isHighlight = false,
    this.imagePath,
  });

  DateTime get dateTime => date;

  String get dateString => '${date.year}年${date.month}月${date.day}日';

  bool get isEmptyOrGeneric => content.contains('[description') || content == '在${date.year}年${date.month}月${date.day}日，记录下这一刻的美好。';

  DiaryEntry copyWith({
    String? id,
    DateTime? date,
    String? location,
    String? content,
    List<String>? tags,
    bool? isHighlight,
    String? imagePath,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      location: location ?? this.location,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      isHighlight: isHighlight ?? this.isHighlight,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

@HiveType(typeId: 2)
class WeeklySummary {
  @HiveField(0)
  final int weekNumber;
  @HiveField(1)
  final int photoCount;

  WeeklySummary({
    required this.weekNumber,
    required this.photoCount,
  });
}

@HiveType(typeId: 3)
class MonthlyDiary {
  @HiveField(0)
  final int year;
  @HiveField(1)
  final int month;
  @HiveField(2)
  final String narrative;
  @HiveField(3)
  final List<String> entryIds;
  @HiveField(4)
  final int photosCount;
  @HiveField(5)
  final int travelDays;
  @HiveField(6)
  final int eventsCount;
  @HiveField(7)
  final String mood;
  @HiveField(8)
  final String weather;
  @HiveField(9)
  final int totalSteps;
  @HiveField(10)
  final String monthlySummary;
  @HiveField(11)
  final List<String> keywords;
  @HiveField(12)
  final List<WeeklySummary> weeks;
  @HiveField(13)
  final List<DiaryEntry> entries;

  MonthlyDiary({
    required this.year,
    required this.month,
    required this.narrative,
    required this.entryIds,
    required this.photosCount,
    required this.travelDays,
    required this.eventsCount,
    required this.mood,
    required this.weather,
    required this.totalSteps,
    required this.monthlySummary,
    required this.keywords,
    required this.weeks,
    required this.entries,
  });
}