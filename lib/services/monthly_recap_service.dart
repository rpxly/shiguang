import '../models/photo.dart';

/// 一条月度摘要由哪些**事实**聚合而来。
///
/// 这份数据只做统计，不做推断：场景词来自 ML Kit 落盘结果，
/// 地名来自用户已有的可读 location，心情/天气/步数是用户自己填的。
/// 任何一个字段缺失时，依赖它的句子就整句不出现——宁可不写，也不编一个。
class MonthlyFacts {
  final int year;
  final int month;

  /// 本月照片总数。
  final int photoCount;

  /// 有照片的不同日期数。
  final int activeDays;

  /// 有人脸的照片数。
  final int faceCount;

  /// 收藏数。
  final int favoriteCount;

  /// 夜间（19:00 之后或 06:00 之前）拍摄的张数。
  ///
  /// 场景词、地名、人脸全都缺失时（真机实测很常见：翻拍屏幕、桌面杂物这类
  /// 照片命中不了任何场景规则），用拍摄时段兜住内容句，避免摘要退化成
  /// 两句空话。
  final int nightCount;

  /// 场景词 → 张数（只统计识别出场景词的照片）。
  final Map<String, int> sceneCounts;

  /// 有场景词的照片数，用来判断场景句是否以偏概全。
  final int sceneKnownCount;

  /// 可读地名 → 张数。
  final Map<String, int> placeCounts;

  /// 有可读地名的照片数。
  final int placeKnownCount;

  /// 分类 → 张数（兼容旧数据的 category 字段）。
  final Map<String, int> categoryCounts;

  /// 单日最多拍摄日（几号）与当天张数；无数据时为 null / 0。
  final int? busiestDay;
  final int busiestDayCount;

  const MonthlyFacts({
    required this.year,
    required this.month,
    required this.photoCount,
    required this.activeDays,
    required this.faceCount,
    required this.favoriteCount,
    required this.nightCount,
    required this.sceneCounts,
    required this.sceneKnownCount,
    required this.placeCounts,
    required this.placeKnownCount,
    required this.categoryCounts,
    required this.busiestDay,
    required this.busiestDayCount,
  });

  bool get isEmpty => photoCount == 0;

  /// 按张数降序；同票按名称排序，保证输出稳定可复现。
  List<String> get topScenes => _ranked(sceneCounts);

  List<String> get topPlaces => _ranked(placeCounts);

  List<String> get topCategories => _ranked(categoryCounts);

  /// 场景覆盖率：低于阈值时不该拿它写句子（例如 200 张里只有 5 张识别出场景）。
  double get sceneCoverage =>
      photoCount == 0 ? 0 : sceneKnownCount / photoCount;

  double get placeCoverage =>
      photoCount == 0 ? 0 : placeKnownCount / photoCount;

  int get topSceneCount => topScenes.isEmpty ? 0 : sceneCounts[topScenes.first]!;

  List<String> _ranked(Map<String, int> counts) {
    final entries = counts.entries.where((e) => e.key.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries.map((e) => e.key).toList(growable: false);
  }
}

/// 生成好的一段月度摘要。
///
/// [sentences] 是 3 句以内的短句，直接填进「本月总结」输入框；
/// [title] 可当作月刊标题；[keywords] 取代原来写死的「生活/记忆/时光」。
class MonthlyRecap {
  final String title;
  final List<String> sentences;
  final List<String> keywords;

  MonthlyRecap({
    required this.title,
    required this.sentences,
    required this.keywords,
  });

  /// 拼成一段可直接落库的文本。
  String get text => sentences.join();

  bool get isEmpty => sentences.isEmpty;
}

/// 规则版月度摘要。
///
/// 定位：**可上线的兜底**，以及端侧大模型的对照基线。
/// 它不做「创作」，只把用户照片里已经存在的事实排成读得下去的三句话。
/// 端侧 AI 叙事若跑通，两者共用同一份 [MonthlyFacts] 与同一处 UI 落点，
/// 便于直接对比「规则 vs 模型」哪一版用户更愿意导出。
class MonthlyRecapService {
  const MonthlyRecapService();

