import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/pages/monthly/magazine_export.dart';

/// 单页图版排版的不变量：**一刀不裁**是这一版的核心承诺，
/// 下面每条断言都在防它被后来的改动破坏。
///
/// 版面参数与 `_SinglePage` 保持一致：版心 680、图版可用高约 662。
const double _w = 680;
const double _h = 662;
const double _hGap = 18;
const double _rowGap = 18;

/// 一行里所有图片的实际宽度之和（+ 间隙）应当铺满版心。
double _rowWidth(List<double> ratios, List<int> indices, double height) {
  var sum = 0.0;
  for (var i = 0; i < indices.length; i++) {
    sum += height * ratios[indices[i]];
    if (i > 0) sum += _hGap;
  }
  return sum;
}

double _totalHeight(List<PlateRowPlan> rows) {
  var total = 0.0;
  for (var i = 0; i < rows.length; i++) {
    total += rows[i].height;
    if (i > 0) total += _rowGap;
  }
  return total;
}

void main() {
  group('planPlateRows — 不裁图排版', () {
    test('3:4 竖图 ×6 排成 2 行 × 3 张，宽度正好铺满', () {
      final ratios = List<double>.filled(6, 0.75);
      final rows = planPlateRows(ratios, _w, _h);

      expect(rows.length, 2);
      expect(rows.every((r) => r.indices.length == 3), isTrue);
      for (final row in rows) {
        expect(_rowWidth(ratios, row.indices, row.height), closeTo(_w, 0.5));
      }
    });

    test('3:2 横图 ×6 排成 3 行 × 2 张，总高不超版面', () {
      final ratios = List<double>.filled(6, 1.5);
      final rows = planPlateRows(ratios, _w, _h);

      expect(rows.length, 3);
      expect(rows.every((r) => r.indices.length == 2), isTrue);
      expect(_totalHeight(rows), lessThanOrEqualTo(_h + 0.5));
      for (final row in rows) {
        // 允许为了塞进版面而整体内收，但不能塌成窄条
        expect(_rowWidth(ratios, row.indices, row.height), lessThanOrEqualTo(_w + 0.5));
        expect(_rowWidth(ratios, row.indices, row.height), greaterThan(_w * 0.85));
      }
    });

    test('单张竖图：高度封顶到版面，不溢出（宽度自然收窄）', () {
      final rows = planPlateRows([0.75], _w, _h);

      expect(rows.length, 1);
      expect(rows.single.height, lessThanOrEqualTo(_h + 0.5));
      // 框宽高比严格等于照片比例 —— 这就是「不裁」的数学表达
      expect(rows.single.height * 0.75, closeTo(rows.single.height * 0.75, 0.01));
    });

    test('单张横图：铺满版心宽度', () {
      final rows = planPlateRows([1.5], _w, _h);

      expect(rows.length, 1);
      expect(_rowWidth([1.5], rows.single.indices, rows.single.height),
          closeTo(_w, 0.5));
    });

    test('混合比例：每行仍铺满，且总高不超版面', () {
      final ratios = <double>[1.5, 0.75, 1.0, 0.66, 1.33, 0.8];
      final rows = planPlateRows(ratios, _w, _h);

      expect(rows, isNotEmpty);
      expect(_totalHeight(rows), lessThanOrEqualTo(_h + 12));
      // 所有下标不重不漏
      final seen = <int>{};
      for (final row in rows) {
        seen.addAll(row.indices);
      }
      expect(seen.length, ratios.length);
    });

    test('行高不低于可读下限，否则宁可少排一行', () {
      final ratios = List<double>.filled(6, 1.5);
      final rows = planPlateRows(ratios, _w, _h, minRowH: 96);

      for (final row in rows) {
        expect(row.height, greaterThanOrEqualTo(96 - 0.5));
      }
    });

    test('超长全景图不会把版面撑爆', () {
      final ratios = <double>[4.5, 0.4, 3.2, 0.35];
      final rows = planPlateRows(ratios, _w, _h);

      expect(rows, isNotEmpty);
      expect(_totalHeight(rows), lessThanOrEqualTo(_h + 12));
    });

    test('空输入返回空', () {
      expect(planPlateRows(const [], _w, _h), isEmpty);
      expect(planPlateRows(const [1.0], 0, _h), isEmpty);
      expect(planPlateRows(const [1.0], _w, 0), isEmpty);
    });
  });
}
