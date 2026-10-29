import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';
import 'thumbnail_service.dart';

/// 权限状态
enum PhotoPermissionStatus { granted, denied, restricted, unknown }

/// 扫描过程中的进度回调集合。
///
/// - [onTotal]：本次扫描需要遍历的照片总数（系统相册总数或文件系统候选数）
/// - [onProgress]：已遍历的照片数（含命中和跳过）
/// - [onBatch]：本批需要写回 Hive 的照片（新增 + 补缩略图/刷新元数据的旧记录）
typedef ScanTotalCallback = void Function(int total);
typedef ScanProgressCallback = void Function(int processed);
typedef ScanBatchCallback = void Function(List<Photo> batch);

class PhotoScannerService {
  bool _hasPermission = false;
  PhotoPermissionStatus _permissionStatus = PhotoPermissionStatus.unknown;

  final ThumbnailService _thumbnailService = ThumbnailService();

  /// 每页读取数量
  static const int _pageSize = 200;

  /// 单张照片元数据抓取 + 缩略图生成的并发度
  static const int _concurrency = 4;

  bool get hasPermission => _hasPermission;
  PhotoPermissionStatus get permissionStatus => _permissionStatus;

  /// 检查当前权限状态（不弹窗）
  Future<PhotoPermissionStatus> checkPermission() async {
    try {
      final state = await PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      debugPrint('[Scanner] 当前权限状态: $state');
      _permissionStatus = _mapPermissionState(state);
      _hasPermission = state.isAuth;
      return _permissionStatus;
    } catch (e) {
      debugPrint('[Scanner] 检查权限失败: $e');
      return PhotoPermissionStatus.unknown;
    }
  }

  PhotoPermissionStatus _mapPermissionState(PermissionState state) {
    switch (state) {
      case PermissionState.authorized:
        return PhotoPermissionStatus.granted;
      case PermissionState.denied:
        return PhotoPermissionStatus.denied;
      case PermissionState.restricted:
        return PhotoPermissionStatus.restricted;
      case PermissionState.limited:
        return PhotoPermissionStatus.granted;
      default:
        return PhotoPermissionStatus.unknown;
    }
  }

  /// 请求相册权限（会弹窗）
  Future<PhotoPermissionStatus> requestPermission() async {
    try {
      debugPrint('[Scanner] 开始请求相册权限...');
      final result = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
      debugPrint('[Scanner] 权限请求结果: ${result.isAuth}, state=$result');
      _hasPermission = result.isAuth;
      _permissionStatus = _mapPermissionState(result);
      if (!_hasPermission) {
        debugPrint('[Scanner] 权限被拒绝，状态: $_permissionStatus');
      }
      return _permissionStatus;
    } catch (e) {
      debugPrint('[Scanner] 权限请求异常: $e');
      _hasPermission = false;
      _permissionStatus = PhotoPermissionStatus.denied;
      return _permissionStatus;
    }
  }

  /// 扫描设备照片。
  ///
  /// [existing] 为已入库照片（id → Photo），用于增量跳过与补缩略图；
  /// [force] 为 true 时刷新已有照片的元数据（同一 id 不会产生重复记录）。
  Future<List<Photo>> scanDevicePhotos({
    Map<String, Photo> existing = const {},
    bool force = false,
    ScanBatchCallback? onBatch,
    ScanTotalCallback? onTotal,
    ScanProgressCallback? onProgress,
  }) async {
    if (!_hasPermission) {
      await requestPermission();
    }

    List<Photo> photos = [];
    var fallbackToFileSystem = true;

    if (_hasPermission) {
      var result = await _scanWithPhotoManager(
        existing: existing,
        force: force,
        onBatch: onBatch,
        onTotal: onTotal,
        onProgress: onProgress,
      );
      if (!result.success) {
        try {
          await PhotoManager.forceOldApi();
          result = await _scanWithPhotoManager(
            existing: existing,
            force: force,
            onBatch: onBatch,
            onTotal: onTotal,
            onProgress: onProgress,
          );
        } catch (e) {
          debugPrint('[Scanner] 旧 API 扫描失败: $e');
        }
      }
      photos = result.photos;
      // 只有读取失败或系统相册为空时才走文件系统兜底；
      // 增量扫描全部跳过时 photos 为空，不能触发兜底。
      fallbackToFileSystem = !result.success || !result.hasAssets;
    }

    if (fallbackToFileSystem) {
      photos = await _scanFileSystem(
        existing: existing,
        force: force,
        onBatch: onBatch,
        onTotal: onTotal,
        onProgress: onProgress,
      );
    }

    debugPrint('[Scanner] 扫描完成，共 ${photos.length} 张照片');
    photos.sort((a, b) => b.date.compareTo(a.date));
    return photos;
  }

