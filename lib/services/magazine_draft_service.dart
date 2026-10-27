import '../models/photo.dart';
import '../pages/monthly/magazine_models.dart';

/// 一键成刊的结果。
class MagazineDraft {
  const MagazineDraft({
    required this.pages,
    required this.photos,
    required this.candidateCount,
    required this.dayCount,
  });

  /// 排好版的页面（按拍摄时间升序）。
  final List<MagPage> pages;

  /// 选中的照片，顺序与 [pages] 一一对应。
  final List<Photo> photos;

  /// 本月可用于选片的照片总数（用来向用户解释「从多少张里挑了这几张」）。
  final int candidateCount;

  /// 选中的照片覆盖了多少天。
  final int dayCount;
}

/// 一键成刊：把「本月照片」直接变成一本排好版、配好图注的月刊草稿。
///
/// 这是方向 3.1 真正要的东西 —— **用户点一下就该有一本月刊**，
/// 而不是「先一张张导入、再选模板、再配文案」。
///
/// 三条设计原则：
/// 1. **瞬时**：纯计算，不调模型。端侧 1.7B 生成一句话要 40 秒（#10 实测），
///    它撑不起「一键」，所以草稿永远走规则；AI 只作为事后可选润色。
/// 2. **可解释**：每页图注只陈述真实数据（场景词 / 地名 / 日期），不编画面。
/// 3. **确定**：同一批照片、同一个月，任何时候生成的草稿完全一致 ——
///    否则用户「重来一次」会得到另一本，无法建立预期。
class MagazineDraftService {
  const MagazineDraftService();

  /// 一本文刊放几页。与手动导入的上限（12 张）保持一致以下，9 页翻起来不累。
  static const int defaultMaxPages = 9;

  /// 每天最多先取 2 张，保证「天数覆盖」；天数太少时自动放宽到 3、4…
  static const int _perDayFirstPass = 2;

  /// 模板节奏：开篇全幅、结尾胶片，中间三种交替。
  static const List<MagTemplate> _opening = [MagTemplate.fullBleed];
  static const List<MagTemplate> _middle = [
    MagTemplate.bottomWhite,
    MagTemplate.centerLine,
    MagTemplate.polaroid,
  ];
  static const MagTemplate _closing = MagTemplate.filmGrain;

