import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';

/// 相机品牌标识（用于水印上的品牌色点 / 品牌字标）
class PhotoBrand {
  /// 字标，如 LEICA / SONY；空串表示未识别
  final String label;
  final Color color;

  const PhotoBrand(this.label, this.color);

  bool get isEmpty => label.isEmpty;

  static const unknown = PhotoBrand('', Color(0xFF9AA0A6));
}

/// 从照片中解析出的 EXIF 拍摄信息。
///
/// 所有字段均为「已格式化好的展示文本」，直接用于水印排版：
/// 焦距 `24mm`、光圈 `f/1.63`、快门 `1/120s`、ISO `200`。
class PhotoExif {
  final String? make;
  final String? model;
  final String? lens;
  final String? focal;
  final String? aperture;
  final String? shutter;
  final String? iso;
  final DateTime? takenAt;
  final double? lat;
  final double? lng;

  const PhotoExif({
    this.make,
    this.model,
    this.lens,
    this.focal,
    this.aperture,
    this.shutter,
    this.iso,
    this.takenAt,
    this.lat,
    this.lng,
  });

  /// 完全没有相机信息（部分截图 / 社交软件转发图会这样）
  bool get isEmpty =>
      model == null && lens == null && focal == null && aperture == null && shutter == null && iso == null && takenAt == null;

  /// 机型展示名：去掉厂商前缀重复，如 "XIAOMI 23127PN0CC" 保留原样、"Apple iPhone 15 Pro" → "iPhone 15 Pro"
  String? get cameraName {
    if (model == null) return make;
    final m = model!.trim();
    final mk = (make ?? '').trim();
    if (mk.isEmpty) return m;
    if (m.toLowerCase().startsWith(mk.toLowerCase())) {
      final rest = m.substring(mk.length).trim();
      return rest.isEmpty ? m : rest;
    }
    return m;
  }

  /// 参数行：`24mm  f/1.63  1/120s  ISO 200`
  String get specLine {
    final parts = <String>[
      if (focal != null) focal!,
      if (aperture != null) aperture!,
      if (shutter != null) shutter!,
      if (iso != null) 'ISO $iso',
    ];
    return parts.join('   ');
  }

  bool get hasSpec => focal != null || aperture != null || shutter != null || iso != null;

  /// 用于界面提示的一行摘要（用完整机型名，便于用户确认识别对不对）
  String get summary {
    final name = model ?? make;
    final bits = <String>[
      if (name != null) name,
      if (hasSpec) specLine,
      if (takenAt != null) PhotoExif.formatDate(takenAt!),
    ];
    return bits.join(' · ');
  }

  static String two(int v) => v.toString().padLeft(2, '0');

  static String formatDate(DateTime d) => '${d.year}.${two(d.month)}.${two(d.day)}';

  static String formatDateTime(DateTime d) =>
      '${d.year}.${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// EXIF 读取与品牌识别。
class ExifService {
  static final Map<String, PhotoExif?> _cache = {};

  /// 读取照片 EXIF；无数据或解析失败返回 null。结果按路径缓存。
  static Future<PhotoExif?> read(File file) async {
    final key = file.path;
    if (_cache.containsKey(key)) return _cache[key];
    PhotoExif? result;
    try {
      final tags = await readExifFromFile(file);
      if (tags.isNotEmpty) result = _parse(tags);
    } catch (_) {
      // 非 JPEG / 损坏文件 / 无 EXIF 段：按「无信息」处理
      result = null;
    }
    _cache[key] = result;
    return result;
  }

  static void clearCache() => _cache.clear();

  static PhotoExif? _parse(Map<String, IfdTag> t) {
    final model = _str(t, 'Image Model');
    final exif = PhotoExif(
      make: _str(t, 'Image Make'),
      model: model,
      lens: _cleanLens(_str(t, 'EXIF LensModel'), model),
      focal: _focal(t),
      aperture: _aperture(t),
      shutter: _shutter(t),
      iso: _iso(t),
      takenAt: _date(t),
      lat: _gps(t, 'GPS GPSLatitude', 'GPS GPSLatitudeRef'),
      lng: _gps(t, 'GPS GPSLongitude', 'GPS GPSLongitudeRef'),
    );
    return exif.isEmpty ? null : exif;
  }

