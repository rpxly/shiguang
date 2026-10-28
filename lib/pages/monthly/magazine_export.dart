import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/photo.dart';
import '../../services/analytics_service.dart';
import '../../services/image_helper.dart';
import '../../services/magazine_draft_service.dart';

/// 导出用画布尺寸（逻辑像素）。A4 比例 1:1.414，导出时乘 3 得
/// 2400×3394，约 289dpi，够家用打印。
const double kExportPageWidth = 800;
const double kExportPageHeight = 1131;

/// 导出时的解码宽度。封面是整幅铺满，需要比内容页更高的解码尺寸。
const int _coverDecodeWidth = 2000;
const int _contentDecodeWidth = 1400;

// ── 版面色板 ───────────────────────────────────────────────────
// 导出件是「纸」，不跟随 App 主题：白纸黑字 + 极少灰阶，打印出来才立得住。
// 纸色：不是纯白，略带一点暖 —— 纯白在屏幕上是「网页背景」，
// 带暖的纸色才有「印在纸上」的错觉。单页与多页统一用这一色。
const Color _paper = Color(0xFFFBFAF7);
const Color _ink = Color(0xFF141414);
const Color _inkSoft = Color(0xFF5E5E5E);
const Color _sub = Color(0xFF8C8C8C);
const Color _hair = Color(0xFFE6E6E6);
const Color _night = Color(0xFF141414);

/// 一页导出需要的外部数据。
class MagazineExportSpec {
  const MagazineExportSpec({
    required this.year,
    required this.month,
    required this.photos,
    this.summary = '',
    this.keywords = const [],
    this.dayCount = 0,
    this.nightCount = 0,
    this.favoriteCount = 0,
    this.sceneOf,
    this.placeOf,
    this.ratioOf,
  });

  final int year;
  final int month;
  final List<Photo> photos;
  final String summary;
  final List<String> keywords;
  final int dayCount;
  final int nightCount;
  final int favoriteCount;
  final String? Function(String photoId)? sceneOf;
  final String? Function(String? location)? placeOf;

  /// 照片原始宽高比（宽 / 高）。
  ///
  /// 单页是**不许裁图**的：以前的 `BoxFit.cover` 把 3:2 的横图塞进 402×530 的
  /// 竖格子，左右各切掉 30%，人常常被切在边上。现在按真实比例排版，
  /// 返回 null 表示"尺寸还没解析出来"，此时按 1:1 兜底（最多裁成方形，不会溢出）。
  final double? Function(String path)? ratioOf;
}

/// 导出总页数：封面 1 + 内容页（每页 3 张）+ 版权页 1。
int exportPageCount(int photoCount) {
  if (photoCount <= 0) return 0;
  return 1 + (photoCount / 3).ceil() + 1;
}

/// 生成全部导出页。[keys] 与返回列表一一对应，用于逐页截图。
List<Widget> buildExportPages(
  BuildContext context,
  MagazineExportSpec spec,
  List<GlobalKey> keys,
) {
  final pages = <Widget>[];
  final content = _chunk(spec.photos, 3);
  var pageNo = 1;

  pages.add(_wrap(keys, 0, _CoverPage(spec: spec, pageNo: pageNo++)));
  for (var i = 0; i < content.length; i++) {
    pages.add(_wrap(
      keys,
      pages.length,
      _ContentPage(
        spec: spec,
        photos: content[i],
        pageNo: pageNo++,
        isFirstContent: i == 0,
      ),
    ));
  }
  pages.add(_wrap(keys, pages.length, _ColophonPage(spec: spec, pageNo: pageNo)));

  return pages;
}

Widget _wrap(List<GlobalKey> keys, int index, Widget page) {
  return RepaintBoundary(
    key: index < keys.length ? keys[index] : null,
    child: SizedBox(
      width: kExportPageWidth,
      height: kExportPageHeight,
      child: page,
    ),
  );
}

List<List<Photo>> _chunk(List<Photo> photos, int size) {
  final result = <List<Photo>>[];
  for (var i = 0; i < photos.length; i += size) {
    result.add(photos.sublist(i, math.min(i + size, photos.length)));
  }
  return result;
}

// ── 封面 ──────────────────────────────────────────────────────
class _CoverPage extends StatelessWidget {
  const _CoverPage({required this.spec, required this.pageNo});

  final MagazineExportSpec spec;
  final int pageNo;

