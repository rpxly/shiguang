import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/photo.dart';
import 'package:shiguang/pages/monthly/magazine_models.dart';
import 'package:shiguang/services/magazine_draft_service.dart';

/// 一键成刊的选片与文案规则。
///
/// 这套逻辑替代了「用户自己一张张导入」的门槛，所以它的每个判断都要能被
/// 解释：为什么是这几张、为什么图注这么写。测试按「能解释」来写，
/// 不是按「跑通」来写。
void main() {
  const service = MagazineDraftService();

  Photo photo(
    String id,
    DateTime date, {
    int score = 50,
    bool favorite = false,
    bool face = false,
    String? location,
  }) =>
      Photo(
        id: id,
        path: '/tmp/$id.jpg',
        thumbnailPath: '/tmp/${id}_t.jpg',
        date: date,
        location: location,
        fileSize: 1024,
        qualityScore: score,
        isFavorite: favorite,
        hasFace: face,
      );

  DateTime at(int day, [int hour = 12]) => DateTime(2026, 10, day, hour);

  group('筛选与上限', () {
    test('本月没有照片时返回 null', () {
      final draft = service.build(monthPhotos: const [], year: 2026, month: 10);
      expect(draft, isNull);
    });

    test('只收本月照片，跨月的一律排除', () {
      final draft = service.build(
        monthPhotos: [
          photo('sep', DateTime(2026, 9, 30, 12)),
          photo('a', at(3)),
          photo('nov', DateTime(2026, 11, 1, 12)),
        ],
        year: 2026,
        month: 10,
      );
      expect(draft!.photos.map((p) => p.id), ['a']);
      expect(draft.candidateCount, 1);
    });

    test('页数不超过上限，且首尾都保留', () {
      final photos = [
        for (var day = 1; day <= 4; day++)
          for (var i = 0; i < 9; i++) photo('d$day-$i', at(day, 8 + i)),
      ];
      final draft = service.build(monthPhotos: photos, year: 2026, month: 10, maxPages: 9);
      expect(draft!.pages.length, 9);
      expect(draft.photos.length, 9);
      // 首尾是整月最早和最晚那张
      expect(draft.photos.first.dateTime.day, 1);
      expect(draft.photos.last.dateTime.day, 4);
    });

    test('照片比上限少时全部用上', () {
      final draft = service.build(
        monthPhotos: [photo('a', at(1)), photo('b', at(2)), photo('c', at(3))],
        year: 2026,
        month: 10,
      );
      expect(draft!.pages.length, 3);
      expect(draft.dayCount, 3);
    });
  });

  group('选片权重', () {
    test('同一天里收藏与高质量优先', () {
      final draft = service.build(
        monthPhotos: [
          photo('low', at(5, 9), score: 20),
          photo('high', at(5, 10), score: 90),
          // 质量分略低，但收藏 +30 后反超（70 + 30 > 90）
          photo('fav', at(5, 11), score: 70, favorite: true),
        ],
        year: 2026,
        month: 10,
        maxPages: 1,
      );
      expect(draft!.photos.single.id, 'fav', reason: '收藏加分应能反超质量分');
    });

    test('同一天照片很多时，也会给其他天留位置', () {
      // 第 1 天塞 20 张高分，第 2、3 天各 1 张低分
      final photos = [
        for (var i = 0; i < 20; i++) photo('d1-$i', at(1, 6 + (i % 16)), score: 95),
        photo('d2', at(2), score: 5),
        photo('d3', at(3), score: 5),
      ];
      final draft = service.build(monthPhotos: photos, year: 2026, month: 10, maxPages: 9);
      final days = draft!.photos.map((p) => p.dateTime.day).toSet();
      expect(days, containsAll([1, 2, 3]), reason: '天数覆盖优先于单纯刷高分');
    });

    test('结果按拍摄时间升序，页面与照片一一对应', () {
      final draft = service.build(
        monthPhotos: [photo('c', at(3)), photo('a', at(1)), photo('b', at(2))],
        year: 2026,
        month: 10,
      );
      expect(draft!.photos.map((p) => p.id), ['a', 'b', 'c']);
      for (var i = 0; i < draft.pages.length; i++) {
        expect(draft.pages[i].photoIds.single, draft.photos[i].id);
      }
    });

    test('同样的输入生成的草稿完全一致', () {
      final photos = [
        for (var day = 1; day <= 3; day++)
          for (var i = 0; i < 5; i++) photo('d$day-$i', at(day, 9 + i), score: 40 + i),
      ];
      final a = service.build(monthPhotos: photos, year: 2026, month: 10);
      final b = service.build(monthPhotos: photos, year: 2026, month: 10);
      expect(a!.photos.map((p) => p.id).toList(), b!.photos.map((p) => p.id).toList());
      expect(a.pages.map((p) => p.caption).toList(), b.pages.map((p) => p.caption).toList());
    });
  });

  group('模板节奏', () {
    test('开篇全幅、收尾胶片', () {
      final photos = [for (var i = 0; i < 5; i++) photo('p$i', at(i + 1))];
      final draft = service.build(monthPhotos: photos, year: 2026, month: 10);
      expect(draft!.pages.first.template, MagTemplate.fullBleed);
      expect(draft.pages.last.template, MagTemplate.filmGrain);
    });

    test('只有一页时用全幅', () {
      final draft = service.build(
        monthPhotos: [photo('only', at(1))],
        year: 2026,
        month: 10,
      );
      expect(draft!.pages.single.template, MagTemplate.fullBleed);
    });
  });

  group('图注只写事实', () {
    test('有场景词时带时段', () {
      final draft = service.build(
        monthPhotos: [photo('a', at(2, 20))],
        year: 2026,
        month: 10,
        sceneOf: (id) => '餐桌',
      );
      expect(draft!.pages.single.caption, '傍晚的餐桌');
    });

    test('时段按拍摄小时分段', () {
      final cases = {
        6: '清晨的风景',
        9: '上午的风景',
        12: '午后的风景',
        15: '下午的风景',
        19: '傍晚的风景',
        23: '夜里的风景',
      };
      cases.forEach((hour, expected) {
        final draft = service.build(
          monthPhotos: [photo('h$hour', at(2, hour))],
          year: 2026,
          month: 10,
          sceneOf: (_) => '风景',
        );
        expect(draft!.pages.single.caption, expected, reason: '$hour 点');
      });
    });

    test('没有场景词时退到地名', () {
      final draft = service.build(
        monthPhotos: [photo('a', at(2), location: '31.2304, 121.4737')],
        year: 2026,
        month: 10,
        sceneOf: (_) => null,
        // 坐标不是地名，由 readablePlace 负责过滤
        placeOf: (loc) => loc == null || loc.contains(',') ? null : loc,
      );
      expect(draft!.pages.single.caption, '10月2日', reason: '坐标不该当图注');
    });

    test('场景词与地名都没有时用日期，不写空话', () {
      final draft = service.build(
        monthPhotos: [photo('a', at(7))],
        year: 2026,
        month: 10,
        sceneOf: (_) => null,
        placeOf: (_) => null,
      );
      expect(draft!.pages.single.caption, '10月7日');
    });

    test('图注永远不为空', () {
      final draft = service.build(
        monthPhotos: [
          for (var i = 0; i < 6; i++) photo('p$i', at(i + 1)),
        ],
        year: 2026,
        month: 10,
        sceneOf: (_) => ' ',
        placeOf: (_) => '',
      );
      for (final page in draft!.pages) {
        expect(page.caption.trim(), isNotEmpty);
      }
    });
  });
}
