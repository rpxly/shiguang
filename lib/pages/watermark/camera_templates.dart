import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/exif_service.dart';
import '../../theme.dart';

/// 相机水印落点（四角）
enum CamPos { bottomLeft, bottomRight, topLeft, topRight }

const camPosLabels = {
  CamPos.bottomLeft: '左下',
  CamPos.bottomRight: '右下',
  CamPos.topLeft: '左上',
  CamPos.topRight: '右上',
};

/// 可独立开关的水印元素（对齐专业 App 的「逐项开关」）
enum CamElement { brand, model, lens, focal, aperture, shutter, iso, date, place }

const camElementLabels = {
  CamElement.brand: '品牌标',
  CamElement.model: '机型',
  CamElement.lens: '镜头',
  CamElement.focal: '焦距',
  CamElement.aperture: '光圈',
  CamElement.shutter: '快门',
  CamElement.iso: 'ISO',
  CamElement.date: '日期',
  CamElement.place: '地点',
};

/// 相机水印模板
enum CamTpl { whiteBar, blackBar, exifCard, vertical, minimal, film }

const camTplLabels = {
  CamTpl.whiteBar: '经典白条',
  CamTpl.blackBar: '暗夜黑条',
  CamTpl.exifCard: 'EXIF 卡片',
  CamTpl.vertical: '竖排',
  CamTpl.minimal: '极简一行',
  CamTpl.film: '胶片边',
};

/// 底条类模板（会扩展画布高度，文字配色由模板固定）
const camBarTemplates = {CamTpl.whiteBar, CamTpl.blackBar, CamTpl.film};

/// 一张照片的水印数据（由 EXIF 自动填充，可被用户手动覆盖）
class CameraMarkData {
  final PhotoBrand brand;
  final String? model;
  final String? lens;
  final String? focal;
  final String? aperture;
  final String? shutter;
  final String? iso;
  final DateTime? takenAt;
  final String? place;
  final Set<CamElement> elements;

  const CameraMarkData({
    this.brand = PhotoBrand.unknown,
    this.model,
    this.lens,
    this.focal,
    this.aperture,
    this.shutter,
    this.iso,
    this.takenAt,
    this.place,
    this.elements = const {
      CamElement.brand,
      CamElement.model,
      CamElement.focal,
      CamElement.aperture,
      CamElement.shutter,
      CamElement.iso,
      CamElement.date,
      CamElement.place,
    },
  });

  bool _on(CamElement e) => elements.contains(e);

  String? get brandText => _on(CamElement.brand) && !brand.isEmpty ? brand.label : null;
  String? get modelText => _on(CamElement.model) ? _nonEmpty(model) : null;
  String? get lensText => _on(CamElement.lens) ? _nonEmpty(lens) : null;

  /// 参数行：`24mm  f/1.63  1/120s  ISO 200`
  String? get specText {
    final parts = <String>[
      if (_on(CamElement.focal) && _nonEmpty(focal) != null) focal!,
      if (_on(CamElement.aperture) && _nonEmpty(aperture) != null) aperture!,
      if (_on(CamElement.shutter) && _nonEmpty(shutter) != null) shutter!,
      if (_on(CamElement.iso) && _nonEmpty(iso) != null) 'ISO $iso',
    ];
    return parts.isEmpty ? null : parts.join('   ');
  }

  String? get dateText =>
      _on(CamElement.date) && takenAt != null ? PhotoExif.formatDate(takenAt!) : null;

  String? get timeText =>
      _on(CamElement.date) && takenAt != null ? PhotoExif.formatDateTime(takenAt!) : null;

  String? get placeText => _on(CamElement.place) ? _nonEmpty(place) : null;

  bool get hasContent =>
      brandText != null ||
      modelText != null ||
      lensText != null ||
      specText != null ||
      dateText != null ||
      placeText != null;

