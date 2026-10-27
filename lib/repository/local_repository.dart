import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';
import '../models/diary.dart';
import '../models/album.dart';
import '../models/scene_tag.dart';

class LocalRepository {
  final Box<Photo> _photoBox;
  final Box<DiaryEntry> _diaryEntryBox;
  final Box<MonthlyDiary> _monthlyDiaryBox;
  final Box _generalBox;
  /// 照片 id → 场景识别记录（独立盒子，避免改动 Photo 的 Hive schema）
  final Box<String> _sceneBox;

  LocalRepository({
    required Box<Photo> photoBox,
    required Box<DiaryEntry> diaryEntryBox,
    required Box<MonthlyDiary> monthlyDiaryBox,
    required Box generalBox,
    required Box<String> sceneBox,
  })  : _photoBox = photoBox,
        _diaryEntryBox = diaryEntryBox,
        _monthlyDiaryBox = monthlyDiaryBox,
        _generalBox = generalBox,
        _sceneBox = sceneBox;

  List<Photo>? _cachedPhotos;
  Map<String, Photo>? _indexById;

  void _invalidateCache() {
    _cachedPhotos = null;
    _indexById = null;
  }

  /// 增量更新缓存与索引，避免每次写入后全表重新反序列化。
  void _upsertInCache(Photo photo) {
    final cached = _cachedPhotos;
    if (cached == null) return;
    final index = _indexById;
    if (index != null) {
      final existing = index[photo.id];
      if (existing != null) {
        cached[cached.indexOf(existing)] = photo;
      } else {
        cached.add(photo);
      }
      index[photo.id] = photo;
    } else {
      // 索引尚未建立：仅当 id 已存在时原位替换，否则追加
      final idx = cached.indexWhere((p) => p.id == photo.id);
      if (idx >= 0) {
        cached[idx] = photo;
      } else {
        cached.add(photo);
      }
    }
  }

  void _removeFromCache(String id) {
    final cached = _cachedPhotos;
    if (cached == null) return;
    cached.removeWhere((p) => p.id == id);
    _indexById?.remove(id);
  }

  List<Photo> getAllPhotos() {
    if (_cachedPhotos != null) return _cachedPhotos!;
    _cachedPhotos = _photoBox.values.toList();
    return _cachedPhotos!;
  }

  /// 一次遍历建立 id → Photo 索引（随缓存复用）。
  Map<String, Photo> indexPhotosById() {
    return _indexById ??= {
      for (final photo in getAllPhotos()) photo.id: photo,
    };
  }

  Photo? getPhoto(String id) => _photoBox.get(id);

  void savePhoto(Photo photo) {
    _photoBox.put(photo.id, photo);
    _upsertInCache(photo);
  }

  void savePhotosBatch(List<Photo> photos) {
    final batch = <String, Photo>{};
    for (final photo in photos) {
      batch[photo.id] = photo;
    }
    _photoBox.putAll(batch);
    for (final photo in photos) {
      _upsertInCache(photo);
    }
  }

