import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/photo.dart';
import 'package:shiguang/services/monthly_recap_service.dart';

Photo _photo(
  int day, {
  String id = '',
  String? category,
  bool hasFace = false,
  bool isFavorite = false,
  String? location,
}) {
  return Photo(
    id: id.isEmpty ? 'p_$day' : id,
    path: '/tmp/p$day.jpg',
    thumbnailPath: '/tmp/t$day.jpg',
    date: DateTime(2026, 8, day, 12),
    location: location,
    category: category,
    fileSize: 1024,
    hasFace: hasFace,
    isFavorite: isFavorite,
  );
}

void main() {
  const service = MonthlyRecapService();

  /// 构造 10 张 8 月照片：8 张场景词「海边」，2 张无场景词。
  List<Photo> beachMonth() => [
        for (var i = 1; i <= 10; i++) _photo(i, id: 'b$i', hasFace: i <= 4),
      ];

  String? Function(String) beachScenes(List<Photo> photos) {
    final sceneIds = photos.take(8).map((p) => p.id).toSet();
    return (id) => sceneIds.contains(id) ? '海边' : null;
  }

  group('月度摘要 · 事实聚合', () {
    test('没有照片时返回 null，界面不显示入口', () {
      final facts = service.collectFacts([], year: 2026, month: 8);
      expect(facts.isEmpty, isTrue);
      expect(service.build(facts), isNull);
    });

    test('同一天的照片只算 1 天，且开场句换一种说法', () {
      final photos = [_photo(3, id: 'a'), _photo(3, id: 'b')];
      final facts = service.collectFacts(photos, year: 2026, month: 8);
      expect(facts.activeDays, 1);
      final recap = service.build(facts)!;
      expect(recap.sentences.first, contains('同一天'));
    });

    test('最热闹的一天取张数最多且日期更早的那天', () {
      final photos = [
        _photo(9, id: 'x1'),
        _photo(9, id: 'x2'),
        _photo(20, id: 'y1'),
        _photo(20, id: 'y2'),
      ];
      final facts = service.collectFacts(photos, year: 2026, month: 8);
      expect(facts.busiestDay, 9);
      expect(facts.busiestDayCount, 2);
    });
  });

  group('月度摘要 · 句子受事实约束', () {
    test('场景覆盖率高时写出场景词', () {
      final photos = beachMonth();
      final facts = service.collectFacts(
        photos,
        year: 2026,
        month: 8,
        sceneOf: beachScenes(photos),
      );
      expect(facts.sceneCoverage, 0.8);
      final recap = service.build(facts)!;
      expect(recap.text, contains('海边'));
    });

    test('场景覆盖率过低时不写场景句，避免以偏概全', () {
      final photos = [for (var i = 1; i <= 10; i++) _photo(i, id: 'c$i')];
      final facts = service.collectFacts(
        photos,
        year: 2026,
        month: 8,
        // 只有 1/10 张识别出场景，覆盖率 0.1 < 0.30
        sceneOf: (id) => id == 'c1' ? '海边' : null,
      );
      expect(facts.sceneCoverage, lessThan(MonthlyRecapService.sceneCoverageFloor));
      final recap = service.build(facts)!;
      expect(recap.text, isNot(contains('海边')));
    });

    test('没有场景没有地名时退回「有人出镜」', () {
      final photos = beachMonth();
      final facts = service.collectFacts(photos, year: 2026, month: 8);
      final recap = service.build(facts)!;
      expect(recap.text, contains('4 张有人出镜'));
    });

    test('未填步数时收束句不得出现步数', () {
      final photos = beachMonth();
      final facts = service.collectFacts(photos, year: 2026, month: 8);
      for (var month = 1; month <= 12; month++) {
        final f = service.collectFacts(photos, year: 2026, month: month);
        final recap = service.build(f, steps: 0)!;
        expect(recap.text, isNot(contains('步')));
      }
      expect(facts.photoCount, 10);
    });

    test('填了步数/心情后才会引用这些元数据', () {
      final photos = beachMonth();
      // 遍历 12 个月各取一次收束句模板，确保只要模板用到就能命中
      final texts = [
        for (var m = 1; m <= 12; m++)
          service
              .build(
                service.collectFacts(photos, year: 2026, month: m),
                mood: '平静',
                steps: 123456,
              )!
              .text,
      ];
      expect(texts.any((t) => t.contains('123456')), isTrue);
      expect(texts.any((t) => t.contains('平静')), isTrue);
    });

    test('句数不超过 3 句', () {
      final photos = beachMonth();
      final facts = service.collectFacts(
        photos,
        year: 2026,
        month: 8,
        sceneOf: beachScenes(photos),
        placeOf: (loc) => loc,
      );
      final recap = service.build(facts)!;
      expect(recap.sentences.length, lessThanOrEqualTo(MonthlyRecapService.maxSentences));
    });
  });

  group('月度摘要 · 关键词', () {
    test('关键词全部来自真实数据，不补「生活/记忆/时光」', () {
      final photos = beachMonth();
      final facts = service.collectFacts(
        photos,
        year: 2026,
        month: 8,
        sceneOf: beachScenes(photos),
      );
      final keywords = service.keywordsFor(facts);
      expect(keywords, contains('海边'));
      expect(keywords, isNot(contains('生活')));
      expect(keywords, isNot(contains('时光')));
      expect(keywords.length, lessThanOrEqualTo(6));
    });
  });

  group('月度摘要 · 稳定性', () {
    test('同一份数据重复生成结果完全一致', () {
      final photos = beachMonth();
      final facts = service.collectFacts(
        photos,
        year: 2026,
        month: 8,
        sceneOf: beachScenes(photos),
      );
      final a = service.build(facts)!;
      final b = service.build(facts)!;
      expect(a.title, b.title);
      expect(a.text, b.text);
      expect(a.keywords, b.keywords);
    });

    test('标题不出现未插值的模板残留', () {
      final photos = beachMonth();
      final facts = service.collectFacts(photos, year: 2026, month: 8);
      final recap = service.build(facts)!;
      expect(recap.title, isNot(contains(r'$')));
      expect(recap.title, isNotEmpty);
    });
  });
}