  static String? _nonEmpty(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// 绘制相机水印，返回输出画布尺寸（底条模板会变高，其余等于 [dest] 或原图尺寸）。
///
/// [fs] 为基准字号（调用方已按图片宽度换算好），所有尺寸都由它推导，保证不同分辨率下比例一致。
/// [dest] 为图片绘制目标区域（预览时传缩放后的矩形）；导出时传 null，按原图尺寸绘制。
/// [drag] 为用户拖动产生的额外偏移（与 [dest] 同一坐标单位），仅对浮层模板生效。
Size paintCameraTemplate(
  Canvas canvas,
  ui.Image image,
  CameraMarkData d, {
  required CamTpl tpl,
  required double fs,
  required Color color,
  required double opacity,
  required String? fontFamily,
  required CamPos pos,
  required bool forPreview,
  Rect? dest,
  Offset drag = Offset.zero,
}) {
  final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final rect = dest ?? src;
  final w = rect.width;
  final h = rect.height;

  if (!d.hasContent) {
    canvas.drawImageRect(image, src, rect, Paint());
    return Size(w, h);
  }

  final shadows = forPreview
      ? null
      : <Shadow>[Shadow(color: Colors.black.withOpacity(0.32), blurRadius: fs * 0.28)];

  switch (tpl) {
    case CamTpl.whiteBar:
      return _paintBar(canvas, image, src, rect, d, w, h, fs, fontFamily, light: true);
    case CamTpl.blackBar:
      return _paintBar(canvas, image, src, rect, d, w, h, fs, fontFamily, light: false);
    case CamTpl.exifCard:
      return _paintCard(
          canvas, image, src, rect, d, w, h, fs, color, opacity, fontFamily, pos, shadows, drag);
    case CamTpl.vertical:
      return _paintVertical(
          canvas, image, src, rect, d, w, h, fs, color, opacity, fontFamily, pos, shadows, drag);
    case CamTpl.minimal:
      return _paintMinimal(
          canvas, image, src, rect, d, w, h, fs, color, opacity, fontFamily, pos, shadows, drag);
    case CamTpl.film:
      return _paintFilm(canvas, image, src, rect, d, w, h, fs, fontFamily);
  }
}

// ────────────────────────── 通用工具 ──────────────────────────

TextPainter _tp(
  String text,
  double size, {
  required Color color,
  bool bold = false,
  double ls = 1.0,
  String? family,
  double? maxW,
  List<Shadow>? shadows,
  int maxLines = 1,
}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontFamily: family,
        fontWeight: bold ? AppFontWeights.semibold : AppFontWeights.normal,
        color: color,
        letterSpacing: ls,
        height: 1.22,
        shadows: shadows,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxW ?? double.infinity);
}

/// 四角落点
Rect _anchor(double w, double h, double pad, double bw, double bh, CamPos pos) {
  switch (pos) {
    case CamPos.bottomLeft:
      return Rect.fromLTWH(pad, h - pad - bh, bw, bh);
    case CamPos.bottomRight:
      return Rect.fromLTWH(w - pad - bw, h - pad - bh, bw, bh);
    case CamPos.topLeft:
      return Rect.fromLTWH(pad, pad, bw, bh);
    case CamPos.topRight:
      return Rect.fromLTWH(w - pad - bw, pad, bw, bh);
  }
}

void _brandDot(Canvas canvas, Offset center, double r, PhotoBrand brand, {required bool onDark}) {
  final fill = Paint()..color = brand.color;
  canvas.drawCircle(center, r, fill);
  // 浅色品牌标（Apple 等）在浅底上补一圈描边，避免看不见
  final needsEdge = onDark ? brand.color.computeLuminance() > 0.75 : brand.color.computeLuminance() > 0.9;
  if (needsEdge) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, r * 0.18)
        ..color = onDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.25),
    );
  }
}

// ────────────────────────── 经典白条 / 暗夜黑条 ──────────────────────────

