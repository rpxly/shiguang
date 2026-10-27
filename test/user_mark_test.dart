import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/photo.dart';
import 'package:shiguang/utils/photo_grouping.dart';

Photo _photo(String id, DateTime date, {String userMark = ''}) {
  return Photo(
    id: id,
    path: 'assets/$id.jpg',
    thumbnailPath: 'assets/$id.jpg',
    date: date,
    fileSize: 1024,
    userMark: userMark,
  );
}

void main() {
  group('userMark 语义', () {
    test('未整理过滤：仅 userMark 为空的照片进入未整理列表', () {
      final photos = <Photo>[
        _photo('p1', DateTime(2024, 10, 5)),
        _photo('p2', DateTime(2024, 10, 6), userMark: 'keep'),
        _photo('p3', DateTime(2024, 11, 1)),
      ];

      // 与 organize_page 的未整理过滤口径一致
      final unorganized = photos.where((p) => p.userMark.isEmpty).toList();

      expect(unorganized.map((p) => p.id).toList(), ['p1', 'p3']);
    });

    test('已整理统计：userMark 非空计入已整理，其余计入未整理', () {
      final photos = <Photo>[
        _photo('p1', DateTime(2024, 10, 5)),
        _photo('p2', DateTime(2024, 10, 6), userMark: 'keep'),
        _photo('p3', DateTime(2024, 11, 1), userMark: 'keep'),
        _photo('p4', DateTime(2024, 12, 1)),
      ];

      // 与 home_page 的统计口径一致
      final organized = photos.where((p) => p.userMark.isNotEmpty).length;

      expect(organized, 2);
      expect(photos.length - organized, 2);
    });

    test('copyWith(userMark: keep) 后从未整理集合移除（滑动整理标记保留路径）', () {
      final p1 = _photo('p1', DateTime(2024, 10, 5));
      final p2 = _photo('p2', DateTime(2024, 10, 6));

      // slide_box_page 标记保留的方式
      final kept = p1.copyWith(userMark: 'keep');
      final photos = [kept, p2];

      expect(kept.userMark, 'keep');
      expect(photos.where((p) => p.userMark.isEmpty).map((p) => p.id).toList(), ['p2']);
      expect(photos.where((p) => p.userMark.isNotEmpty).map((p) => p.id).toList(), ['p1']);
    });

    test('未整理列表按月分组只包含未整理照片，组内顺序保持', () {
      final photos = <Photo>[
        _photo('p1', DateTime(2024, 10, 5)),
        _photo('p2', DateTime(2024, 10, 20), userMark: 'keep'),
        _photo('p3', DateTime(2024, 11, 3)),
        _photo('p4', DateTime(2024, 11, 28), userMark: 'keep'),
        _photo('p5', DateTime(2024, 10, 12)),
      ];

      final unorganized = photos.where((p) => p.userMark.isEmpty).toList();
      final groups = groupPhotosByMonth(unorganized);

      // 已整理的 p2/p4 不应出现在任何分组中
      expect(groups.map((g) => g.key).toList(), ['2024-11', '2024-10']);
      expect(groups[0].photos.map((p) => p.id).toList(), ['p3']);
      expect(groups[1].photos.map((p) => p.id).toList(), ['p1', 'p5']);
    });

    test('全部标记为 keep 时未整理集合与分组均为空（已整理完成态）', () {
      final photos = <Photo>[
        _photo('p1', DateTime(2024, 10, 5), userMark: 'keep'),
        _photo('p2', DateTime(2024, 11, 3), userMark: 'keep'),
      ];

      final unorganized = photos.where((p) => p.userMark.isEmpty).toList();

      expect(unorganized, isEmpty);
      expect(groupPhotosByMonth(unorganized), isEmpty);
    });
  });
}
