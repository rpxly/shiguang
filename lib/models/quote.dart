import 'package:hive/hive.dart';

part 'quote.g.dart';

@HiveType(typeId: 19)
class Quote {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String text;
  @HiveField(2)
  final String? author;
  @HiveField(3)
  final String? source;
  @HiveField(4)
  final String category;
  @HiveField(5)
  final bool isAiGenerated;
  @HiveField(6)
  final DateTime createdAt;

  Quote({
    required this.id,
    required this.text,
    this.author,
    this.source,
    required this.category,
    this.isAiGenerated = false,
    required this.createdAt,
  });

  DateTime get createdDateTime => createdAt;

  Quote copyWith({
    String? id,
    String? text,
    String? author,
    String? source,
    String? category,
    bool? isAiGenerated,
    DateTime? createdAt,
  }) {
    return Quote(
      id: id ?? this.id,
      text: text ?? this.text,
      author: author ?? this.author,
      source: source ?? this.source,
      category: category ?? this.category,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      createdAt: createdAt ?? createdDateTime,
    );
  }
}
