import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/album.dart';
import '../repository/local_repository.dart';
import 'album_service.dart';
import 'photo_move_service.dart';

/// 一次「应用整理」的进度
class ArchiveProgress {
  final int done;
  final int total;
  final String albumName;

  const ArchiveProgress({
    required this.done,
    required this.total,
    required this.albumName,
  });

  double get ratio => total == 0 ? 0 : done / total;
}

/// 一次「应用整理 / 回滚 / 解散相簿」的结果
class ArchiveOutcome {
  final String? batchId;
  final int requested;
  final int moved;
  final int alreadyThere;
  final int blocked;
  final int failed;
  final Duration elapsed;
  final List<MoveItemResult> failures;

  const ArchiveOutcome({
    this.batchId,
    this.requested = 0,
    this.moved = 0,
    this.alreadyThere = 0,
    this.blocked = 0,
    this.failed = 0,
    this.elapsed = Duration.zero,
    this.failures = const [],
  });

  bool get isEmpty => requested == 0;

  String get summary {
    if (requested == 0) return '没有需要处理的照片';
    final parts = <String>['移动 $moved 张'];
    if (alreadyThere > 0) parts.add('已在目标 $alreadyThere 张');
    if (blocked > 0) parts.add('跳过 $blocked 张');
    if (failed > 0) parts.add('失败 $failed 张');
    return parts.join(' · ');
  }
}

/// 把「待应用队列」真正落到系统相册的业务层。
///
/// 负责：记录每张照片的**原始目录**（用于精确回滚）、按相簿分组批量移动、
/// 移动后回写 [Photo.path]、清单持久化、失败项保留以便重试。
class AlbumArchiveService {
  AlbumArchiveService({
    required this.repository,
    required this.albumService,
    PhotoMoveService? mover,
  }) : mover = mover ?? PhotoMoveService.instance;

  final LocalRepository repository;
  final AlbumService albumService;
  final PhotoMoveService mover;

  /// 应用所有相簿的待整理队列
  Future<ArchiveOutcome> applyPending({
    void Function(ArchiveProgress)? onProgress,
  }) async {
    final pending = repository.getPendingMoves();
    if (pending.isEmpty) return const ArchiveOutcome();

    final albums = repository.getAllAlbums();
    final byId = <String, Album>{for (final album in albums) album.id: album};

    final total = pending.values.fold<int>(0, (sum, ids) => sum + ids.length);
    var done = 0;
    var requested = 0;
    var moved = 0;
    var alreadyThere = 0;
    var blocked = 0;
    var failed = 0;
    final failures = <MoveItemResult>[];
    final originalPaths = <String, String>{};
    final stopwatch = Stopwatch()..start();
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();

    for (final entry in pending.entries) {
      final album = byId[entry.key];
      if (album == null) {
        repository.clearPendingFor(entry.key);
        continue;
      }

      final entities = await _entitiesOf(entry.value);
      final missing = entry.value.where((id) => entities.every((e) => e.id != id));
      if (missing.isNotEmpty) {
        // 照片已经被用户在系统里删掉了，直接摘掉死 id
        repository.removePendingMoves(entry.key, missing);
      }
      if (entities.isEmpty) {
        repository.clearPendingFor(entry.key);
        continue;
      }

      final targetDir =
          album.isPhysical ? album.relativePath! : ArchivePaths.albumDir(album.name);

      // 先记原始目录，再移动 —— 顺序反了就拿不到来源了
      for (final entity in entities) {
        originalPaths[entity.id] = ArchivePaths.normalize(entity.relativePath ?? '');
      }

      final result = await mover.moveToDirectory(
        entities: entities,
        targetDir: targetDir,
        onProgress: (processed, _) {
          onProgress?.call(ArchiveProgress(
            done: done + processed,
            total: total,
            albumName: album.name,
          ));
        },
      );

      done += entities.length;
      requested += result.requested;
      moved += result.moved;
      alreadyThere += result.alreadyThere;
      blocked += result.blocked;
      failed += result.failed;
      failures.addAll(result.items.where((item) => !item.success));

      final okIds = result.items
          .where((item) => item.success)
          .map((item) => item.assetId)
          .toList(growable: false);
      repository.removePendingMoves(entry.key, okIds);
      await refreshPhotoPaths(okIds);

      // 只有真的落盘了才把草稿升级成物理相簿
      if (!album.isPhysical && okIds.isNotEmpty) {
        album.relativePath = ArchivePaths.normalize(targetDir);
        album.isLocalSync = true;
        repository.saveAlbum(album);
      }

      onProgress?.call(ArchiveProgress(
        done: done,
        total: total,
        albumName: album.name,
      ));
    }

    stopwatch.stop();
    if (originalPaths.isNotEmpty) {
      repository.saveMoveManifest(
        batchId: batchId,
        albumId: '',
        originalPaths: originalPaths,
      );
    }

    return ArchiveOutcome(
      batchId: batchId,
      requested: requested,
      moved: moved,
      alreadyThere: alreadyThere,
      blocked: blocked,
      failed: failed,
      elapsed: stopwatch.elapsed,
      failures: failures,
    );
  }

