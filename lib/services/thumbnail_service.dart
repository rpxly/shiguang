import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// 生成并缓存照片缩略图。
///
/// 缩略图写入 `<临时目录>/thumbs/<safeId>.jpg`：同一照片的 id 每次都会得到
/// 同一个文件名，重复扫描直接复用已有文件；目录被系统清理时会自动重建。
class ThumbnailService {
  // 512px：相簿封面/首页横幅等中等尺寸场景不糊；滑卡页大图已改用原图
  static const int thumbnailEdge = 512;
  static const int thumbnailQuality = 85;
  static const int maxFileNameLength = 120;
  // v2：换目录让旧版 256px 缩略图全部重新生成
  static const String _dirName = 'thumbs_v2';

  Future<String>? _dirPathFuture;

  /// 缩略图文件的预期路径（不保证目录已存在，写入时会创建）。
  Future<String> pathForId(String id) async {
    final dirPath = await _cachedDirPath();
    return '$dirPath${Platform.pathSeparator}${fileNameForId(id)}';
  }

  /// 把照片 id 转成安全文件名：非法字符替换为 `_`，总长度不超过 120。
  static String fileNameForId(String id) {
    var safe = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty) safe = 'thumb';
    const suffix = '.jpg';
    final maxStemLength = maxFileNameLength - suffix.length;
    if (safe.length > maxStemLength) {
      safe = safe.substring(0, maxStemLength);
    }
    return '$safe$suffix';
  }

  /// 缩略图文件是否存在且有内容。
  Future<bool> hasThumbnailFile(String path) async {
    if (path.isEmpty) return false;
    return _hasContent(File(path));
  }

  /// 为 [entity] 生成缩略图并返回文件路径；生成失败返回 null，调用方回退原图路径。
  Future<String?> generateForEntity(AssetEntity entity, String id) async {
    final path = await pathForId(id);
    final file = File(path);
    if (await _hasContent(file)) return path;

    Uint8List? data;
    try {
      data = await entity.thumbnailDataWithSize(
        const ThumbnailSize(thumbnailEdge, thumbnailEdge),
        quality: thumbnailQuality,
      );
    } catch (e) {
      debugPrint('[Thumb] 生成缩略图失败 $id: $e');
      return null;
    }
    if (data == null || data.isEmpty) return null;

    try {
      await _ensureDir();
      await file.writeAsBytes(data, flush: true);
      return path;
    } catch (e) {
      debugPrint('[Thumb] 写入缩略图失败 $id: $e');
      return null;
    }
  }

  Future<String> _cachedDirPath() async {
    final future = _dirPathFuture ??= _computeDirPath();
    try {
      return await future;
    } catch (_) {
      if (identical(_dirPathFuture, future)) _dirPathFuture = null;
      rethrow;
    }
  }

  Future<String> _computeDirPath() async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}${Platform.pathSeparator}$_dirName';
  }

  Future<void> _ensureDir() async {
    final dir = Directory(await _cachedDirPath());
    if (await dir.exists()) return;
    try {
      await dir.create(recursive: true);
    } on FileSystemException {
      // 并发创建时目录可能已被其它任务建好
    }
  }

  Future<bool> _hasContent(File file) async {
    try {
      if (!await file.exists()) return false;
      return await file.length() > 0;
    } catch (_) {
      return false;
    }
  }
}