  @override
  Widget build(BuildContext context) {
    final cover = spec.photos.isNotEmpty ? spec.photos.first : null;
    final summary = _firstSentences(spec.summary, 2);

    return Container(
      color: _paper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            LocalImage(
              path: cover.path,
              fit: BoxFit.cover,
              cacheWidth: _coverDecodeWidth,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)),
            )
          else
            const ColoredBox(color: Color(0xFF2A2A2A)),
          // 底部渐变：让文字压在图上还读得清
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x33000000), Color(0xE6000000)],
                stops: [0.35, 0.62, 1.0],
              ),
            ),
          ),
          // 顶部两角：卷号 / 刊名
          Positioned(
            left: 56,
            top: 52,
            child: Text(
              'VOL.${spec.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Positioned(
            right: 56,
            top: 52,
            child: Text(
              '拾光 SHIGUANG',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 4,
              ),
            ),
          ),
          // 标题块
          Positioned(
            left: 56,
            right: 56,
            bottom: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '二〇二六 · ${_chineseMonth(spec.month)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${spec.month}月',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    color: Colors.white,
                    fontSize: 104,
                    height: 0.95,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 22),
                Container(width: 56, height: 1, color: Colors.white38),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.9,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 56,
            bottom: 40,
            child: Text(
              '${spec.photos.length} 张照片 · ${spec.dayCount} 天',
              style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2),
            ),
          ),
          Positioned(
            right: 56,
            bottom: 38,
            child: _PageNumber(text: pageNo.toString().padLeft(2, '0'), light: true),
          ),
        ],
      ),
    );
  }
}

// ── 内容页 ────────────────────────────────────────────────────
class _ContentPage extends StatelessWidget {
  const _ContentPage({
    required this.spec,
    required this.photos,
    required this.pageNo,
    required this.isFirstContent,
  });

  final MagazineExportSpec spec;
  final List<Photo> photos;
  final int pageNo;
  final bool isFirstContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _paper,
      padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页眉：左边内容索引，右边刊名
          Row(
            children: [
              Text(
                '${spec.year} / ${spec.month.toString().padLeft(2, '0')}',
                style: const TextStyle(color: _sub, fontSize: 11, letterSpacing: 3),
              ),
              const Spacer(),
              const Text(
                '拾光月刊',
                style: TextStyle(color: _sub, fontSize: 11, letterSpacing: 3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _hair),
          const SizedBox(height: 26),
          Expanded(child: _buildBody()),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                isFirstContent ? '本月影像' : '影像',
                style: const TextStyle(color: _sub, fontSize: 10, letterSpacing: 3),
              ),
              const Spacer(),
              _PageNumber(text: pageNo.toString().padLeft(2, '0')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (photos.length) {
      case 1:
        return _single();
      case 2:
        return _pair();
      default:
        return _heroAndPair();
    }
  }

  /// 1 张：留白最多，图居中偏上，图注跟在下面。
  Widget _single() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(flex: 2),
        _figure(photos[0], height: 560, decodeWidth: _coverDecodeWidth),
        const Spacer(flex: 3),
      ],
    );
  }

  /// 2 张：上下等分，节奏平。
  Widget _pair() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _figure(photos[0], height: 380, decodeWidth: _contentDecodeWidth),
        const SizedBox(height: 30),
        _figure(photos[1], height: 380, decodeWidth: _contentDecodeWidth),
      ],
    );
  }

  /// 3 张：一大两小，杂志里最常见的图文节奏。
  Widget _heroAndPair() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _figure(photos[0], height: 470, decodeWidth: _coverDecodeWidth),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _figure(photos[1], height: 250, decodeWidth: _contentDecodeWidth)),
            const SizedBox(width: 18),
            Expanded(child: _figure(photos[2], height: 250, decodeWidth: _contentDecodeWidth)),
          ],
        ),
      ],
    );
  }

  /// 图 + 图注。图注只用真实数据（场景词/地名/日期），规则见 MagazineDraftService。
  Widget _figure(Photo photo, {required double height, required int decodeWidth}) {
    final caption = captionOf(photo, spec);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: LocalImage(
            path: photo.path,
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFEDEDED),
              child: Center(
                child: Icon(Icons.image_outlined, color: Color(0xFFBDBDBD), size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _inkSoft, fontSize: 11, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${photo.dateTime.month.toString().padLeft(2, '0')}.'
              '${photo.dateTime.day.toString().padLeft(2, '0')}',
              style: const TextStyle(color: _sub, fontSize: 10, letterSpacing: 1),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 版权/统计页 ───────────────────────────────────────────────
class _ColophonPage extends StatelessWidget {
  const _ColophonPage({required this.spec, required this.pageNo});

  final MagazineExportSpec spec;
  final int pageNo;

  @override
  Widget build(BuildContext context) {
    final stats = <String>[
      '${spec.photos.length} 张照片',
      if (spec.dayCount > 0) '${spec.dayCount} 天',
      if (spec.nightCount > 0) '${spec.nightCount} 个夜晚',
      if (spec.favoriteCount > 0) '${spec.favoriteCount} 张收藏',
    ];

    return Container(
      color: _night,
      padding: const EdgeInsets.fromLTRB(56, 56, 56, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 3),
          Text(
            '${spec.year} · ${_chineseMonth(spec.month)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 8),
          ),
          const SizedBox(height: 26),
          Text(
            '${spec.photos.length}',
            style: const TextStyle(
              fontFamily: 'serif',
              color: Colors.white,
              fontSize: 110,
              height: 1,
              fontWeight: FontWeight.w200,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '张照片，组成了这个月',
            style: TextStyle(color: Colors.white70, fontSize: 17, letterSpacing: 2, height: 1.6),
          ),
          const SizedBox(height: 30),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 20),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              for (final stat in stats)
                Text(
                  stat,
                  style: const TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 1.5),
                ),
            ],
          ),
          if (spec.keywords.isNotEmpty) ...[
            const SizedBox(height: 34),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final keyword in spec.keywords)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      keyword,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1),
                    ),
                  ),
              ],
            ),
          ],
          const Spacer(flex: 4),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '拾光 SHIGUANG · 用照片记录时间',
                style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2),
              ),
              const Spacer(),
              _PageNumber(text: pageNo.toString().padLeft(2, '0'), light: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({required this.text, this.light = false});

  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: light ? Colors.white38 : _sub,
        fontSize: 10,
        letterSpacing: 2,
      ),
    );
  }
}

