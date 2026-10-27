import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// 归档目录约定（参考 Slidebox 在 Android 上的策略）。
///
/// 根目录放在 `Pictures` 而不是 `DCIM`：`DCIM` 被多数 ROM 视为「相机胶卷」，
/// 第三方写入容易被相机 App 的胶卷视图忽略；`Pictures` 是 Android 官方给
/// 应用图片的归属目录，各家 ROM 的相册都能稳定识别。
class ArchivePaths {
  ArchivePaths._();

  /// 归档根目录，所有 App 内相簿都挂在它下面
  static const String root = 'Pictures/拾光';

  /// 去掉首尾斜杠，用于比较
  static String normalize(String path) {
    var p = path.trim();
    if (p.startsWith('/')) p = p.substring(1);
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// MediaStore 的 RELATIVE_PATH 惯例带结尾斜杠，写入时保持一致，
  /// 否则会出现 `Pictures/X` 与 `Pictures/X/` 两种写法混存。
  static String toRelativePath(String dir) => '${normalize(dir)}/';

  /// 相簿名里的非法字符会导致目录创建失败，统一替换掉
  static String sanitizeAlbumName(String name) {
    final cleaned = name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    final trimmed = cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
    return trimmed.isEmpty ? '未命名相簿' : trimmed;
  }

  static String albumDir(String albumName) => '$root/${sanitizeAlbumName(albumName)}';
  static String albumPath(String albumName) => toRelativePath(albumDir(albumName));
}

/// 允许移动的来源目录白名单。
///
/// 微信 / QQ 等第三方目录默认不动：它们按路径或 uri 索引自己的图片，
/// 移走后聊天里的图可能打不开。
class MovableSources {
  MovableSources._();

  static const List<String> prefixes = <String>[
    'DCIM',
    'Pictures',
    'Download',
  ];

  static const List<String> blockedKeywords = <String>[
    'weixin',
    'wechat',
    'micromsg',
    'tencent',
    'qq',
    'dingtalk',
    'telegram',
    'whatsapp',
  ];

  static bool allows(String? relativePath) {
    final p = ArchivePaths.normalize(relativePath ?? '');
    if (p.isEmpty) return false;
    final lower = p.toLowerCase();
    for (final keyword in blockedKeywords) {
      if (lower.contains(keyword)) return false;
    }
    for (final prefix in prefixes) {
      if (p == prefix || p.startsWith('$prefix/')) return true;
    }
    return false;
  }
}

/// 单张照片的移动结果
class MoveItemResult {
  final String assetId;
  final String? fromPath;
  final String? toPath;
  final bool success;

  /// 已在目标目录，未产生实际移动
  final bool skipped;
  final String? error;

  const MoveItemResult({
    required this.assetId,
    this.fromPath,
    this.toPath,
    required this.success,
    this.skipped = false,
    this.error,
  });

  String get shortId => assetId.length > 10 ? assetId.substring(0, 10) : assetId;
}

/// 一次批量移动的结果
class MoveBatchResult {
  final String targetDir;
  final String targetRelativePath;
  final int requested;
  final int alreadyThere;
  final int blocked;
  final int moved;
  final int failed;
  final Duration elapsed;
  final List<MoveItemResult> items;
  final String? fatalError;

  const MoveBatchResult({
    required this.targetDir,
    required this.targetRelativePath,
    required this.requested,
    required this.alreadyThere,
    required this.blocked,
    required this.moved,
    required this.failed,
    required this.elapsed,
    required this.items,
    this.fatalError,
  });

  bool get allOk => failed == 0 && fatalError == null;

  /// 真正发生过移动、可用于回滚的条目
  List<MoveItemResult> get movableItems =>
      items.where((i) => i.success && !i.skipped).toList();
}

/// 相簿物理归档服务。
///
/// 核心机制：Android 11+ 通过 `MediaStore.createWriteRequest` 申请一次批量授权，
/// 随后逐条 `UPDATE RELATIVE_PATH`。文件原地换目录，不复制字节、不占额外空间，
/// MediaStore 的 `_ID` 不变，因此 [Photo.id] 与缩略图缓存继续有效。
class PhotoMoveService {
  PhotoMoveService._();

  static final PhotoMoveService instance = PhotoMoveService._();

  /// 单次 createWriteRequest 的项数上限，超过必须分批
  static const int systemBatchLimit = 2000;

  /// 实际批次大小：切小一点，进度反馈和失败重试都更细
  static const int defaultChunkSize = 200;