Size _paintBar(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect rect,
  CameraMarkData d,
  double w,
  double h,
  double fs,
  String? family, {
  required bool light,
}) {
  final bg = light ? const Color(0xFFFAFAF7) : const Color(0xFF0B0B0C);
  final ink = light ? const Color(0xFF17171A) : const Color(0xFFF2EFE9);

  final barH = math.max(fs * 2.75, w * 0.095);
  final outH = h + barH;
  canvas.drawRect(Rect.fromLTWH(0, 0, w, outH), Paint()..color = bg);
  canvas.drawImageRect(image, src, rect, Paint());

  final padX = w * 0.048;
  final gap = fs * 0.24;

  // 左列：机型（含品牌点）+ 参数
  final modelTp = d.modelText == null
      ? null
      : _tp(d.modelText!, fs * 1.02, color: ink, bold: true, ls: 0.6, family: family, maxW: w * 0.60);
  final brandOnlyTp = (modelTp == null && d.brandText != null)
      ? _tp(d.brandText!, fs * 1.02, color: ink, bold: true, ls: 2.2, family: family, maxW: w * 0.60)
      : null;
  final specTp = d.specText == null
      ? null
      : _tp(d.specText!, fs * 0.70, color: ink.withOpacity(0.60), ls: 1.4, family: family, maxW: w * 0.74);
  final lensTp = d.lensText == null
      ? null
      : _tp(d.lensText!, fs * 0.60, color: ink.withOpacity(0.42), ls: 0.6, family: family, maxW: w * 0.74);

  // 右列：日期 + 地点
  final dateTp = d.dateText == null
      ? null
      : _tp(d.dateText!, fs * 0.78, color: ink.withOpacity(0.86), ls: 1.6, family: family);
  final placeTp = d.placeText == null
      ? null
      : _tp(d.placeText!.toUpperCase(), fs * 0.66, color: ink.withOpacity(0.52), ls: 1.6, family: family);
  final timeTp = (d.dateText == null && d.timeText != null)
      ? _tp(d.timeText!, fs * 0.78, color: ink.withOpacity(0.86), ls: 1.4, family: family)
      : null;

  final leftRows = <TextPainter?>[modelTp ?? brandOnlyTp, specTp, lensTp].whereType<TextPainter>().toList();
  final rightRows = <TextPainter?>[dateTp ?? timeTp, placeTp].whereType<TextPainter>().toList();

  double blockH(List<TextPainter> rows) {
    if (rows.isEmpty) return 0;
    return rows.fold<double>(0, (a, e) => a + e.height) + gap * (rows.length - 1);
  }

  final leftH = blockH(leftRows);
  final rightH = blockH(rightRows);
  final topY = h + (barH - math.max(leftH, rightH)) / 2;

  // 左列
  var y = topY;
  final r = fs * 0.20;
  final showDot = d.brandText != null || (d.modelText != null && !d.brand.isEmpty);
  final textX = padX + (showDot ? r * 2 + fs * 0.26 : 0);
  if (leftRows.isNotEmpty) {
    final first = leftRows.first;
    if (showDot && !d.brand.isEmpty) {
      _brandDot(canvas, Offset(padX + r, y + first.height / 2), r, d.brand, onDark: !light);
    } else if (showDot) {
      _brandDot(canvas, Offset(padX + r, y + first.height / 2), r, PhotoBrand.unknown, onDark: !light);
    }
    for (final p in leftRows) {
      p.paint(canvas, Offset(textX, y));
      y += p.height + gap;
      p.dispose();
    }
  } else if (showDot && !d.brand.isEmpty) {
    _brandDot(canvas, Offset(padX + r, topY + barH / 2 - gap), r, d.brand, onDark: !light);
  }

  // 右列（右对齐）
  var ry = h + (barH - rightH) / 2;
  for (final p in rightRows) {
    p.paint(canvas, Offset(w - padX - p.width, ry));
    ry += p.height + gap;
    p.dispose();
  }

  return Size(w, outH);
}

// ────────────────────────── EXIF 卡片 ──────────────────────────