  Future<_PhotoManagerScanResult> _scanWithPhotoManager({
    required Map<String, Photo> existing,
    required bool force,
    ScanBatchCallback? onBatch,
    ScanTotalCallback? onTotal,
    ScanProgressCallback? onProgress,
  }) async {
    try {
      final totalCount = await PhotoManager.getAssetCount(
        type: RequestType.image,
      );
      debugPrint('[Scanner] 系统相册共 $totalCount 张图片');
      onTotal?.call(totalCount);
      if (totalCount == 0) {
        return const _PhotoManagerScanResult([], success: true, hasAssets: false);
      }

      final allPhotos = <Photo>[];
      var processed = 0;

      for (var start = 0; start < totalCount; start += _pageSize) {
        final end = math.min(start + _pageSize, totalCount);
        final entities = await PhotoManager.getAssetListRange(
          start: start,
          end: end,
          type: RequestType.image,
        );
        final images = entities
            .where((entity) => entity.type == AssetType.image)
            .toList();

        // 元数据抓取 + 缩略图生成按 4 路并发执行
        final batch = <Photo>[];
        for (var i = 0; i < images.length; i += _concurrency) {
          final chunk = images.sublist(
            i,
            math.min(i + _concurrency, images.length),
          );
          final results = await Future.wait(
            chunk.map(
              (entity) => _processEntity(
                entity,
                existing[entity.id],
                force: force,
              ),
            ),
          );
          for (final photo in results) {
            if (photo != null) batch.add(photo);
          }
        }

        if (batch.isNotEmpty) {
          allPhotos.addAll(batch);
          onBatch?.call(batch);
        }
        processed += entities.length;
        onProgress?.call(processed);
        debugPrint('[Scanner] 扫描进度: $processed/$totalCount');
      }

      return _PhotoManagerScanResult(allPhotos, success: true, hasAssets: true);
    } catch (e) {
      debugPrint('[Scanner] PhotoManager 扫描失败: $e');
      return const _PhotoManagerScanResult([], success: false, hasAssets: false);
    }
  }

  /// 处理单张照片：增量跳过、补缩略图或刷新元数据。
  Future<Photo?> _processEntity(
    AssetEntity entity,
    Photo? existing, {
    required bool force,
  }) async {
    if (entity.type != AssetType.image) return null;

    final thumbnailUsable =
        existing != null && await _hasUsableThumbnail(existing);

    // 增量：已入库且缩略图可用则完全跳过（不读取文件信息）
    if (existing != null && !force) {
      if (thumbnailUsable) return null;
      // 旧记录（缩略图仍指向原图或文件已被清理）：只补缩略图，不刷新元数据
      final generated = await _generateThumbnail(entity);
      if (generated != null) {
        return existing.copyWith(thumbnailPath: generated);
      }
      if (existing.thumbnailPath != existing.path) {
        return existing.copyWith(thumbnailPath: existing.path);
      }
      return null;
    }

    final base = await _entityToPhoto(entity);
    if (base == null) return null;

    final thumbnailPath = thumbnailUsable
        ? existing.thumbnailPath
        : await _generateThumbnail(entity) ?? base.path;

    final photo = base.copyWith(thumbnailPath: thumbnailPath);
    if (existing == null) return photo;

    // 保留收藏、标签、评分等用户数据，仅刷新元数据与缩略图
    return existing.copyWith(
      path: photo.path,
      thumbnailPath: thumbnailPath,
      date: photo.dateTime,
      location: photo.location,
      fileSize: photo.fileSize,
    );
  }

  Future<bool> _hasUsableThumbnail(Photo photo) async {
    final thumbnailPath = photo.thumbnailPath;
    if (thumbnailPath.isEmpty) return false;
    if (thumbnailPath == photo.path) return false;
    if (thumbnailPath.startsWith('assets/')) return false;
    return _thumbnailService.hasThumbnailFile(thumbnailPath);
  }

  Future<String?> _generateThumbnail(AssetEntity entity) async {
    try {
      return await _thumbnailService.generateForEntity(entity, entity.id);
    } catch (e) {
      debugPrint('[Scanner] 缩略图生成异常 ${entity.id}: $e');
      return null;
    }
  }

