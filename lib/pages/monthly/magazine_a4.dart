import 'dart:io';
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/photo.dart';
import '../../services/analytics_service.dart';
import '../../services/image_helper.dart';
import '../../theme.dart';
import 'magazine_models.dart';

// ─── A4 导出 ──────────────────────────────────────────────────
Widget buildA4Layout(BuildContext context, int year, int month, List<Photo> photos) {
  const double a4AspectRatio = 1414; // A4 portrait 1:1.414
  const double containerWidth = 800;
  final double containerHeight = containerWidth * a4AspectRatio / 1000;

  return Container(
    width: containerWidth,
    height: containerHeight,
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题区
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$year', style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w200, color: AppColors.textPrimaryLight,
              letterSpacing: 8,
            )),
            const SizedBox(width: 12),
            Text('${month.toString().padLeft(2, '0')}', style: TextStyle(
              fontSize: 56, fontWeight: FontWeight.w100, color: AppColors.textTertiaryLight,
              letterSpacing: 4,
            )),
            const Spacer(),
            Text('VOL. $year${month.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiaryLight, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: AppColors.dividerLight),
        const SizedBox(height: 32),
        Expanded(child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildA4Grid(context, year, month, photos, constraints.maxWidth, constraints.maxHeight);
          },
        )),
      ],
    ),
  );
}

/// A4 杂志风大小错落网格
/// 布局规则：
/// - 1 张：单大图满铺
/// - 2 张：上下或左右 1:1
/// - 3-6 张：3 列网格，随机选 1-2 张跨 2 格
/// - 7-12 张：4 列网格，随机选 2-3 张跨 2 格
/// 跨格方式：colspan=2（横向跨 2 列）或 rowspan=2（纵向跨 2 行），用 Table 实现
/// 随机种子基于 year+month，同一月导出布局稳定（不每次导出都变）
Widget _buildA4Grid(BuildContext context, int year, int month, List<Photo> photos,
    double availableWidth, double availableHeight) {
  final count = photos.length;
  if (count == 0) return const SizedBox();

  // 基于年月的稳定随机种子
  final seed = year * 100 + month;
  final rng = Random(seed);

  // 根据数量决定列数和布局方案
  final cols = count <= 2 ? count : (count <= 6 ? 3 : 4);
  final gap = 12.0;
  // 行数：大图会占 2 格，所以实际行数可能少于 ceil(count/cols)
  // 这里用预设布局表，避免动态计算复杂度
  final layout = _pickA4Layout(count, cols, rng);
  final rows = layout.rows;

  final tileWidth = (availableWidth - gap * (cols - 1)) / cols;
  final tileHeight = (availableHeight - gap * (rows - 1)) / rows;

  return Table(
    columnWidths: {
      for (var c = 0; c < cols; c++) c: FixedColumnWidth(tileWidth),
    },
    defaultVerticalAlignment: TableCellVerticalAlignment.top,
    children: [
      for (var r = 0; r < rows; r++)
        TableRow(
          children: [
            for (var c = 0; c < cols; c++)
              _buildA4Cell(context, photos, layout, r, c, tileWidth, tileHeight, gap),
          ],
        ),
    ],
  );
}

/// A4 布局描述：哪些格子被大图占据（跨格）
A4Layout _pickA4Layout(int count, int cols, Random rng) {
  // 简化方案：定义每行每列的单元格，标注 colspan/rowspan
  // 单元格按行优先填充，大图占 2 格
  final cells = <A4Cell>[];
  final bigCount = count <= 2
      ? 0
      : count <= 6
          ? (count >= 4 ? 2 : 1)
          : (count >= 10 ? 3 : 2);

  // 生成 bigCount 个大图位置（不重叠）
  final bigIndices = <int>{};
  var attempts = 0;
  while (bigIndices.length < bigCount && attempts < 30) {
    final idx = rng.nextInt(count);
    // 简单避免相邻都跨列导致行溢出
    if (!bigIndices.contains(idx)) {
      bigIndices.add(idx);
    }
    attempts++;
  }

  // 按照片顺序生成单元格，大图 colspan=2
  for (var i = 0; i < count; i++) {
    final isBig = bigIndices.contains(i);
    cells.add(A4Cell(
      photoIdx: i,
      colspan: isBig ? 2 : 1,
      rowspan: 1,
    ));
  }

  // 计算行数：遍历 cells，按 colspan 累加列宽，超出则换行
  final rows = _computeA4Rows(cells, cols);
  return A4Layout(cells: cells, rows: rows, cols: cols);
}

int _computeA4Rows(List<A4Cell> cells, int cols) {
  var row = 0;
  var col = 0;
  for (final cell in cells) {
    if (col + cell.colspan > cols) {
      row++;
      col = 0;
    }
    col += cell.colspan;
    if (col >= cols) {
      row++;
      col = 0;
    }
  }
  if (col > 0) row++; // 最后一行未满
  return row.clamp(1, 6);
}

Widget _buildA4Cell(BuildContext context, List<Photo> photos, A4Layout layout, int row, int col,
    double tileWidth, double tileHeight, double gap) {
  // 按线性顺序填入，遇到 colspan=2 则占用相邻列，相邻列返回空 SizedBox
  // 计算该 (row, col) 在线性流中的位置
  final pos = row * layout.cols + col;
  // 遍历 cells 找到 pos 对应的 cell（考虑前面大图占位）
  var cursor = 0;
  A4Cell? cell;
  for (final c in layout.cells) {
    if (cursor == pos) {
      cell = c;
      break;
    }
    if (cursor > pos) {
      // 该位置被前一个大图占据
      return const SizedBox();
    }
    cursor += c.colspan;
  }
  if (cell == null) return const SizedBox();
  if (cell.photoIdx >= photos.length) return const SizedBox();

  final photo = photos[cell.photoIdx];
  final width = tileWidth * cell.colspan + gap * (cell.colspan - 1);

  return Padding(
    padding: EdgeInsets.only(
      right: col < layout.cols - 1 ? gap : 0,
      bottom: row < layout.rows - 1 ? gap : 0,
    ),
    child: Container(
      width: width,
      height: tileHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: context.scrim.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LocalImage(
            path: photo.path,
            fit: BoxFit.cover,
            cacheWidth: (width * 2.5).round(),
            cacheHeight: (tileHeight * 2.5).round(),
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(gradient: AppGradients.accentSoft),
              child: const Center(child: Icon(Icons.image_outlined, color: Colors.white38, size: 24)),
            ),
          ),
          // 大图右下角加日期戳（杂志风）
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${photo.dateTime.month.toString().padLeft(2, '0')}.${photo.dateTime.day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> captureA4({
  required BuildContext context,
  required GlobalKey a4Key,
  required int year,
  required int month,
  required List<Photo> photos,
  required ValueChanged<bool> onPreparing,
}) async {
  if (photos.isEmpty) return;
  HapticFeedback.lightImpact();
  onPreparing(true);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 100));
    final ctx = a4Key.currentContext;
    if (ctx == null) throw StateError('A4 画册未就绪');
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}a4_${year}_$month.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    final result = await Share.shareXFiles([XFile(file.path)], text: '${year}年${month}月 画册');
    // 取消分享不记导出（同 monthly_magazine_page 里的说明）。
    if (result.status != ShareResultStatus.dismissed) {
      AnalyticsService.instance.log(
        AnalyticsEvent.magazineExported,
        props: {'type': 'a4', 'status': result.status.name, 'photos': photos.length},
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  } finally {
    if (context.mounted) onPreparing(false);
  }
}
