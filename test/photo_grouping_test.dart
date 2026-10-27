import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/photo.dart';
import 'package:shiguang/utils/photo_grouping.dart';

Photo _photo(String id, DateTime date) {
  return Photo(
    id: id,
    path: 'assets/$id.jpg',
    thumbnailPath: 'assets/$id.jpg',
    date: date,
    fileSize: 1024,
  );
}

void main() {
  group('groupPhotosByMonth', () {
    test('跨 3 个月分组、组内顺序保持、按 key 降序、标签格式正确', () {
      // 输入顺序刻意打乱月份，用于验证组内顺序保持传入顺序
      final photos = <Photo>[
        _photo('p1', DateTime(2024, 10, 5)),
        _photo('p2', DateTime(2024, 11, 3)),
        _photo('p3', DateTime(2024, 10, 20)),
        _photo('p4', DateTime(2024, 12, 1)),
        _photo('p5', DateTime(2024, 11, 28)),
      ];

      final groups = groupPhotosByMonth(photos);

      // 共 3 个月份分组
      expect(groups.length, 3);

      // 按 key（'yyyy-M'）降序：2024-12 > 2024-11 > 2024-10
      expect(groups.map((g) => g.key).toList(), [
        '2024-12',
        '2024-11',
        '2024-10',
      ]);

      // 标签格式为 YYYY年M月
      expect(groups.map((g) => g.label).toList(), [
        '2024年12月',
        '2024年11月',
        '2024年10月',
      ]);

      // 组内顺序与传入顺序一致
      expect(groups[0].photos.map((p) => p.id).toList(), ['p4']);
      expect(groups[1].photos.map((p) => p.id).toList(), ['p2', 'p5']);
      expect(groups[2].photos.map((p) => p.id).toList(), ['p1', 'p3']);
    });

    test('空输入返回空分组列表', () {
      expect(groupPhotosByMonth(const <Photo>[]), isEmpty);
    });
  });
}
