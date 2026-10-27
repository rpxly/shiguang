class Album {
  final String id;
  String name;
  int order;
  String? coverPath;
  bool isLocalSync;
  String? localAlbumId;

  /// 物理目录（如 `Pictures/拾光/旅行`）。
  /// 为 null 表示「草稿相簿」：只在 App 内存在，还没有照片落盘。
  String? relativePath;
  DateTime createdAt;

  Album({
    required this.id,
    required this.name,
    this.order = 0,
    this.coverPath,
    this.isLocalSync = false,
    this.localAlbumId,
    this.relativePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 是否已经在系统相册里落成真实目录
  bool get isPhysical => (relativePath ?? '').isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order,
    'coverPath': coverPath,
    'isLocalSync': isLocalSync,
    'localAlbumId': localAlbumId,
    'relativePath': relativePath,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    id: json['id'] as String,
    name: json['name'] as String,
    order: json['order'] as int? ?? 0,
    coverPath: json['coverPath'] as String?,
    isLocalSync: json['isLocalSync'] as bool? ?? false,
    localAlbumId: json['localAlbumId'] as String?,
    relativePath: json['relativePath'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );

  Album copyWith({
    String? id,
    String? name,
    int? order,
    String? coverPath,
    bool? isLocalSync,
    String? localAlbumId,
    String? relativePath,
    DateTime? createdAt,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      coverPath: coverPath ?? this.coverPath,
      isLocalSync: isLocalSync ?? this.isLocalSync,
      localAlbumId: localAlbumId ?? this.localAlbumId,
      relativePath: relativePath ?? this.relativePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