  static String? _str(Map<String, IfdTag> t, String key) {
    final v = t[key]?.printable.trim();
    if (v == null || v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower == 'unknown' || lower == 'n/a' || lower == '0') return null;
    return v;
  }

  static Ratio? _ratio(Map<String, IfdTag> t, String key) {
    final values = t[key]?.values;
    if (values is! IfdRatios) return null;
    final list = values.toList();
    if (list.isEmpty) return null;
    final r = list.first as Ratio;
    if (r.denominator == 0) return null;
    return r;
  }

  /// 优先 35mm 等效焦距（摄影师习惯读数：23mm / 35mm / 85mm），回退物理焦距
  static String? _focal(Map<String, IfdTag> t) {
    final eq = t['EXIF FocalLengthIn35mmFilm'] ?? t['EXIF FocalLengthIn35MmFilm'];
    if (eq != null) {
      final values = eq.values;
      if (values is IfdInts) {
        final list = values.toList();
        if (list.isNotEmpty) {
          final v = (list.first as int).toDouble();
          if (v > 0 && v < 2000) return '${_trimNum(v)}mm';
        }
      }
      final p = int.tryParse(eq.printable.trim());
      if (p != null && p > 0 && p < 2000) return '${p}mm';
    }
    final r = _ratio(t, 'EXIF FocalLength');
    if (r == null) return null;
    final v = r.numerator / r.denominator;
    if (v <= 0 || v > 2000) return null;
    return '${_trimNum(v)}mm';
  }