  /// 生成本月草稿。本月没有照片时返回 null（调用方负责提示「先扫描相册」）。
  ///
  /// [sceneOf] / [placeOf] 由调用方注入（一般传 SceneClassifier 的方法），
  /// 便于单测时给假数据，也避免这个纯逻辑文件依赖 ML Kit。
  MagazineDraft? build({
    required List<Photo> monthPhotos,
    required int year,
    required int month,
    int maxPages = defaultMaxPages,
    String? Function(String photoId)? sceneOf,
    String? Function(String? location)? placeOf,
  }) {
    final photos = monthPhotos
        .where((p) => p.dateTime.year == year && p.dateTime.month == month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (photos.isEmpty) return null;

    final selected = _pick(photos, maxPages, sceneOf);
    final pages = <MagPage>[];
    for (var i = 0; i < selected.length; i++) {
      final photo = selected[i];
      pages.add(MagPage(
        id: 'draft_${photo.id}',
        photoIds: [photo.id],
        template: _templateAt(i, selected.length),
        caption: captionFor(
          photo,
          year: year,
          month: month,
          scene: sceneOf?.call(photo.id),
          place: placeOf?.call(photo.location),
        ),
      ));
    }

    return MagazineDraft(
      pages: pages,
      photos: selected,
      candidateCount: photos.length,
      dayCount: selected.map((p) => p.dateTime.day).toSet().length,
    );
  }

  /// 选片：先按天分桶保证覆盖，再按分数补齐。
  ///
  /// 排序权重只用真实存在的字段（质量分/收藏/人脸/有场景词），
  /// 不做任何「审美判断」——那样错了没法解释。
  List<Photo> _pick(
    List<Photo> photos,
    int maxPages,
    String? Function(String photoId)? sceneOf,
  ) {
    final byDay = <int, List<Photo>>{};
    for (final photo in photos) {
      byDay.putIfAbsent(photo.dateTime.day, () => []).add(photo);
    }
    for (final list in byDay.values) {
      list.sort((a, b) {
        final diff = _score(b, sceneOf).compareTo(_score(a, sceneOf));
        // 同分时按时间，保证结果稳定（不要依赖 List.sort 的不稳定性）
        return diff != 0 ? diff : a.date.compareTo(b.date);
      });
    }

    final days = byDay.keys.toList()..sort();
    final picked = <Photo>{};
    var perDay = _perDayFirstPass;
    while (picked.length < maxPages && perDay <= 12) {
      picked.clear();
      for (final day in days) {
        final list = byDay[day]!;
        picked.addAll(list.take(perDay));
      }
      if (picked.length >= maxPages) break;
      if (picked.length == photos.length) break; // 照片本来就不够
      perDay++;
    }

    var result = picked.toList()..sort((a, b) => a.date.compareTo(b.date));
    if (result.length > maxPages) {
      // 只要 1 页时，「保留首尾」没有意义 —— 语义应该是「整月最好的一张」，
      // 所以按分数取，而不是取最早那张。
      if (maxPages <= 1) {
        final best = result.reduce(
          (a, b) => _score(b, sceneOf) > _score(a, sceneOf) ? b : a,
        );
        return [best];
      }
      result = _evenlyTrim(result, maxPages);
    }
    return result;
  }

  int _score(Photo photo, String? Function(String photoId)? sceneOf) {
    var score = photo.qualityScore;
    if (photo.isFavorite) score += 30;
    if (photo.hasFace) score += 10;
    final scene = sceneOf?.call(photo.id);
    if (scene != null && scene.isNotEmpty) score += 5;
    return score;
  }

  /// 超过上限时均匀裁掉，**保留首尾**（开篇和收尾对一本册子最重要）。
  ///
  /// 中间按 `middle.length / slots` 等距取，step ≥ 1 保证不会取到重复项
  /// （只有 `total - 2 > slots` 才会走到这里，即 middle 一定比 slots 长）。
  List<Photo> _evenlyTrim(List<Photo> sorted, int maxPages) {
    final middle = sorted.sublist(1, sorted.length - 1);
    final slots = maxPages - 2;
    final result = <Photo>[sorted.first];
    for (var i = 0; i < slots; i++) {
      final index = (i * middle.length / slots).floor();
      result.add(middle[index.clamp(0, middle.length - 1)]);
    }
    result.add(sorted.last);
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  MagTemplate _templateAt(int index, int total) {
    if (total == 1) return _opening.first;
    if (index == 0) return _opening.first;
    if (index == total - 1) return _closing;
    return _middle[(index - 1) % _middle.length];
  }

  /// 单页图注：只写能核对的事实。
  ///
  /// 优先级：场景词（带时段）→ 地名 → 日期。三条都拿不到时退回「M月D日」，
  /// 不写「美好的一天」这类放之四海皆准的空话。
  String captionFor(
    Photo photo, {
    required int year,
    required int month,
    String? scene,
    String? place,
  }) =>
      magazineCaption(photo, scene: scene, place: place);
}

/// 图注规则的唯一实现。月刊页和一键成刊、导出共用它，
/// 避免「同一张照片在时间线和导出里被写成两句话」。
String magazineCaption(Photo photo, {String? scene, String? place}) {
  final date = photo.dateTime;
  if (scene != null && scene.trim().isNotEmpty) {
    final period = magazinePeriodOf(date.hour);
    return period == null ? scene.trim() : '$period的${scene.trim()}';
  }
  if (place != null && place.trim().isNotEmpty) return place.trim();
  return '${date.month}月${date.day}日';
}

/// 时段词。只有确实带着时间信息才加，避免「深夜的风景」这种过度解读——
/// 真正判断依据就是拍摄小时，属于事实。
String? magazinePeriodOf(int hour) {
  if (hour >= 5 && hour < 8) return '清晨';
  if (hour >= 8 && hour < 11) return '上午';
  if (hour >= 11 && hour < 14) return '午后';
  if (hour >= 14 && hour < 18) return '下午';
  if (hour >= 18 && hour < 22) return '傍晚';
  return '夜里';
}
