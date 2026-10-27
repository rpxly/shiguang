import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/album.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import 'photo_move_service.dart';

/// 一个相簿在某一时刻的状态快照（相簿本身 + 系统目录 + 实时计数）
class AlbumEntry {
  final Album album;
  final AssetPathEntity? bucket;
  final int count;
  final List<String> coverIds;
  final int pending;

  const AlbumEntry({
    required this.album,
    required this.bucket,
    required this.count,
    required this.coverIds,
    required this.pending,
  });

  bool get isPhysical => bucket != null;
  bool get isEmpty => count == 0 && pending == 0;
}

/// 相簿与系统目录的对齐服务。
///
/// 新模型下「相簿 = 系统目录」，App 只保存少量元信息（名称、排序、草稿状态），
/// 照片归属和数量一律从 MediaStore 的 bucket 派生 —— 不存在第二份数据，
/// 也就不存在两边对不上的问题。
class AlbumService {
  AlbumService(this.repository);

  final LocalRepository repository;

  /// 归档根目录下的所有 bucket（排除 isAll 伪相簿和根目录本身）
  Future<Map<String, AssetPathEntity>> _loadBuckets() async {
    final result = <String, AssetPathEntity>{};
    List<AssetPathEntity> paths;
    try {
      paths = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.image,
      );
    } catch (error) {
      debugPrint('[AlbumService] 读取系统相簿失败: $error');
      return result;
    }

    final root = ArchivePaths.normalize(ArchivePaths.root);
    for (final path in paths) {
      if (path.isAll) continue;
      String? relative;
      try {
        relative = await path.relativePathAsync;
      } catch (_) {
        continue;
      }
      final norm = ArchivePaths.normalize(relative ?? '');
      if (norm.isEmpty) continue;
      // 只要归档根下面的子目录，根目录自身不作为相簿
      if (norm == root || !norm.startsWith('$root/')) continue;
      result[norm] = path;
    }
    return result;
  }

  /// 把 App 内的相簿列表与系统目录对齐，并返回带实时计数的快照。
  ///
  /// [pruneMissing] 为 true 时，目录已经不存在（被系统删除或改名）的物理相簿
  /// 会从 App 列表里移除 —— 与「相簿就是目录」的认知保持一致。
  Future<List<AlbumEntry>> refresh({bool pruneMissing = true}) async {
    final buckets = await _loadBuckets();
    var albums = repository.getAllAlbums();
    var changed = false;

    if (buckets.isNotEmpty) {
      // 1. 系统里有、App 里没有 → 绑定同名草稿，或补一条新相簿
      for (final entry in buckets.entries) {
        final norm = entry.key;
        final bucket = entry.value;
        final bound = _firstWhere(
          albums,
          (a) => ArchivePaths.normalize(a.relativePath ?? '') == norm,
        );
        if (bound != null) continue;

        final draft = _firstWhere(
          albums,
          (a) => !a.isPhysical && a.name == bucket.name,
        );
        if (draft != null) {
          draft.relativePath = norm;
          draft.isLocalSync = true;
          changed = true;
        } else {
          albums.add(Album(
            id: 'path_$norm',
            name: bucket.name,
            order: albums.length,
            relativePath: norm,
            isLocalSync: true,
          ));
          changed = true;
        }
      }
    }

    // 2. 目录已经不存在的物理相簿：跟随系统移除
    if (pruneMissing && buckets.isNotEmpty) {
      final alive = buckets.keys.toSet();
      final before = albums.length;
      albums = albums.where((a) {
        if (!a.isPhysical) return true;
        return alive.contains(ArchivePaths.normalize(a.relativePath ?? ''));
      }).toList();
      if (albums.length != before) changed = true;
    }

    if (changed) {
      repository.reorderAlbums(albums);
      albums = repository.getAllAlbums();
    }

    // 3. 统计（一次读 bucket，避免逐条查 DB）
    final pendingCounts = repository.getPendingCounts();
    final entries = <AlbumEntry>[];
    for (final album in albums) {
      final norm = ArchivePaths.normalize(album.relativePath ?? '');
      final bucket = buckets[norm];
      var count = 0;
      var covers = const <String>[];
      if (bucket != null) {
        try {
          count = await bucket.assetCountAsync;
          final end = count < 3 ? count : 3;
          if (end > 0) {
            final assets = await bucket.getAssetListRange(start: 0, end: end);
            covers = [for (final asset in assets) asset.id];
          }
        } catch (error) {
          debugPrint('[AlbumService] 统计相簿失败 ${album.name}: $error');
        }
      }
      entries.add(AlbumEntry(
        album: album,
        bucket: bucket,
        count: count,
        coverIds: covers,
        pending: pendingCounts[album.id] ?? 0,
      ));
    }

    // 4. 白名单目录之外的散落照片数（未整理的真实口径）
    return entries;
  }

  /// 读取某个相簿里的照片（按 id 从本地库解析，缺失的忽略）
  Future<List<Photo>> photosInBucket(
    AssetPathEntity bucket, {
    int limit = 20000,
  }) async {
    var total = 0;
    try {
      total = await bucket.assetCountAsync;
    } catch (_) {}
    if (total == 0) return const [];
    final end = total < limit ? total : limit;
    final assets = await bucket.getAssetListRange(start: 0, end: end);
    final index = repository.indexPhotosById();
    final photos = <Photo>[];
    for (final asset in assets) {
      final photo = index[asset.id];
      if (photo != null) photos.add(photo);
    }
    return photos;
  }

  Future<AssetPathEntity?> bucketOf(String relativePath) async {
    final target = ArchivePaths.normalize(relativePath);
    if (target.isEmpty) return null;
    final buckets = await _loadBuckets();
    return buckets[target];
  }

  static T? _firstWhere<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }
}