  /// 清洗镜头名：去掉重复的机型名与参数尾巴，常见词本地化
  static String? _cleanLens(String? raw, String? model) {
    if (raw == null) return null;
    var s = raw;
    if (model != null && model.trim().isNotEmpty) {
      s = s.replaceAll(RegExp(RegExp.escape(model.trim()), caseSensitive: false), ' ');
    }
    s = s.replaceAll(RegExp(r'\b\d+(\.\d+)?\s*mm\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\bf\s*/\s*\d+(\.\d+)?\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\bback\s+camera\b', caseSensitive: false), '后置主摄');
    s = s.replaceAll(RegExp(r'\bfront\s+camera\b', caseSensitive: false), '前置');
    s = s.replaceAll(RegExp(r'\b(ultra\s*wide|ultrawide)\b', caseSensitive: false), '超广角');
    s = s.replaceAll(RegExp(r'\btele\s*camera\b', caseSensitive: false), '长焦');
    s = s.replaceAll(RegExp(r'\b(telephoto|lens)\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? null : s;
  }

  /// f/1.63 / f/2.8
  static String? _aperture(Map<String, IfdTag> t) {
    final r = _ratio(t, 'EXIF FNumber');
    if (r == null) return null;
    final v = r.numerator / r.denominator;
    if (v <= 0 || v > 64) return null;
    return 'f/${_trimNum(v)}';
  }

  /// 1/120s / 2s
  static String? _shutter(Map<String, IfdTag> t) {
    final r = _ratio(t, 'EXIF ExposureTime');
    if (r == null) return null;
    final v = r.numerator / r.denominator;
    if (v <= 0) return null;
    if (v >= 1) return '${_trimNum(v)}s';
    final inv = r.denominator / r.numerator;
    return '1/${inv.round()}s';
  }

  static String? _iso(Map<String, IfdTag> t) {
    final tag = t['EXIF ISOSpeedRatings'] ?? t['EXIF PhotographicSensitivity'];
    if (tag == null) return null;
    final values = tag.values;
    if (values is IfdInts) {
      final list = values.toList();
      if (list.isEmpty) return null;
      final v = list.first as int;
      return v > 0 && v < 1000000 ? '$v' : null;
    }
    final p = tag.printable.trim();
    final parsed = int.tryParse(p);
    if (parsed == null || parsed <= 0) return null;
    return '$parsed';
  }

  static DateTime? _date(Map<String, IfdTag> t) {
    final raw = _str(t, 'EXIF DateTimeOriginal') ??
        _str(t, 'EXIF DateTimeDigitized') ??
        _str(t, 'Image DateTime');
    if (raw == null) return null;
    final m = RegExp(r'(\d{4})[:\-/](\d{2})[:\-/](\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(raw);
    if (m == null) return null;
    final y = int.parse(m[1]!);
    if (y < 1990 || y > 2100) return null;
    return DateTime(
      y,
      int.parse(m[2]!),
      int.parse(m[3]!),
      int.parse(m[4]!),
      int.parse(m[5]!),
      int.parse(m[6]!),
    );
  }

  static double? _gps(Map<String, IfdTag> t, String key, String refKey) {
    final values = t[key]?.values;
    if (values is! IfdRatios) return null;
    final list = values.toList();
    if (list.length < 3) return null;
    double part(Ratio r) => r.denominator == 0 ? 0 : r.numerator / r.denominator;
    var v = part(list[0] as Ratio) + part(list[1] as Ratio) / 60 + part(list[2] as Ratio) / 3600;
    final ref = t[refKey]?.printable.trim().toUpperCase();
    if (ref == 'S' || ref == 'W') v = -v;
    if (v.abs() < 0.0001) return null;
    return v;
  }

  /// 去掉多余的 .0，最多保留一位小数（f/1.63 这类保留两位）
  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// 根据厂商 / 型号识别相机品牌，返回字标与品牌色
  static PhotoBrand brandOf(String? make, String? model) {
    final s = '${make ?? ''} ${model ?? ''}'.toUpperCase();
    if (s.trim().isEmpty) return PhotoBrand.unknown;
    bool has(List<String> keys) => keys.any((k) => s.contains(k));

    if (has(['LEICA'])) return const PhotoBrand('LEICA', Color(0xFFE20612));
    if (has(['HASSELBLAD', 'HASSEL'])) return const PhotoBrand('HASSELBLAD', Color(0xFFF0A500));
    if (has(['SONY', 'ILCE', 'ILDC', 'DSC-'])) return const PhotoBrand('SONY', Color(0xFFF26F21));
    if (has(['FUJIFILM', 'FUJI', 'X-T', 'X100'])) return const PhotoBrand('FUJIFILM', Color(0xFF00843D));
    if (has(['CANON'])) return const PhotoBrand('CANON', Color(0xFFCC0000));
    if (has(['NIKON'])) return const PhotoBrand('NIKON', Color(0xFFFFE100));
    if (has(['APPLE', 'IPHONE'])) return const PhotoBrand('Apple', Color(0xFFEDEDED));
    if (has(['XIAOMI', 'REDMI', 'POCO', '2312', '2307'])) return const PhotoBrand('XIAOMI', Color(0xFFFF6900));
    if (has(['HUAWEI', 'HONOR', 'HMA-', 'ALN-'])) return const PhotoBrand('HUAWEI', Color(0xFFCF0A2C));
    if (has(['VIVO', 'IQOO'])) return const PhotoBrand('vivo', Color(0xFF415FFF));
    if (has(['OPPO', 'ONEPLUS', 'REALME', 'PJZ', 'PHK'])) return const PhotoBrand('OPPO', Color(0xFF1D7A46));
    if (has(['SAMSUNG', 'SM-'])) return const PhotoBrand('SAMSUNG', Color(0xFF1428A0));
    if (has(['GOOGLE', 'PIXEL'])) return const PhotoBrand('Google', Color(0xFF4285F4));
    if (has(['MOTOROLA', 'MOTO '])) return const PhotoBrand('motorola', Color(0xFF5BC2E7));
    return PhotoBrand.unknown;
  }
}
