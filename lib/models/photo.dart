import 'package:hive/hive.dart';

part 'photo.g.dart';

@HiveType(typeId: 0)
class Photo {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String path;
  @HiveField(2)
  final String thumbnailPath;
  @HiveField(3)
  final int date;
  @HiveField(4)
  final String? location;
  @HiveField(5)
  final String? category;
  @HiveField(6)
  final int fileSize;
  @HiveField(7)
  bool isSelected;
  /// ML Kit 图像标签列表
  @HiveField(8)
  List<String> mlKitLabels;
  /// 是否检测到人脸
  @HiveField(9)
  bool hasFace;
  /// 检测到的人脸数量
  @HiveField(10)
  int faceCount;
  /// ML Kit 最高标签置信度
  @HiveField(11)
  double mlKitConfidence;
  /// 用户手动收藏/精选标记
  @HiveField(12)
  bool isFavorite;
  /// AI 质量评分 0-100（综合分辨率、清晰度、构图、人脸质量）
  @HiveField(13)
  int qualityScore;
  /// 用户手动整理标记（空字符串=未整理；'keep'=已保留）
  @HiveField(14)
  String userMark;

  Photo({
    required this.id,
    required this.path,
    required this.thumbnailPath,
    required DateTime date,
    this.location,
    this.category,
    required this.fileSize,
    this.isSelected = false,
    this.mlKitLabels = const [],
    this.hasFace = false,
    this.faceCount = 0,
    this.mlKitConfidence = 0.0,
    this.isFavorite = false,
    this.qualityScore = 0,
    this.userMark = '',
  }) : date = date.millisecondsSinceEpoch;

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(date);

  bool get isLocalFile => !path.startsWith('assets/');

  bool get isAssetPath => path.startsWith('assets/');

  Photo copyWith({
    String? id,
    String? path,
    String? thumbnailPath,
    DateTime? date,
    String? location,
    String? category,
    int? fileSize,
    bool? isSelected,
    List<String>? mlKitLabels,
    bool? hasFace,
    int? faceCount,
    double? mlKitConfidence,
    bool? isFavorite,
    int? qualityScore,
    String? userMark,
  }) {
    return Photo(
      id: id ?? this.id,
      path: path ?? this.path,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      date: date ?? dateTime,
      location: location ?? this.location,
      category: category ?? this.category,
      fileSize: fileSize ?? this.fileSize,
      isSelected: isSelected ?? this.isSelected,
      mlKitLabels: mlKitLabels ?? this.mlKitLabels,
      hasFace: hasFace ?? this.hasFace,
      faceCount: faceCount ?? this.faceCount,
      mlKitConfidence: mlKitConfidence ?? this.mlKitConfidence,
      isFavorite: isFavorite ?? this.isFavorite,
      qualityScore: qualityScore ?? this.qualityScore,
      userMark: userMark ?? this.userMark,
    );
  }
}