  Future<List<Photo>> _scanFileSystem({
    required Map<String, Photo> existing,
    required bool force,
    ScanBatchCallback? onBatch,
    ScanTotalCallback? onTotal,
    ScanProgressCallback? onProgress,
  }) async {
    try {
      final dirs = <String>[
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Pictures/Screenshots',
        '/storage/emulated/0/Download',
      ];

      final exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
      final existingByPath = <String, Photo>{};
      for (final photo in existing.values) {
        if (photo.path.isNotEmpty && !photo.isAssetPath) {
          existingByPath[photo.path] = photo;
        }
      }

      final candidates = <File>[];
      final seen = <String>{};
      for (final dirPath in dirs) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        try {
          final files = dir.listSync(recursive: true);
          for (final file in files) {
            if (file is! File) continue;
            final path = file.path.toLowerCase();
            if (!exts.any((ext) => path.endsWith(ext))) continue;
            if (!seen.add(file.path)) continue;
            candidates.add(file);
          }
        } catch (_) {}
      }

      onTotal?.call(candidates.length);

      final photos = <Photo>[];
      final batch = <Photo>[];
      var processed = 0;

      for (final file in candidates) {
        final existingPhoto = existingByPath[file.path];
        processed++;

        if (existingPhoto != null && !force) {
          final thumbnailPath = existingPhoto.thumbnailPath;
          final thumbnailOk = thumbnailPath.isEmpty ||
              thumbnailPath == existingPhoto.path ||
              await _thumbnailFileExists(thumbnailPath);
          if (thumbnailOk) {
            onProgress?.call(processed);
            continue;
          }
        }

        try {
          final stat = await file.stat();
          final fileSize = await file.length();
          final Photo photo;
          if (existingPhoto != null) {
            photo = existingPhoto.copyWith(
              path: file.path,
              // 文件系统兜底没有缩略图，使用原图路径
              thumbnailPath: file.path,
              date: stat.modified,
              fileSize: fileSize,
            );
          } else {
            photo = Photo(
              id: file.path.hashCode.toString(),
              path: file.path,
              thumbnailPath: file.path,
              date: stat.modified,
              location: null,
              category: null,
              fileSize: fileSize,
            );
          }
          batch.add(photo);
          photos.add(photo);
        } catch (_) {}

        if (batch.length >= _pageSize) {
          onBatch?.call(List<Photo>.from(batch));
          batch.clear();
        }
        onProgress?.call(processed);
      }

      if (batch.isNotEmpty) {
        onBatch?.call(List<Photo>.from(batch));
        batch.clear();
      }

      return photos;
    } catch (e) {
      debugPrint('[Scanner] 文件系统扫描失败: $e');
      return [];
    }
  }

  Future<bool> _thumbnailFileExists(String path) async {
    try {
      final file = File(path);
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<Photo?> _entityToPhoto(AssetEntity entity) async {
    try {
      final date = entity.createDateTime;

      String? filePath;
      try {
        final file = await entity.file;
        if (file != null) {
          filePath = file.path;
        }
      } catch (_) {}

      if (filePath == null) {
        try {
          final originFile = await entity.originFile;
          if (originFile != null) {
            filePath = originFile.path;
          }
        } catch (_) {}
      }

      if (filePath == null) {
        // 兜底：云端未下载 / 系统清理过原文件的图片，entity.file 可能拿不到，
        // 改用 MediaStore 的 relativePath + title 拼出物理路径，避免照片被静默丢弃。
        final relative = entity.relativePath;
        final title = entity.title;
        if (relative != null &&
            relative.isNotEmpty &&
            title != null &&
            title.isNotEmpty) {
          var dir = relative.startsWith('/') ? relative : '/$relative';
          if (!dir.endsWith('/')) dir = '$dir/';
          final candidate = '/storage/emulated/0$dir$title';
          debugPrint(
            '[Scanner] file 为空，使用 MediaStore 路径兜底: id=${entity.id}, path=$candidate',
          );
          filePath = candidate;
        }
      }

      if (filePath == null) {
        debugPrint(
          '[Scanner] 无法获取文件路径，已跳过: id=${entity.id}, title=${entity.title}',
        );
        return null;
      }

      int fileSize = 0;
      try {
        fileSize = await File(filePath).length();
      } catch (_) {}

      String? location;
      if (entity.latitude != null && entity.longitude != null) {
        location =
            '${entity.latitude!.toStringAsFixed(4)}, ${entity.longitude!.toStringAsFixed(4)}';
      }

      return Photo(
        id: entity.id,
        path: filePath,
        thumbnailPath: filePath,
        date: date,
        location: location,
        category: null,
        fileSize: fileSize,
      );
    } catch (e) {
      return null;
    }
  }

  static bool isLocalFile(String path) {
    return !path.startsWith('assets/');
  }

  static bool isAssetPath(String path) {
    return path.startsWith('assets/');
  }
}

class _PhotoManagerScanResult {
  final List<Photo> photos;
  final bool success;
  final bool hasAssets;

  const _PhotoManagerScanResult(
    this.photos, {
    required this.success,
    required this.hasAssets,
  });
}