  /// 按最近一次移动的清单，把照片精确还原到**原始目录**
  /// （不是上一次的目录 —— 链式移动时两者不同）
  Future<ArchiveOutcome> rollbackLatest({
    void Function(ArchiveProgress)? onProgress,
  }) async {
    final manifest = repository.getLatestMoveManifest();
    if (manifest == null) return const ArchiveOutcome();

    final rawItems = manifest['items'];
    if (rawItems is! Map) return const ArchiveOutcome();
    final items = rawItems.map((key, value) => MapEntry('$key', '$value'));

    final groups = <String, List<String>>{};
    items.forEach((id, path) {
      final origin = ArchivePaths.normalize(path);
      if (origin.isEmpty) return;
      groups.putIfAbsent(origin, () => <String>[]).add(id);
    });
    if (groups.isEmpty) return const ArchiveOutcome();

    final total = items.length;
    var done = 0;
    var requested = 0;
    var moved = 0;
    var alreadyThere = 0;
    var blocked = 0;
    var failed = 0;
    final failures = <MoveItemResult>[];
    final stopwatch = Stopwatch()..start();

    for (final group in groups.entries) {
      final entities = await _entitiesOf(group.value);
      if (entities.isEmpty) {
        done += group.value.length;
        continue;
      }
      final result = await mover.moveToDirectory(
        entities: entities,
        targetDir: group.key,
        onProgress: (processed, _) {
          onProgress?.call(ArchiveProgress(
            done: done + processed,
            total: total,
            albumName: '回滚',
          ));
        },
      );
      done += entities.length;
      requested += result.requested;
      moved += result.moved;
      alreadyThere += result.alreadyThere;
      blocked += result.blocked;
      failed += result.failed;
      failures.addAll(result.items.where((item) => !item.success));
      await refreshPhotoPaths(
        result.items.where((i) => i.success).map((i) => i.assetId).toList(),
      );
    }

    stopwatch.stop();
    if (failed == 0) repository.clearMoveManifest();
    return ArchiveOutcome(
      requested: requested,
      moved: moved,
      alreadyThere: alreadyThere,
      blocked: blocked,
      failed: failed,
      elapsed: stopwatch.elapsed,
      failures: failures,
    );
  }

  /// 把相簿里的照片整体移到另一个目录（解散相簿 / 重命名相簿用）
  Future<ArchiveOutcome> moveAlbumTo(Album album, String targetDir) async {
    if (!album.isPhysical) return const ArchiveOutcome();
    final bucket = await albumService.bucketOf(album.relativePath ?? '');
    if (bucket == null) return const ArchiveOutcome();

    final total = await bucket.assetCountAsync;
    if (total == 0) return const ArchiveOutcome();
    final assets = await bucket.getAssetListRange(start: 0, end: math.min(total, 20000));

    final originalPaths = <String, String>{};
    for (final asset in assets) {
      originalPaths[asset.id] = ArchivePaths.normalize(asset.relativePath ?? '');
    }

    final result = await mover.moveToDirectory(entities: assets, targetDir: targetDir);
    await refreshPhotoPaths(
      result.items.where((i) => i.success).map((i) => i.assetId).toList(),
    );

    if (originalPaths.isNotEmpty) {
      repository.saveMoveManifest(
        batchId: DateTime.now().millisecondsSinceEpoch.toString(),
        albumId: album.id,
        originalPaths: originalPaths,
      );
    }

    return ArchiveOutcome(
      requested: result.requested,
      moved: result.moved,
      alreadyThere: result.alreadyThere,
      blocked: result.blocked,
      failed: result.failed,
      elapsed: result.elapsed,
      failures: result.items.where((i) => !i.success).toList(),
    );
  }

  /// 移动会改变文件的 DATA 路径，Photo.path 必须同步，
  /// 否则详情页用 File(path) 打开原图会 404。
  Future<void> refreshPhotoPaths(List<String> ids) async {
    if (ids.isEmpty) return;
    for (final id in ids) {
      try {
        final entity = await AssetEntity.fromId(id);
        final file = await entity?.file;
        if (file == null) continue;
        final photo = repository.getPhoto(id);
        if (photo == null || photo.path == file.path) continue;
        repository.savePhoto(photo.copyWith(path: file.path));
      } catch (error) {
        debugPrint('[Archive] 回写 path 失败 $id: $error');
      }
    }
  }

  Future<List<AssetEntity>> _entitiesOf(Iterable<String> ids) async {
    final entities = <AssetEntity>[];
    for (final id in ids) {
      try {
        final entity = await AssetEntity.fromId(id);
        if (entity != null) entities.add(entity);
      } catch (_) {}
    }
    return entities;
  }
}