  /// 场景覆盖率低于此值时，不写场景句。
  static const double sceneCoverageFloor = 0.30;

  /// 地名覆盖率低于此值时，不写地名句。
  static const double placeCoverageFloor = 0.15;

  /// 摘要句数上限。
  static const int maxSentences = 3;

  /// 从照片聚合事实。
  ///
  /// [sceneOf] 由调用方注入（通常传 `SceneClassifier.instance.labelFor`），
  /// 这样本服务不依赖单例，方便单测。
  MonthlyFacts collectFacts(
    List<Photo> photos, {
    required int year,
    required int month,
    String? Function(String photoId)? sceneOf,
    String? Function(String? location)? placeOf,
  }) {
    final sceneCounts = <String, int>{};
    final placeCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    final perDay = <int, int>{};
    var sceneKnown = 0;
    var placeKnown = 0;
    var faceCount = 0;
    var favoriteCount = 0;
    var nightCount = 0;

    for (final photo in photos) {
      final date = photo.dateTime;
      perDay[date.day] = (perDay[date.day] ?? 0) + 1;

      final scene = sceneOf?.call(photo.id)?.trim() ?? '';
      if (scene.isNotEmpty) {
        sceneKnown++;
        sceneCounts[scene] = (sceneCounts[scene] ?? 0) + 1;
      }

      final place = placeOf?.call(photo.location)?.trim() ?? '';
      if (place.isNotEmpty) {
        placeKnown++;
        placeCounts[place] = (placeCounts[place] ?? 0) + 1;
      }

      final category = photo.category?.trim() ?? '';
      if (category.isNotEmpty) {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      if (photo.hasFace) faceCount++;
      if (photo.isFavorite) favoriteCount++;
      final hour = date.hour;
      if (hour >= 19 || hour < 6) nightCount++;
    }

    int? busiestDay;
    var busiestCount = 0;
    perDay.forEach((day, count) {
      if (count > busiestCount || (count == busiestCount && (busiestDay == null || day < busiestDay!))) {
        busiestCount = count;
        busiestDay = day;
      }
    });

    return MonthlyFacts(
      year: year,
      month: month,
      photoCount: photos.length,
      activeDays: perDay.length,
      faceCount: faceCount,
      favoriteCount: favoriteCount,
      nightCount: nightCount,
      sceneCounts: sceneCounts,
      sceneKnownCount: sceneKnown,
      placeCounts: placeCounts,
      placeKnownCount: placeKnown,
      categoryCounts: categoryCounts,
      busiestDay: busiestDay,
      busiestDayCount: busiestCount,
    );
  }

  /// 由事实生成摘要。没有照片时返回 null（调用方不显示入口）。
  ///
  /// [mood] / [weather] / [steps] 是用户在月刊页手填的元数据，
  /// 只有真的填过（steps > 0、mood 非空）才会被引用。
  MonthlyRecap? build(
    MonthlyFacts facts, {
    String? mood,
    String? weather,
    int steps = 0,
  }) {
    if (facts.isEmpty) return null;

    final seed = _seed(facts.year, facts.month);
    final sentences = <String>[];

    // ① 数量 + 分布：这一句永远成立，用它开场。
    sentences.add(_openingSentence(facts));

    // ② 画面内容：场景优先，地名次之，都不够可信时退到「有人出镜」。
    final content = _contentSentence(facts);
    if (content != null) sentences.add(content);

    // ③ 收束：只引用用户自己填过的元数据与真实统计。
    sentences.add(_closingSentence(facts, seed, mood: mood, weather: weather, steps: steps));

    return MonthlyRecap(
      title: _title(facts, seed),
      sentences: sentences.take(maxSentences).toList(growable: false),
      keywords: keywordsFor(facts),
    );
  }

  /// 关键词：真实场景词 + 真实分类，绝不补「生活/时光」这类空词。
  List<String> keywordsFor(MonthlyFacts facts, {int limit = 6}) {
    final result = <String>[];
    void add(String value) {
      final text = value.trim();
      if (text.isEmpty || result.contains(text)) return;
      result.add(text);
    }

    for (final scene in facts.topScenes) {
      add(scene);
    }
    for (final category in facts.topCategories) {
      add(category);
    }
    return result.take(limit).toList(growable: false);
  }

  // ────────────────────────────────────────────────────────────
  //  句子装配
  // ────────────────────────────────────────────────────────────

  String _openingSentence(MonthlyFacts facts) {
    final n = facts.photoCount;
    final days = facts.activeDays;
    if (days <= 1) {
      return '这个月的 $n 张照片，都落在同一天。';
    }
    return '这个月留下 $n 张照片，散在 $days 天里。';
  }

  String? _contentSentence(MonthlyFacts facts) {
    final useScene = facts.sceneCoverage >= sceneCoverageFloor && facts.topScenes.isNotEmpty;
    final usePlace = facts.placeCoverage >= placeCoverageFloor && facts.topPlaces.isNotEmpty;

    if (useScene) {
      final first = facts.topScenes.first;
      final second = facts.topScenes.length > 1 ? facts.topScenes[1] : null;
      // 只有一个场景且占比压倒性时，说「几乎」；否则给两个词，避免单调。
      final dominated = facts.topSceneCount >= (facts.sceneKnownCount * 0.7);
      final tail = usePlace ? '，也去过${facts.topPlaces.first}。' : '。';
      if (second == null || dominated) {
        return '镜头几乎都停在「$first」$tail';
      }
      return '镜头大多停在「$first」，也有几回「$second」$tail';
    }

    if (usePlace) {
      final places = facts.topPlaces.take(2).toList();
      final joined = places.join('、');
      return '照片里有 $joined 的痕迹。';
    }

    if (facts.faceCount > 0) {
      return '其中 ${facts.faceCount} 张有人出镜。';
    }

    if (facts.topCategories.isNotEmpty) {
      return '它们大致归进了「${facts.topCategories.first}」。';
    }

    if (facts.favoriteCount > 0) {
      return '其中有 ${facts.favoriteCount} 张被你标成了精选。';
    }

    // 最后的兜底：时段是每张照片都有的确定信息，不会误判内容。
    if (facts.nightCount > 0) {
      return '有 ${facts.nightCount} 张是入夜之后拍的。';
    }

    return null;
  }

  String _closingSentence(
    MonthlyFacts facts,
    int seed, {
    String? mood,
    String? weather,
    int steps = 0,
  }) {
    // 候选按优先级排列，只保留有真实数据支撑的那几条，再按 seed 轮换开头。
    final candidates = <String>[];

    if (facts.busiestDay != null && facts.busiestDayCount > 1) {
      candidates.add('最热闹的是 ${facts.busiestDay} 号，一天拍了 ${facts.busiestDayCount} 张。');
    }
    if (steps > 0) {
      candidates.add('这个月走了 $steps 步，路没白走。');
    }
    if (mood != null && mood.trim().isNotEmpty && mood.trim() != '普通') {
      candidates.add('心情记作「${mood.trim()}」，也算给这段时间留了个注脚。');
    }
    if (weather != null && weather.trim().isNotEmpty) {
      candidates.add('天气记作「${weather.trim()}」，连同照片一起收好了。');
    }
    candidates.add('翻到这里，这个月就算收好了。');
    candidates.add('日子没有变慢，只是被留下来了。');

    return candidates[seed % candidates.length];
  }

  String _title(MonthlyFacts facts, int seed) {
    final scene = facts.topScenes.isNotEmpty &&
            facts.sceneCoverage >= sceneCoverageFloor
        ? facts.topScenes.first
        : null;
    final month = facts.month;

    if (scene != null) {
      final templates = <String>[
        '$month月 · $scene',
        '$month月的$scene',
        '$scene的那个$month月',
      ];
      return templates[seed % templates.length];
    }

    final fallback = <String>[
      '$month月留影',
      '$month月的${facts.photoCount}张',
      '${facts.year}年的第$month个月',
    ];
    return fallback[seed % fallback.length];
  }

  /// 稳定种子：同一个月、同一批数据每次生成结果一致，避免重进页面文案乱跳。
  int _seed(int year, int month) => (year * 137 + month * 31) % 997;
}