Size _paintCard(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect rect,
  CameraMarkData d,
  double w,
  double h,
  double fs,
  Color color,
  double opacity,
  String? family,
  CamPos pos,
  List<Shadow>? shadows,
  Offset drag,
) {
  canvas.drawImageRect(image, src, rect, Paint());

  final lines = <TextPainter>[];
  if (d.brandText != null) {
    lines.add(_tp(d.brandText!, fs * 0.56,
        color: d.brand.color.computeLuminance() > 0.75 ? color.withOpacity(opacity) : d.brand.color,
        bold: true,
        ls: 2.6,
        family: family));
  }
  if (d.modelText != null) {
    lines.add(_tp(d.modelText!, fs * 1.08,
        color: color.withOpacity(opacity), bold: true, ls: 0.2, family: family, maxW: w * 0.62, shadows: shadows));
  }
  if (d.lensText != null) {
    lines.add(_tp(d.lensText!, fs * 0.62,
        color: color.withOpacity(opacity * 0.68), ls: 0.4, family: family, maxW: w * 0.62, shadows: shadows));
  }
  if (d.specText != null) {
    lines.add(_tp(d.specText!, fs * 0.70,
        color: color.withOpacity(opacity * 0.86), ls: 0.8, family: family, maxW: w * 0.62, shadows: shadows));
  }
  final meta = [d.dateText, d.placeText].whereType<String>().join('   ·   ');
  if (meta.isNotEmpty) {
    lines.add(_tp(meta, fs * 0.60,
        color: color.withOpacity(opacity * 0.66), ls: 1.0, family: family, maxW: w * 0.62, shadows: shadows));
  }
  if (lines.isEmpty) return Size(w, h);

  final gap = fs * 0.22;
  final innerW = lines.map((e) => e.width).reduce(math.max);
  final innerH = lines.fold<double>(0, (a, e) => a + e.height) + gap * (lines.length - 1);
  final padH = fs * 0.85;
  final padV = fs * 0.68;
  final pad = math.max(fs * 1.0, w * 0.035);
  final box = _anchor(w, h, pad, innerW + padH * 2, innerH + padV * 2, pos).shift(drag);

  // 左侧强调竖条 + 半透明底
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, Radius.circular(fs * 0.30)),
    Paint()..color = Colors.black.withOpacity(0.40),
  );
  canvas.drawRect(
    Rect.fromLTWH(box.left, box.top, math.max(1.5, fs * 0.10), box.height),
    Paint()..color = d.brand.isEmpty ? color.withOpacity(opacity) : d.brand.color,
  );

  var y = box.top + padV;
  for (final p in lines) {
    p.paint(canvas, Offset(box.left + padH + fs * 0.2, y));
    y += p.height + gap;
    p.dispose();
  }
  return Size(w, h);
}

// ────────────────────────── 竖排 ──────────────────────────

Size _paintVertical(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect rect,
  CameraMarkData d,
  double w,
  double h,
  double fs,
  Color color,
  double opacity,
  String? family,
  CamPos pos,
  List<Shadow>? shadows,
  Offset drag,
) {
  canvas.drawImageRect(image, src, rect, Paint());

  final groups = <String>[
    if (d.timeText != null || d.dateText != null) d.timeText ?? d.dateText!,
    if (d.modelText != null) d.modelText!,
    if (d.placeText != null) d.placeText!,
  ];
  if (groups.isEmpty) return Size(w, h);

  final size = fs * 0.86;
  final charGap = size * 0.14;
  final colGap = size * 0.86;
  final pad = math.max(fs * 1.1, w * 0.04);

  // 每列：逐字排版的 TextPainter 列表
  final columns = <List<TextPainter>>[];
  for (final g in groups) {
    final chars = g.runes.map(String.fromCharCode).toList();
    columns.add(chars
        .map((c) => _tp(c, size, color: color.withOpacity(opacity), ls: 0, family: family, shadows: shadows))
        .toList());
  }

  double colWidth(List<TextPainter> col) => col.isEmpty ? 0 : col.map((e) => e.width).reduce(math.max);
  double colHeight(List<TextPainter> col) =>
      col.isEmpty ? 0 : col.fold<double>(0, (a, e) => a + e.height) + charGap * (col.length - 1);

  final widths = columns.map(colWidth).toList();
  final heights = columns.map(colHeight).toList();
  final totalW = widths.fold<double>(0, (a, v) => a + v) + colGap * (columns.length - 1);

  final onRight = pos == CamPos.topRight || pos == CamPos.bottomRight;
  final onTop = pos == CamPos.topLeft || pos == CamPos.topRight;

  // 从贴边一侧向内排列
  var x = (onRight ? w - pad : pad + totalW) + drag.dx;
  final maxH = math.max(heights.reduce(math.max), 1.0);
  final startY = (onTop ? pad : h - pad - maxH) + drag.dy;

  for (var i = 0; i < columns.length; i++) {
    final col = columns[i];
    final cw = widths[i];
    final left = onRight ? x - cw : x;
    var y = startY + (maxH - heights[i]) / 2;
    for (final p in col) {
      p.paint(canvas, Offset(left + (cw - p.width) / 2, y));
      y += p.height + charGap;
      p.dispose();
    }
    x += onRight ? -(cw + colGap) : (cw + colGap);
  }

  // 分隔竖线
  final lineX = onRight ? w - pad - totalW - colGap * 0.7 : pad + totalW + colGap * 0.7;
  canvas.drawRect(
    Rect.fromLTWH(lineX, startY, math.max(1.0, size * 0.045), maxH),
    Paint()..color = color.withOpacity(opacity * 0.55),
  );

  return Size(w, h);
}