// ── 文字工具 ──────────────────────────────────────────────────

/// 图注：与一键成刊、时间线共用同一套规则（`magazineCaption`），
/// 导出件里不能出现另一种说法。
String captionOf(Photo photo, MagazineExportSpec spec) => magazineCaption(
      photo,
      scene: spec.sceneOf?.call(photo.id),
      place: spec.placeOf?.call(photo.location),
    );

String _chineseMonth(int month) {
  const names = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];
  return '${names[(month - 1).clamp(0, 11)]}月';
}

/// 取前 [maxSentences] 句，避免封面被长摘要挤满。
String _firstSentences(String text, int maxSentences) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  final buffer = StringBuffer();
  var count = 0;
  for (final rune in trimmed.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(char);
    if ('。！？!?'.contains(char)) {
      count++;
      if (count >= maxSentences) break;
    }
  }
  return buffer.toString();
}

// ── 单页版：一页排完，直接能发 ────────────────────────────────

/// 单页月刊：所有照片排在一页 A4 上。
///
/// 相比旧版的改动都在「让一页像杂志」这件事上：
/// - 抬头有字号层级（年份小、月份大、卷号极小），不再是一行平字
/// - 第一张做成 hero 大图，其余按行等分；旧版全部等大，等于缩略图墙
/// - 图注只压在 hero 上（图上渐变 + 白字），小图只留日期戳，不塞满
/// - 去掉圆角与投影：印刷件用直角，投影在白纸上显脏
/// - 底部落款 + 页码，让单页也有「成册」的收口
Widget buildSingleExportPage(BuildContext context, MagazineExportSpec spec, GlobalKey key) {
  return RepaintBoundary(
    key: key,
    child: SizedBox(
      width: kExportPageWidth,
      height: kExportPageHeight,
      child: _SinglePage(spec: spec),
    ),
  );
}

/// 图版里的一行：同一行的图**等高**，宽度各自按原始比例算，
/// 所以整行恰好铺满版心，且一刀不裁。
class _PlateRow {
  const _PlateRow(this.photos, this.height);
  final List<Photo> photos;
  final double height;
}

/// 排版结果的一行：照片下标 + 行高。纯数据，方便单测。
class PlateRowPlan {
  const PlateRowPlan(this.indices, this.height);
  final List<int> indices;
  final double height;
}

