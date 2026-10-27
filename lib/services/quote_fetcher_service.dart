import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/quote.dart';
import 'quote_service.dart';

/// 文案抓取服务：始终从 hitokoto 在线 API 抓取若干条文案
class QuoteFetcherService {
  final Set<String> _seen = {};

  Future<int> fetchAndSave(QuoteService service) async {
    int count = 0;

    // hitokoto 在线文案（并发 5 条）
    try {
      final results = await Future.wait([
        _fetchFromHitokoto(),
        _fetchFromHitokoto(),
        _fetchFromHitokoto(),
        _fetchFromHitokoto(),
        _fetchFromHitokoto(),
      ], eagerError: false);

      for (final quotes in results) {
        for (final q in quotes) {
          if (_seen.contains(q.text)) continue;
          _seen.add(q.text);
          await service.addQuote(q);
          count++;
        }
      }
    } catch (e) {
      debugPrint('[QuoteFetcher] 在线获取失败: $e');
    }

    return count;
  }

  Future<List<Quote>> _fetchFromHitokoto() async {
    try {
      final response = await http.get(
        Uri.parse('https://v1.hitokoto.cn/?c=a&c=b&c=d&c=f&c=h&c=i&c=j&encode=json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['hitokoto'] as String?;
      if (text == null || text.isEmpty) return [];

      final from = data['from'] as String?;
      final fromWho = data['from_who'] as String?;
      final typeMap = <String, String>{
        'a': '哲思', 'b': '爱情', 'c': '生活',
        'd': '旅行', 'f': '爱情', 'h': '自然',
        'i': '生活', 'j': '哲思',
      };
      final cat = typeMap[data['type']] ?? '哲思';

      final quote = Quote(
        id: 'online_hitokoto_${text.hashCode}',
        text: text,
        author: fromWho,
        source: from,
        category: cat == '网易云' || cat == '小红书' ? '生活' : cat,
        createdAt: DateTime.now(),
      );
      return [quote];
    } catch (_) {
      return [];
    }
  }
}