// ────────────────────────── 极简一行 ──────────────────────────

Size _paintMinimal(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect rect,
  CameraMarkData d,
  double w,
  double h,
  double fs,
  Color color,
  double opacity,
  String? family,
  CamPos pos,
  List<Shadow>? shadows,
  Offset drag,
) {
  canvas.drawImageRect(image, src, rect, Paint());

  final parts = <String>[
    if (d.modelText != null) d.modelText!,
    if (d.specText != null) d.specText!,
    if (d.dateText != null) d.dateText!,
    if (d.placeText != null) d.placeText!.toUpperCase(),
  ];
  if (parts.isEmpty) return Size(w, h);

  final p = _tp(
    parts.join('  ·  '),
    fs * 0.74,
    color: color.withOpacity(opacity),
    ls: 1.0,
    family: family,
    maxW: w - math.max(fs * 2.0, w * 0.08),
    shadows: shadows,
  );
  final pad = math.max(fs * 1.1, w * 0.04);
  final box = _anchor(w, h, pad, p.width, p.height, pos).shift(drag);
  p.paint(canvas, box.topLeft);
  p.dispose();
  return Size(w, h);
}

// ────────────────────────── 胶片边 ──────────────────────────

Size _paintFilm(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect rect,
  CameraMarkData d,
  double w,
  double h,
  double fs,
  String? family,
) {
  const frame = Color(0xFF08080A);
  const ink = Color(0xFFE8E4DC);

  final barH = math.max(fs * 1.5, h * 0.075);
  final outH = h + barH * 2;
  canvas.drawRect(Rect.fromLTWH(0, 0, w, outH), Paint()..color = frame);
  canvas.drawImageRect(image, src, rect.shift(Offset(0, barH)), Paint());

  final padX = w * 0.045;

  // 底栏：左 机型+参数，右 日期
  final leftParts = <String>[
    if (d.modelText != null) d.modelText!,
    if (d.specText != null) d.specText!,
  ];
  final leftTp = leftParts.isEmpty
      ? null
      : _tp(leftParts.join('   '), fs * 0.62, color: ink.withOpacity(0.82), ls: 1.2, family: family, maxW: w * 0.66);
  final rightTp = d.dateText == null
      ? null
      : _tp(d.dateText!, fs * 0.62, color: ink.withOpacity(0.55), ls: 1.6, family: family);

  final bottomCenterY = h + barH + barH / 2;
  if (leftTp != null) {
    leftTp.paint(canvas, Offset(padX, bottomCenterY - leftTp.height / 2));
    leftTp.dispose();
  }
  if (rightTp != null) {
    rightTp.paint(canvas, Offset(w - padX - rightTp.width, bottomCenterY - rightTp.height / 2));
    rightTp.dispose();
  }

  // 顶栏：地点（左） + 品牌标（右）
  final topCenterY = barH / 2;
  if (d.placeText != null) {
    final topTp =
        _tp(d.placeText!.toUpperCase(), fs * 0.60, color: ink.withOpacity(0.55), ls: 2.0, family: family);
    topTp.paint(canvas, Offset(padX, topCenterY - topTp.height / 2));
    topTp.dispose();
  }
  if (d.brandText != null) {
    final bTp = _tp(d.brandText!, fs * 0.58, color: ink.withOpacity(0.75), bold: true, ls: 2.6, family: family);
    final r = fs * 0.18;
    bTp.paint(canvas, Offset(w - padX - bTp.width - r * 2 - fs * 0.3, topCenterY - bTp.height / 2));
    _brandDot(canvas, Offset(w - padX - r, topCenterY), r, d.brand, onDark: true);
    bTp.dispose();
  }

  return Size(w, outH);
}