/// 图版排版：给定各图宽高比与可用区域，决定分成几行、每行多高。
///
/// 这是"不裁图"的代价 —— 既然不能靠裁切把任意照片塞进固定格子，就只能反过来
/// 让格子跟着照片比例走，再由可用高度反推该排几行：
/// - 6 张 3:4 竖图 → 2 行 × 3 张，每张约 216×288
/// - 6 张 3:2 横图 → 3 行 × 2 张，每张约 331×221
///
/// 不变量（单测覆盖）：行内总宽恰好等于 [width]（整体缩放后成比例收窄）、
/// 总高不超过 [height]、每行高度不低于 [minRowH]。
List<PlateRowPlan> planPlateRows(
  List<double> ratios,
  double width,
  double height, {
  double hGap = 18,
  double rowGap = 18,
  double minRowH = 96,
}) {
  if (ratios.isEmpty || width <= 0 || height <= 0) return const [];

  double rowHeight(List<int> group) {
    var sum = 0.0;
    for (final i in group) {
      sum += ratios[i];
    }
    if (sum <= 0) return 0;
    return (width - hGap * (group.length - 1)) / sum;
  }

  List<List<int>> splitEven(int rows) {
    final base = ratios.length ~/ rows;
    final rem = ratios.length % rows;
    if (base == 0) return const [];
    final out = <List<int>>[];
    var cursor = 0;
    for (var r = 0; r < rows; r++) {
      final k = base + (r < rem ? 1 : 0);
      out.add([for (var i = cursor; i < cursor + k; i++) i]);
      cursor += k;
    }
    return out;
  }

  // 「填满版面」和「不超出版面」在竖图/横图上会打架：
  // 6 张横图排 2 行只占一半高度，排 3 行会超出 5%。所以不追求严格不超，
  // 而是允许小幅溢出（整体等比缩小补回来），用「版面的利用率」打分。
  const double maxFill = 1.08; // 允许溢出 8%
  const double minFill = 0.6; // 低于 60% 说明这一版太空，宁可少排一行

  List<PlateRowPlan>? best;
  var bestScore = 0.0;
  var bestTotal = 0.0;

  for (var rows = 1; rows <= ratios.length; rows++) {
    final groups = splitEven(rows);
    if (groups.length != rows) continue;
    final plans = <PlateRowPlan>[];
    var total = rowGap * (rows - 1);
    var usable = true;
    for (final group in groups) {
      final rh = rowHeight(group);
      if (rh < minRowH) {
        usable = false;
        break;
      }
      plans.add(PlateRowPlan(group, rh));
      total += rh;
    }
    if (!usable) continue;

    final fill = total / height;
    if (fill > maxFill || fill < minFill) continue;
    // 越接近 1 越好；超过 1 不再加分（反正要缩回来）
    final score = fill < 1.0 ? fill : 1.0;
    if (score > bestScore) {
      bestScore = score;
      best = plans;
      bestTotal = total;
    }
  }

  if (best == null) {
    // 极端比例（超长全景、单张竖图等）兜底：一行一张，按可用高度均分
    final each = (height - rowGap * (ratios.length - 1)) / ratios.length;
    return [
      for (var i = 0; i < ratios.length; i++)
        PlateRowPlan([i], math.min(each, width / ratios[i])),
    ];
  }

  // 整体等比缩小：所有行缩同一系数，行与行仍然左右对齐，只是略微内收。
  // 缩小只作用于图片高度，行间距不动，所以要把间距先从总量里扣掉再算系数。
  final gaps = rowGap * (best.length - 1);
  final scale = bestTotal > height
      ? (height - gaps) / (bestTotal - gaps)
      : 1.0;
  return [
    for (final row in best) PlateRowPlan(row.indices, row.height * scale),
  ];
}

class _SinglePage extends StatelessWidget {
  const _SinglePage({required this.spec});

  final MagazineExportSpec spec;

  /// 一页最多 12 张 —— 用户要的是"整月都在这一页上"。
  ///
  /// 不裁切 + 按比例排版下，12 张 3:4 竖图自动排成 3 行 × 4 列，
  /// 每张约 156×209pt，正好铺满图版区。再多（整月 30 张那种）仍按时间
  /// 均匀取样到 12 张，页脚写明「精选 n / m 张」。
  static const int _maxTiles = 12;