  Future<bool> deletePhoto(String id) async {
    final photo = _photoBox.get(id);
    if (photo == null) return false;
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset != null) {
        await PhotoManager.editor.deleteWithIds([asset.id]);
      }
    } catch (_) {}
    await _deleteLocalFiles([photo]);
    await _photoBox.delete(id);
    _removeFromCache(id);
    removeFromPendingEverywhere([id]);
    return true;
  }

  Future<int> deletePhotos(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final photos = <Photo>[];
    for (final id in ids) {
      final photo = _photoBox.get(id);
      if (photo != null) photos.add(photo);
    }
    if (photos.isEmpty) return 0;

    await _deleteOriginals(photos);
    // 同时清理原图与缩略图（thumbnailPath 现可能与 path 不同）
    await _deleteLocalFiles(photos);

    // 一次批量删除，避免逐条写盘
    await _photoBox.deleteAll(ids);
    for (final photo in photos) {
      _removeFromCache(photo.id);
    }
    removeFromPendingEverywhere(ids);
    debugPrint('[Repo] 批量删除完成: ${photos.length} 张');
    return photos.length;
  }

  /// 通过系统相册删除原图（仅对看起来是 AssetEntity id 的记录生效）。
  Future<void> _deleteOriginals(List<Photo> photos) async {
    final assetIds = <String>[
      for (final photo in photos)
        if (_looksLikeAssetId(photo)) photo.id,
    ];
    if (assetIds.isEmpty) return;
    try {
      await PhotoManager.editor.deleteWithIds(assetIds);
    } catch (e) {
      debugPrint('[Repo] PhotoManager 删除失败: $e');
    }
  }

  /// 并发删除原图与缩略图文件。
  Future<void> _deleteLocalFiles(List<Photo> photos) async {
    final jobs = <Future<void>>[];
    for (final photo in photos) {
      jobs.add(_deleteFileIfExists(photo.path));
      if (photo.thumbnailPath != photo.path) {
        jobs.add(_deleteFileIfExists(photo.thumbnailPath));
      }
    }
    await Future.wait(jobs);
  }

  Future<void> _deleteFileIfExists(String path) async {
    if (path.isEmpty || path.startsWith('assets/')) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 旧逻辑用「id 长度 > 10 且非 assets 路径」判断是否为系统相册资源。
  static bool _looksLikeAssetId(Photo photo) {
    return photo.id.length > 10 && !photo.isAssetPath;
  }

  void deletePhotoRecordOnly(String id) {
    _photoBox.delete(id);
    _removeFromCache(id);
    removeFromPendingEverywhere([id]);
  }

  List<Photo> getPhotosByCategory(String category) {
    return getAllPhotos().where((p) => p.category == category).toList();
  }

  List<Photo> getSelectedPhotos() {
    return getAllPhotos().where((p) => p.isSelected).toList();
  }

  // ──────────────────────────────────────────────
  //  场景识别记录：photoId → SceneRecord（JSON 字符串存盘）
  // ──────────────────────────────────────────────

  Map<String, SceneRecord>? _sceneCache;

  Map<String, SceneRecord> _sceneRecords() {
    final cached = _sceneCache;
    if (cached != null) return cached;
    final map = <String, SceneRecord>{};
    for (final entry in _sceneBox.toMap().entries) {
      final record = SceneRecord.tryDecode(entry.value as String?);
      if (record != null) map[entry.key as String] = record;
    }
    return _sceneCache = map;
  }

  SceneRecord? getSceneRecord(String photoId) => _sceneRecords()[photoId];

  void saveSceneRecord(String photoId, SceneRecord record) {
    _sceneBox.put(photoId, record.encode());
    _sceneRecords()[photoId] = record;
  }

  /// 已识别过的张数（含「识别过但没结论」），用于设置页展示进度。
  int get sceneRecordCount => _sceneRecords().length;

  void clearSceneRecords() {
    // 逐条 delete：内存即刻失效；Box.clear() 是异步的，删完立刻读会拿到旧值
    for (final id in _sceneBox.keys.toList()) {
      _sceneBox.delete(id);
    }
    _sceneCache = null;
  }

  List<DiaryEntry> getAllDiaryEntries() => _diaryEntryBox.values.toList();
  DiaryEntry? getDiaryEntry(String id) => _diaryEntryBox.get(id);
  void saveDiaryEntry(DiaryEntry entry) => _diaryEntryBox.put(entry.id, entry);
  void deleteDiaryEntry(String id) => _diaryEntryBox.delete(id);

  List<MonthlyDiary> getAllMonthlyDiaries() => _monthlyDiaryBox.values.toList();

  MonthlyDiary? getMonthlyDiary(int year, int month) {
    final key = '${year}_$month';
    return _monthlyDiaryBox.get(key);
  }

  void saveMonthlyDiary(MonthlyDiary diary) {
    final key = '${diary.year}_${diary.month}';
    _monthlyDiaryBox.put(key, diary);
  }

  void deleteMonthlyDiary(int year, int month) {
    final key = '${year}_$month';
    _monthlyDiaryBox.delete(key);
  }

  List<String> getMagazinePhotoIds(int year, int month) {
    final key = 'magazine_${year}_$month';
    final stored = _generalBox.get(key);
    if (stored is List) return stored.cast<String>();
    return [];
  }

  void saveMagazinePhotoIds(int year, int month, List<String> ids) {
    final key = 'magazine_${year}_$month';
    _generalBox.put(key, ids);
  }

  List<Map<String, dynamic>> getMagazinePages(int year, int month) {
    final key = 'magazine_pages_${year}_$month';
    final stored = _generalBox.get(key);
    if (stored is String) {
      try {
        final list = jsonDecode(stored);
        if (list is List) return list.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    return [];
  }

  void saveMagazinePages(int year, int month, List<Map<String, dynamic>> pages) {
    final key = 'magazine_pages_${year}_$month';
    _generalBox.put(key, jsonEncode(pages));
  }

  Map<String, dynamic>? getMagazineMeta(int year, int month) {
    final key = 'magazine_meta_${year}_$month';
    final stored = _generalBox.get(key);
    if (stored is String) {
      try { return jsonDecode(stored) as Map<String, dynamic>; } catch (_) {}
    }
    return null;
  }

  void saveMagazineMeta(int year, int month, Map<String, dynamic> meta) {
    final key = 'magazine_meta_${year}_$month';
    _generalBox.put(key, jsonEncode(meta));
  }

  int getThemeMode() => _generalBox.get('themeMode', defaultValue: 0);
  void setThemeMode(int mode) => _generalBox.put('themeMode', mode);

  bool getHideEmptyAlbums() => _generalBox.get('hideEmptyAlbums', defaultValue: false);
  void setHideEmptyAlbums(bool value) => _generalBox.put('hideEmptyAlbums', value);

  // ── 今日已整理统计 ──
  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// 今日已整理张数（跨日自动归零）。
  int getOrganizedTodayCount() {
    if (_generalBox.get('organized_date') != _todayKey()) return 0;
    return _generalBox.get('organized_count', defaultValue: 0) as int;
  }

  /// 累计今日整理数（支持负数用于撤销）。
  void recordOrganized(int delta) {
    final today = _todayKey();
    if (_generalBox.get('organized_date') != today) {
      _generalBox.put('organized_date', today);
      _generalBox.put('organized_count', delta < 0 ? 0 : delta);
    } else {
      final current = _generalBox.get('organized_count', defaultValue: 0) as int;
      _generalBox.put('organized_count', current + delta < 0 ? 0 : current + delta);
    }
  }

  bool getAutoScan() => _generalBox.get('autoScan', defaultValue: true);
  void setAutoScan(bool value) => _generalBox.put('autoScan', value);
  bool getSkipDeleteConfirm() => _generalBox.get('skipDeleteConfirm', defaultValue: false);
  void setSkipDeleteConfirm(bool value) => _generalBox.put('skipDeleteConfirm', value);
  bool getAutoFetchQuotes() => _generalBox.get('autoFetchQuotes', defaultValue: false);
  void setAutoFetchQuotes(bool value) => _generalBox.put('autoFetchQuotes', value);
  int getLastQuoteFetchTime() => _generalBox.get('lastQuoteFetchTime', defaultValue: 0);
  void setLastQuoteFetchTime(int value) => _generalBox.put('lastQuoteFetchTime', value);

  List<Album> getAllAlbums() {
    final stored = _generalBox.get('albums_list');
    if (stored == null) return [];
    final list = (jsonDecode(stored) as List).cast<Map<String, dynamic>>();
    return list.map((e) => Album.fromJson(e)).toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  void saveAlbum(Album album) {
    final albums = getAllAlbums();
    final idx = albums.indexWhere((a) => a.id == album.id);
    if (idx >= 0) {
      albums[idx] = album;
    } else {
      albums.add(album);
    }
    _saveAlbums(albums);
  }

  void deleteAlbum(String albumId) {
    final albums = getAllAlbums()..removeWhere((a) => a.id == albumId);
    _saveAlbums(albums);
    clearPendingFor(albumId);
  }

  void reorderAlbums(List<Album> albums) {
    for (int i = 0; i < albums.length; i++) {
      albums[i].order = i;
    }
    _saveAlbums(albums);
  }

  void _saveAlbums(List<Album> albums) {
    final data = albums.map((a) => a.toJson()).toList();
    _generalBox.put('albums_list', jsonEncode(data));
  }

  // ──────────────────────────────────────────────
  //  待应用队列：整理时只入队，退出整理时一次性落盘
  // ──────────────────────────────────────────────

  static const String _pendingKey = 'pending_moves';
  static const String _manifestKey = 'move_manifest_latest';

  /// 相簿 id → 待移动照片 id 列表
  Map<String, List<String>> getPendingMoves() {
    final stored = _generalBox.get(_pendingKey);
    if (stored is String) {
      try {
        final map = jsonDecode(stored) as Map<String, dynamic>;
        return {
          for (final entry in map.entries)
            entry.key: (entry.value as List).cast<String>(),
        };
      } catch (_) {}
    }
    return {};
  }

  void _savePendingMoves(Map<String, List<String>> moves) {
    final cleaned = <String, dynamic>{};
    moves.forEach((key, ids) {
      if (ids.isNotEmpty) cleaned[key] = ids;
    });
    if (cleaned.isEmpty) {
      _generalBox.delete(_pendingKey);
    } else {
      _generalBox.put(_pendingKey, jsonEncode(cleaned));
    }
  }

  void addPendingMove(String albumId, String photoId) {
    final moves = getPendingMoves();
    final ids = moves.putIfAbsent(albumId, () => <String>[]);
    if (!ids.contains(photoId)) ids.add(photoId);
    _savePendingMoves(moves);
  }

  void removePendingMoves(String albumId, Iterable<String> photoIds) {
    final moves = getPendingMoves();
    final ids = moves[albumId];
    if (ids == null) return;
    final drop = photoIds.toSet();
    ids.removeWhere(drop.contains);
    _savePendingMoves(moves);
  }

  void clearPendingFor(String albumId) {
    final moves = getPendingMoves()..remove(albumId);
    _savePendingMoves(moves);
  }

  Map<String, int> getPendingCounts() {
    return getPendingMoves().map((key, ids) => MapEntry(key, ids.length));
  }

  int get totalPendingCount {
    var total = 0;
    for (final ids in getPendingMoves().values) {
      total += ids.length;
    }
    return total;
  }

  /// 照片被删除时，从所有待应用队列里摘掉，避免残留死 id
  void removeFromPendingEverywhere(Iterable<String> photoIds) {
    final drop = photoIds.toSet();
    if (drop.isEmpty) return;
    final moves = getPendingMoves();
    var changed = false;
    for (final ids in moves.values) {
      final before = ids.length;
      ids.removeWhere(drop.contains);
      if (ids.length != before) changed = true;
    }
    if (changed) _savePendingMoves(moves);
  }

  // ──────────────────────────────────────────────
  //  移动批次清单：记录每张照片的**原始目录**，用于精确回滚
  // ──────────────────────────────────────────────

  void saveMoveManifest({
    required String batchId,
    required String albumId,
    required Map<String, String> originalPaths,
  }) {
    final payload = <String, dynamic>{
      'batchId': batchId,
      'albumId': albumId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'items': originalPaths,
    };
    _generalBox.put(_manifestKey, jsonEncode(payload));
  }

  Map<String, dynamic>? getLatestMoveManifest() {
    final stored = _generalBox.get(_manifestKey);
    if (stored is String) {
      try {
        return jsonDecode(stored) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  void clearMoveManifest() => _generalBox.delete(_manifestKey);

  /// 一次性迁移：旧版本把相簿照片存在 `album_photos_<albumId>`。
  /// 新模型里相簿就是系统目录，这份 id 列表降级为「待应用队列」，
  /// 由用户显式确认后再物理移动。
  void migrateLegacyAlbumPhotos() {
    if (_generalBox.get('album_photos_migrated') == true) return;
    const prefix = 'album_photos_';
    final moves = getPendingMoves();
    final emptyAlbumIds = <String>{};
    var migrated = 0;
    for (final key in _generalBox.keys.toList()) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final albumId = key.substring(prefix.length);
      final stored = _generalBox.get(key);
      if (stored is List) {
        final ids = stored.cast<String>();
        if (ids.isEmpty) {
          emptyAlbumIds.add(albumId);
        } else {
          final merged = moves.putIfAbsent(albumId, () => <String>[]);
          for (final id in ids) {
            if (!merged.contains(id)) merged.add(id);
          }
          migrated += ids.length;
        }
      }
      _generalBox.delete(key);
    }

    // 旧版「同步本地相册」会给每个系统 bucket 建一条记录，其中大量是 0 张空壳
    //（QQ、网易云音乐、App 缓存目录等），迁移时一并清掉
    if (emptyAlbumIds.isNotEmpty) {
      final albums = getAllAlbums()..removeWhere((a) => emptyAlbumIds.contains(a.id));
      _saveAlbums(albums);
    }

    _savePendingMoves(moves);
    _generalBox.put('album_photos_migrated', true);
    debugPrint(
      '[Repo] 旧相簿迁移完成: $migrated 张进入待应用队列，清理 ${emptyAlbumIds.length} 个空相簿',
    );
  }
}
