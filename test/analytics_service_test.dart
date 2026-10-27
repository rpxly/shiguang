import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/services/analytics_service.dart';

/// 埋点服务的回归测试。
///
/// 重点不在「能不能写文件」，而在**漏斗口径**：
/// 分母是「有整理完成的天数」、同一天去重、样本不足时不给百分比结论。
/// 这三条错了，拿它替代方向清单里的示例数据就是拿假数据骗自己。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('analytics_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// 往 events.jsonl 里塞构造好的历史（模拟攒了几天的数据）。
  Future<void> seed(List<Map<String, Object?>> events) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}events.jsonl');
    final lines = events.map((e) => jsonEncode(e)).join('\n');
    await file.writeAsString(lines.isEmpty ? '' : '$lines\n');
  }

  Map<String, Object?> event(DateTime t, AnalyticsEvent e, [Map<String, Object?>? props]) => {
        't': t.toIso8601String(),
        'e': e.key,
        if (props != null) 'p': props,
      };

  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12).subtract(Duration(days: n));
  }

  group('写入与落盘', () {
    test('log 后计数正确，flush 后可重新读出', () async {
      final service = AnalyticsService(dirOverride: tempDir);
      service.log(AnalyticsEvent.organizeCompleted, props: {'moves': 12});
      service.log(AnalyticsEvent.magazineOpened);
      await service.flush();

      final reopened = AnalyticsService(dirOverride: tempDir);
      await reopened.ensureLoaded();
      final report = reopened.funnel();
      expect(report.countOf(AnalyticsEvent.organizeCompleted), 1);
      expect(report.countOf(AnalyticsEvent.magazineOpened), 1);
      expect(report.recent.first.event, AnalyticsEvent.magazineOpened.key);
      expect(report.recent.first.props, isEmpty);
    });

    test('reset 清空内存与磁盘', () async {
      final service = AnalyticsService(dirOverride: tempDir);
      service.log(AnalyticsEvent.magazineOpened);
      await service.flush();
      await service.reset();
      expect(service.funnel().countOf(AnalyticsEvent.magazineOpened), 0);

      final reopened = AnalyticsService(dirOverride: tempDir);
      await reopened.ensureLoaded();
      expect(reopened.funnel().countOf(AnalyticsEvent.magazineOpened), 0);
    });

    test('脏行被跳过，不影响同一文件里的好数据', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}events.jsonl');
      await file.writeAsString(
        'not json at all\n'
        '{"t":"坏时间","e":"magazine_opened"}\n'
        '${jsonEncode(event(daysAgo(0), AnalyticsEvent.magazineOpened))}\n',
      );
      final service = AnalyticsService(dirOverride: tempDir);
      await service.ensureLoaded();
      expect(service.funnel().countOf(AnalyticsEvent.magazineOpened), 1);
    });
  });

  group('漏斗口径', () {
    test('同一天进入月刊多次，只算一天进入', () async {
      final service = AnalyticsService(dirOverride: tempDir);
      for (var i = 0; i < 5; i++) {
        service.log(AnalyticsEvent.organizeCompleted);
        service.log(AnalyticsEvent.magazineOpened);
      }
      await service.flush();
      final report = service.funnel();
      expect(report.organizedDays, 1, reason: '一天只算一天');
      expect(report.openedDays, 1);
      expect(report.enterRate, 1.0);
      expect(report.countOf(AnalyticsEvent.magazineOpened), 5, reason: '全量计数仍记 5 次');
    });

    test('没有整理完成的日子不进分母', () async {
      // 第 1 天：整理 + 进入；第 2 天：只进入月刊（没整理）
      await seed([
        event(daysAgo(1), AnalyticsEvent.organizeCompleted),
        event(daysAgo(1), AnalyticsEvent.magazineOpened),
        event(daysAgo(2), AnalyticsEvent.magazineOpened),
      ]);
      final service = AnalyticsService(dirOverride: tempDir);
      await service.ensureLoaded();
      final report = service.funnel();
      expect(report.organizedDays, 1);
      expect(report.openedDays, 1);
      expect(report.enterRate, 1.0, reason: '第 2 天没整理，不能算进分子');
    });

    test('三段比率按各自的分子算', () async {
      // 5 天整理；其中 3 天进月刊、2 天产出、1 天导出
      await seed([
        event(daysAgo(1), AnalyticsEvent.organizeCompleted),
        event(daysAgo(1), AnalyticsEvent.magazineOpened),
        event(daysAgo(1), AnalyticsEvent.magazineGenerated),
        event(daysAgo(1), AnalyticsEvent.magazineExported),
        event(daysAgo(2), AnalyticsEvent.organizeCompleted),
        event(daysAgo(2), AnalyticsEvent.magazineOpened),
        event(daysAgo(2), AnalyticsEvent.magazineGenerated),
        event(daysAgo(3), AnalyticsEvent.organizeCompleted),
        event(daysAgo(3), AnalyticsEvent.magazineOpened),
        event(daysAgo(4), AnalyticsEvent.organizeCompleted),
        event(daysAgo(5), AnalyticsEvent.organizeCompleted),
      ]);
      final service = AnalyticsService(dirOverride: tempDir);
      await service.ensureLoaded();
      final report = service.funnel();
      expect(report.organizedDays, 5);
      expect(report.enterRate, closeTo(0.6, 1e-9));
      expect(report.generateRate, closeTo(0.4, 1e-9));
      expect(report.exportRate, closeTo(0.2, 1e-9));
      expect(report.rateText(report.generateRate), '40%');
    });

    test('窗口外的老数据不进漏斗，但仍在全量计数里', () async {
      await seed([
        event(daysAgo(40), AnalyticsEvent.organizeCompleted),
        event(daysAgo(40), AnalyticsEvent.magazineOpened),
      ]);
      final service = AnalyticsService(dirOverride: tempDir);
      await service.ensureLoaded();
      final report = service.funnel(days: 7);
      expect(report.organizedDays, 0, reason: '40 天前不在 7 天窗口内');
      expect(report.enterRate, isNull);
      expect(report.rateText(null), '—');
      expect(report.countOf(AnalyticsEvent.organizeCompleted), 1);
    });

    test('样本 <5 天时不给出可读结论', () async {
      await seed([
        event(daysAgo(1), AnalyticsEvent.organizeCompleted),
        event(daysAgo(1), AnalyticsEvent.magazineOpened),
      ]);
      final service = AnalyticsService(dirOverride: tempDir);
      await service.ensureLoaded();
      expect(service.funnel().isSampleEnough, isFalse);

      await seed([
        for (var i = 1; i <= 5; i++) ...[
          event(daysAgo(i), AnalyticsEvent.organizeCompleted),
          event(daysAgo(i), AnalyticsEvent.magazineOpened),
        ],
      ]);
      final enough = AnalyticsService(dirOverride: tempDir);
      await enough.ensureLoaded();
      expect(enough.funnel().isSampleEnough, isTrue);
    });

    test('没有任何数据时比率为 null 而不是 0%', () async {
      final service = AnalyticsService(dirOverride: tempDir);
      await service.ensureLoaded();
      final report = service.funnel();
      expect(report.organizedDays, 0);
      expect(report.enterRate, isNull);
      expect(report.generateRate, isNull);
      expect(report.exportRate, isNull);
    });
  });

  group('事件名', () {
    test('key 保持稳定（改了就断了历史数据）', () {
      expect(AnalyticsEvent.organizeCompleted.key, 'organize_completed');
      expect(AnalyticsEvent.magazineOpened.key, 'magazine_opened');
      expect(AnalyticsEvent.magazineGenerated.key, 'magazine_generated');
      expect(AnalyticsEvent.magazineExported.key, 'magazine_exported');
    });
  });
}