  /// photo_manager 的写入授权内部只有一份 pending 操作（单例 writeHandler），
  /// 并发调用会互相覆盖并导致回调永不返回，因此所有移动必须串行排队。
  Future<void> _tail = Future<void>.value();

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<T> _serialize<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      if (completer.isCompleted) return;
      try {
        completer.complete(await task());
      } catch (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// 批量移动到 [targetDir]（如 `Pictures/拾光/旅行`）。
  ///
  /// 会自动跳过已在目标目录的照片、以及来源不在白名单的照片。
  /// [onProgress] 按「待移动张数」推进。
  Future<MoveBatchResult> moveToDirectory({
    required List<AssetEntity> entities,
    required String targetDir,
    int chunkSize = defaultChunkSize,
    void Function(int processed, int total)? onProgress,
  }) {
    return _serialize(
      () => _doMove(
        entities: entities,
        targetDir: targetDir,
        chunkSize: chunkSize.clamp(1, systemBatchLimit),
        onProgress: onProgress,
      ),
    );
  }

  Future<MoveBatchResult> _doMove({
    required List<AssetEntity> entities,
    required String targetDir,
    required int chunkSize,
    void Function(int processed, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final targetNorm = ArchivePaths.normalize(targetDir);
    final targetRel = ArchivePaths.toRelativePath(targetDir);

    final items = <MoveItemResult>[];
    final pending = <AssetEntity>[];
    var alreadyThere = 0;
    var blocked = 0;

    for (final entity in entities) {
      final current = entity.relativePath;
      if (ArchivePaths.normalize(current ?? '') == targetNorm) {
        alreadyThere++;
        items.add(MoveItemResult(
          assetId: entity.id,
          fromPath: current,
          toPath: targetNorm,
          success: true,
          skipped: true,
        ));
        continue;
      }
      if (!MovableSources.allows(current)) {
        blocked++;
        items.add(MoveItemResult(
          assetId: entity.id,
          fromPath: current,
          toPath: targetNorm,
          success: false,
          error: '来源不在白名单：${current ?? '未知'}',
        ));
        continue;
      }
      pending.add(entity);
    }

    if (pending.isEmpty) {
      stopwatch.stop();
      return MoveBatchResult(
        targetDir: targetNorm,
        targetRelativePath: targetRel,
        requested: entities.length,
        alreadyThere: alreadyThere,
        blocked: blocked,
        moved: 0,
        failed: 0,
        elapsed: stopwatch.elapsed,
        items: items,
      );
    }

    final total = pending.length;
    var processed = 0;
    String? fatalError;

    for (var start = 0; start < total; start += chunkSize) {
      final end = math.min(start + chunkSize, total);
      final chunk = pending.sublist(start, end);

      try {
        await PhotoManager.editor.android.moveAssetsToPath(
          entities: chunk,
          targetPath: targetRel,
        );
      } catch (error) {
        // 用户拒绝授权、或系统抛 RecoverableSecurityException 都会落到这里
        fatalError ??= error.toString();
      }

      // 逐条回查：moveAssetsToPath 只要有一条成功就返回 true，
      // 部分失败也会被当成成功，因此必须用 relativePath 复核。
      for (final entity in chunk) {
        String? actual;
        Object? verifyError;
        try {
          final latest = await AssetEntity.fromId(entity.id);
          actual = latest?.relativePath;
        } catch (error) {
          verifyError = error;
        }
        final ok = ArchivePaths.normalize(actual ?? '') == targetNorm;
        items.add(MoveItemResult(
          assetId: entity.id,
          fromPath: entity.relativePath,
          toPath: ok ? ArchivePaths.normalize(actual ?? targetNorm) : targetNorm,
          success: ok,
          error: ok
              ? null
              : (verifyError?.toString() ?? fatalError ?? '移动后目录未变化'),
        ));
      }

      processed += chunk.length;
      onProgress?.call(processed, total);
    }

    stopwatch.stop();
    final moved = items.where((i) => i.success && !i.skipped).length;
    final failed = items.where((i) => !i.success).length;
    return MoveBatchResult(
      targetDir: targetNorm,
      targetRelativePath: targetRel,
      requested: entities.length,
      alreadyThere: alreadyThere,
      blocked: blocked,
      moved: moved,
      failed: failed,
      elapsed: stopwatch.elapsed,
      items: items,
      fatalError: fatalError,
    );
  }

  /// 把一次移动回滚到各自的原目录（按原目录分组逐组执行）。
  Future<MoveBatchResult> restore(List<MoveItemResult> moved) {
    return _serialize(() async {
      final groups = <String, List<String>>{};
      for (final item in moved) {
        if (!item.success || item.skipped) continue;
        final origin = ArchivePaths.normalize(item.fromPath ?? '');
        if (origin.isEmpty) continue;
        groups.putIfAbsent(origin, () => <String>[]).add(item.assetId);
      }

      final allItems = <MoveItemResult>[];
      final stopwatch = Stopwatch()..start();
      String? fatalError;

      for (final entry in groups.entries) {
        final entities = <AssetEntity>[];
        for (final id in entry.value) {
          final entity = await AssetEntity.fromId(id);
          if (entity != null) entities.add(entity);
        }
        if (entities.isEmpty) continue;
        final result = await _doMove(
          entities: entities,
          targetDir: entry.key,
          chunkSize: defaultChunkSize,
          onProgress: null,
        );
        allItems.addAll(result.items);
        fatalError ??= result.fatalError;
      }

      stopwatch.stop();
      return MoveBatchResult(
        targetDir: '(回滚)',
        targetRelativePath: '',
        requested: allItems.length,
        alreadyThere: allItems.where((i) => i.skipped).length,
        blocked: allItems.where((i) => !i.success && i.error?.contains('白名单') == true).length,
        moved: allItems.where((i) => i.success && !i.skipped).length,
        failed: allItems.where((i) => !i.success).length,
        elapsed: stopwatch.elapsed,
        items: allItems,
        fatalError: fatalError,
      );
    });
  }

  /// 查询某个目录此刻是否已经成为系统 bucket。
  ///
  /// 用于验证「移动后相册 App 是否立刻能看到新相簿」。
  Future<AssetPathEntity?> findBucket(String dir) async {
    final target = ArchivePaths.normalize(dir);
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: false,
      type: RequestType.image,
    );
    for (final path in paths) {
      String? relative;
      try {
        relative = await path.relativePathAsync;
      } catch (_) {}
      if (ArchivePaths.normalize(relative ?? '') == target) return path;
    }
    return null;
  }
}