  // 不对称页边距：左宽右窄、下留白多，是纸刊内页的常规做法。
  static const double _padL = 64;
  static const double _padR = 56;
  static const double _padT = 44;
  static const double _padB = 44;

  /// 摘要固定三行高。摘要长短不一时版面不跳，图版区高度才稳定。
  static const double _summaryH = 74;

  /// 图注行预留高度（含与图版的间隙）。
  static const double _captionSpace = 34;

  static const double _hGap = 18;
  static const double _rowGap = 18;

  /// 行高下限。低于这个值就不像照片、像色块了，宁可少排一行。
  static const double _minRowH = 96;

  @override
  Widget build(BuildContext context) {
    final picked = _pick(spec.photos);

    return Container(
      color: _paper,
      padding: const EdgeInsets.fromLTRB(_padL, _padT, _padR, _padB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _masthead(),
          const SizedBox(height: 18),
          Container(height: 1, color: _ink.withOpacity(0.14)),
          const SizedBox(height: 24),
          _issueLine(),
          const SizedBox(height: 22),
          SizedBox(width: 420, height: _summaryH, child: _summaryBlock()),
          const SizedBox(height: 30),
          Expanded(
            child: picked.isEmpty
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, box) {
                      // 图版高度 = 剩余空间 - 图注。由它反推"最多能排几行、每行多高"。
                      final rows = _planRows(
                        picked,
                        box.maxWidth,
                        box.maxHeight - _captionSpace,
                      );
                      // 顶部对齐：图片贴住摘要下方，多余空间全部沉到图版底部。
                      // 居中的话会在标题区与图片之间裂开一条空带，像排版没做完。
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < rows.length; i++) ...[
                              if (i > 0) const SizedBox(height: _rowGap),
                              _row(rows[i]),
                            ],
                            const SizedBox(height: 12),
                            // 图注宽度绑在图版上，时间戳才会顶齐图版的右边缘
                            SizedBox(
                              width: _plateWidth(rows.first),
                              child: _captionLine(picked.first),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _ink.withOpacity(0.14)),
          const SizedBox(height: 10),
          _footer(),
        ],
      ),
    );
  }

  /// 刊头：中文刊名 + 细线 + 英文刊名，右端是期号。
  Widget _masthead() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '拾光',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            letterSpacing: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 18, height: 1, color: _ink.withOpacity(0.35)),
        const SizedBox(width: 10),
        Text(
          'MONTHLY',
          style: TextStyle(
            color: _ink.withOpacity(0.45),
            fontSize: 8,
            letterSpacing: 3.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          'NO.${spec.month.toString().padLeft(2, '0')} — ${spec.year}',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _ink.withOpacity(0.45),
            fontSize: 9,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  /// 月号：`10 / OCTOBER / 12 EXPOSURES` 严格站在同一条字母基线上。
  Widget _issueLine() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          spec.month.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontFamily: 'serif',
            color: _ink,
            fontSize: 146,
            height: 0.82,
            fontWeight: FontWeight.w200,
            letterSpacing: -8,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            _monthWord(spec.month),
            style: TextStyle(
              color: _ink.withOpacity(0.62),
              fontSize: 10,
              letterSpacing: 6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            '${spec.photos.length} EXPOSURES',
            style: TextStyle(
              fontFamily: 'monospace',
              color: _ink.withOpacity(0.42),
              fontSize: 9,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  /// 摘要：前置一截短横线，像引文而不是说明文。
  Widget _summaryBlock() {
    final text = _summaryLine();
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 1,
          margin: const EdgeInsets.only(top: 10),
          color: _ink.withOpacity(0.38),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink.withOpacity(0.72),
              fontSize: 11.5,
              height: 1.9,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  /// 一行图的实际总宽，图注靠它对齐到图版右边缘。
  double _plateWidth(_PlateRow row) {
    var width = _hGap * (row.photos.length - 1);
    for (final photo in row.photos) {
      width += row.height * _ratio(photo);
    }
    return width;
  }

  /// 一行图：等高、宽度按各自比例，整行铺满版心。
  Widget _row(_PlateRow row) {    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < row.photos.length; i++) ...[
          if (i > 0) const SizedBox(width: _hGap),
          SizedBox(
            width: row.height * _ratio(row.photos[i]),
            height: row.height,
            child: _figure(row.photos[i]),
          ),
        ],
      ],
    );
  }

  Widget _captionLine(Photo photo) {
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              captionOf(photo, spec),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontFamily: 'serif',
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _stamp(photo),
            style: TextStyle(
              fontFamily: 'monospace',
              color: _ink.withOpacity(0.42),
              fontSize: 8,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Text(
          'SHIGUANG · MONTHLY',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _ink.withOpacity(0.38),
            fontSize: 8.5,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        Text(
          _footerCount(),
          style: TextStyle(
            fontFamily: 'monospace',
            color: _ink.withOpacity(0.38),
            fontSize: 8.5,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  /// 图。框的宽高比已经等于照片原始比例，所以 `cover` 退化为「不裁」。
  Widget _figure(Photo photo) {
    return LocalImage(
      path: photo.path,
      fit: BoxFit.cover,
      cacheWidth: _decodeWidthOf(photo),
      errorBuilder: (_, __, ___) => ColoredBox(
        color: _ink.withOpacity(0.06),
        child: Center(
          child: Icon(Icons.image_outlined, color: _ink.withOpacity(0.18), size: 22),
        ),
      ),
    );
  }

  int _decodeWidthOf(Photo photo) => singlePageTileDecodeWidth(
      spec.photos.length, photo.id == spec.photos.first.id);

  double _ratio(Photo photo) {
    final r = spec.ratioOf?.call(photo.path);
    if (r == null || !r.isFinite || r < 0.2 || r > 5.0) return 1.0;
    return r;
  }

  List<_PlateRow> _planRows(List<Photo> picked, double width, double height) {
    final plan = planPlateRows(
      [for (final p in picked) _ratio(p)],
      width,
      height,
      hGap: _hGap,
      rowGap: _rowGap,
      minRowH: _minRowH,
    );
    return [
      for (final row in plan)
        _PlateRow([for (final i in row.indices) picked[i]], row.height),
    ];
  }

  /// 超过上限时按时间均匀取样，保留第一张作为 hero。
  List<Photo> _pick(List<Photo> photos) {
    if (photos.length <= _maxTiles) return photos;
    final picked = <Photo>{photos.first};
    final rest = photos.sublist(1);
    for (var i = 0; i < _maxTiles - 1; i++) {
      final index = ((i + 0.5) * rest.length / (_maxTiles - 1)).floor();
      picked.add(rest[index.clamp(0, rest.length - 1)]);
    }
    return picked.toList();
  }

  String _summaryLine() => _firstSentences(spec.summary, 1);

  String _stamp(Photo photo) {
    final t = photo.dateTime;
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}'
        '  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _footerCount() {
    final shown = _pick(spec.photos).length;
    final total = spec.photos.length;
    final photos = shown < total ? '$shown / $total 张' : '$total 张';
    return '$photos · ${spec.dayCount} 天';
  }
}


String _monthAbbr(int month) {
  const names = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return names[(month - 1).clamp(0, 11)];
}

String _monthWord(int month) {
  const names = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
  return names[(month - 1).clamp(0, 11)];
}

// ── 截图与分享 ────────────────────────────────────────────────

/// 单页导出：一页 A4，分享一张图。
Future<void> captureSinglePageExport({
  required BuildContext context,
  required MagazineExportSpec spec,
  required GlobalKey pageKey,
  required ValueChanged<bool> onPreparing,
}) {
  return _runCapture(
    context: context,
    spec: spec,
    pageKeys: [pageKey],
    fileName: 'single_${spec.year}${spec.month.toString().padLeft(2, '0')}.png',
    shareText: '${spec.year}年${spec.month}月 · 拾光月刊',
    onPreparing: onPreparing,
    decodeWidths: _singlePageDecodeWidths(spec),
  );
}

/// 多页画册导出：封面 + 内容页 + 统计页。
Future<void> captureMagazineExport({
  required BuildContext context,
  required MagazineExportSpec spec,
  required List<GlobalKey> pageKeys,
  required ValueChanged<bool> onPreparing,
}) {
  return _runCapture(
    context: context,
    spec: spec,
    pageKeys: pageKeys,
    fileName: 'magazine_${spec.year}${spec.month.toString().padLeft(2, '0')}.png',
    shareText: '${spec.year}年${spec.month}月 · 拾光月刊（${pageKeys.length} 页）',
    onPreparing: onPreparing,
    decodeWidths: _multiPageDecodeWidths(spec),
  );
}

/// 三个真机上的坑：
/// 1. **图片必须先解码完**再截，否则截到空白块 —— 这里用与 LocalImage 完全相同的
///    `ResizeImage(allowUpscaling: false)` 作为 key 预载，键不一致就命中不了缓存。
/// 2. 3 倍像素比会放大解码需求，所以解码宽度按「页内实际显示宽度」给，
///    不要给原图宽度（12 张 4000px 图能瞬间吃掉几百 MB）。
/// 3. 页面挂在 `-9999` 位置上渲染，虽然被 Stack 裁剪，但**仍然会 paint**，
///    RepaintBoundary 才有 layer 可截；换成 Offstage 就会截出空白。
Future<void> _runCapture({
  required BuildContext context,
  required MagazineExportSpec spec,
  required List<GlobalKey> pageKeys,
  required String fileName,
  required String shareText,
  required ValueChanged<bool> onPreparing,
  required Map<String, int> decodeWidths,
}) async {
  if (spec.photos.isEmpty || pageKeys.isEmpty) return;
  HapticFeedback.lightImpact();
  onPreparing(true);
  try {
    await _precache(context, spec, decodeWidths);
    await WidgetsBinding.instance.endOfFrame;
    // 首帧只保证「已提交布局」，文件解码完成落在后续帧，给一拍缓冲。
    await Future<void>.delayed(const Duration(milliseconds: 260));

    final tempDir = await getTemporaryDirectory();
    final files = <XFile>[];
    for (var i = 0; i < pageKeys.length; i++) {
      final boundary = pageKeys[i].currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) continue;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) continue;
      final suffix = pageKeys.length > 1 ? '_p${(i + 1).toString().padLeft(2, '0')}' : '';
      final file = File('${tempDir.path}${Platform.pathSeparator}${fileName.replaceFirst('.png', '$suffix.png')}');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      files.add(XFile(file.path));
    }
    if (files.isEmpty) throw StateError('没有截到任何一页');

    final result = await Share.shareXFiles(files, text: shareText);
    if (result.status != ShareResultStatus.dismissed) {
      AnalyticsService.instance.log(
        AnalyticsEvent.magazineExported,
        props: {
          'type': pageKeys.length > 1 ? 'a4_multi' : 'a4_single',
          'status': result.status.name,
          'photos': spec.photos.length,
          'pages': files.length,
        },
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  } finally {
    if (context.mounted) onPreparing(false);
  }
}

/// 单页版解码宽度：按"页上有多少张"分档。
///
/// 张数越多每张越小，解码宽给大了纯浪费内存 —— 12 张 × 1400 宽要 120MB+，
/// 800 宽只要 40MB，而实际显示宽度 3 倍像素比下也就 470–1000px。
int singlePageTileDecodeWidth(int total, bool isFirst) {
  if (total <= 4) return isFirst ? _coverDecodeWidth : _contentDecodeWidth;
  if (total <= 6) return 1000;
  return 800;
}

Map<String, int> _singlePageDecodeWidths(MagazineExportSpec spec) {
  final widths = <String, int>{};
  final total = spec.photos.length;
  for (var i = 0; i < total; i++) {
    widths[spec.photos[i].id] = singlePageTileDecodeWidth(total, i == 0);
  }
  return widths;
}

/// 多页版：封面与每页首图用宽解码，其余用内容宽度。
Map<String, int> _multiPageDecodeWidths(MagazineExportSpec spec) {
  final widths = <String, int>{};
  for (var i = 0; i < spec.photos.length; i++) {
    widths[spec.photos[i].id] = i % 3 == 0 ? _coverDecodeWidth : _contentDecodeWidth;
  }
  return widths;
}

/// 预热图片缓存。键必须与 LocalImage 内部构造的一致，否则白等。
Future<void> _precache(
  BuildContext context,
  MagazineExportSpec spec,
  Map<String, int> decodeWidths,
) async {
  for (final entry in decodeWidths.entries) {
    final photo = spec.photos.firstWhere((p) => p.id == entry.key);
    if (!photo.isLocalFile) continue;
    final file = File(photo.path);
    if (!file.existsSync()) continue;
    try {
      await precacheImage(
        ResizeImage(FileImage(file), width: entry.value, allowUpscaling: false),
        context,
      );
    } catch (_) {
      // 单张图挂了不影响其余页，留给 errorBuilder 显示占位
    }
  }
}
