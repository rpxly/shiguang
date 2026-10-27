import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/quote.dart';
import 'package:shiguang/pages/monthly/quote_picker_sheet.dart';
import 'package:shiguang/services/quote_service.dart';

Quote _quote(
  String id,
  String text, {
  String? author,
  String? source,
  String category = '生活',
}) {
  return Quote(
    id: id,
    text: text,
    author: author,
    source: source,
    category: category,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('formatQuoteAsCaption', () {
    test('有作者时格式为「文案 — 作者」', () {
      final quote = _quote('q1', '你好世界', author: '木心');
      expect(formatQuoteAsCaption(quote), '你好世界 — 木心');
    });

    test('无作者但有出处时回退为「文案 — 出处」', () {
      final quote = _quote('q2', '你好世界', source: '《无声告白》');
      expect(formatQuoteAsCaption(quote), '你好世界 — 《无声告白》');
    });

    test('作者与出处均缺失时仅返回文案', () {
      final quote = _quote('q3', '你好世界');
      expect(formatQuoteAsCaption(quote), '你好世界');
    });

    test('作者为空字符串时视为缺失，仅返回文案', () {
      final quote = _quote('q4', '你好世界', author: '', source: '某出处');
      expect(formatQuoteAsCaption(quote), '你好世界');
    });
  });

  group('QuoteService 数据层', () {
    late QuoteService service;
    final addedIds = <String>[];

    setUp(() {
      service = QuoteService();
    });

    tearDown(() {
      // QuoteService 为单例，清理自建文案避免用例间污染
      for (final id in addedIds) {
        service.deleteQuote(id);
      }
      addedIds.clear();
    });

    Future<Quote> addCustom(String id, {String category = '生活'}) async {
      final quote = _quote(id, '测试文案$id', author: '测试者', category: category);
      await service.addQuote(quote);
      addedIds.add(id);
      return quote;
    }

    test('内置文案非空且 id 均为 builtin_ 前缀', () {
      final builtIn = service.builtInQuotes;
      expect(builtIn, isNotEmpty);
      expect(builtIn.every((q) => q.id.startsWith('builtin_')), isTrue);
    });

    test('自建文案合并进 allQuotes，排在内置文案之后', () async {
      final baseline = service.allQuotes.length;
      final custom = await addCustom('custom_test_merge');

      final all = service.allQuotes;
      expect(all.length, baseline + 1);
      expect(all[baseline].id, custom.id, reason: '自建文案应紧随内置文案之后');
      expect(all.sublist(0, baseline).every((q) => q.id.startsWith('builtin_')), isTrue);
    });

    test('删除自建文案后从 allQuotes 移除', () async {
      final custom = await addCustom('custom_test_delete');
      expect(service.allQuotes.any((q) => q.id == custom.id), isTrue);

      service.deleteQuote(custom.id);
      expect(service.allQuotes.any((q) => q.id == custom.id), isFalse);
    });

    test('内置文案不可通过 deleteQuote 删除', () {
      final before = service.allQuotes.length;
      service.deleteQuote('builtin_001');
      expect(service.allQuotes.length, before);
      expect(service.allQuotes.any((q) => q.id == 'builtin_001'), isTrue);
    });

    test('分类筛选仅返回该分类的文案', () {
      final filtered = service.getQuotesByCategory('哲思');
      expect(filtered, isNotEmpty);
      expect(filtered.every((q) => q.category == '哲思'), isTrue);
      // 「全部」语义即不过滤，数量为全集
      expect(service.allQuotes.length, greaterThan(filtered.length));
    });

    test('自定义分类的自建文案可被筛选', () async {
      final custom = await addCustom('custom_test_category', category: '测试分类');

      final filtered = service.getQuotesByCategory('测试分类');
      expect(filtered.map((q) => q.id).toList(), contains(custom.id));
      expect(filtered.every((q) => q.category == '测试分类'), isTrue);
    });

    test('每日文案取自 allQuotes 全集', () {
      final daily = service.getDailyQuoteDetails();
      expect(service.allQuotes.any((q) => q.id == daily.id), isTrue);
    });
  });
}
