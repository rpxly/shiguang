import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/photo.dart';
import '../models/scene_tag.dart';
import '../repository/local_repository.dart';

/// 一条「标签 → 中文场景词」规则。
///
/// [weight] 用于压过过于泛化的标签（例如几乎每张带人的照片都会出 people），
/// [minScore] 是这条规则的最低分，避免靠一个弱标签硬凑出场景。
class _SceneRule {
  final String tag;
  final List<String> keys;
  final double weight;
  final double minScore;

  const _SceneRule(
    this.tag,
    this.keys, {
    this.weight = 1.0,
    this.minScore = 0.5,
  });
}

/// 顺序即优先级：分数相同时靠前的规则胜出。
///
/// 这些词全部来自 ML Kit 基础图像标注模型（英文标签）的真实输出，
/// 不做地理位置推断——所以「餐厅」的意思是「这张图里有餐厅场景的证据」，
/// 而不是「GPS 落点在餐厅」。
const List<_SceneRule> _rules = [
  _SceneRule('咖啡厅', [
    'cafe', 'café', 'coffeehouse', 'coffee house', 'coffee', 'latte',
    'espresso', 'cappuccino', 'barista', 'coffee cup', 'tea house', 'teahouse',
  ]),
  _SceneRule('餐厅', [
    'restaurant', 'fast food', 'cuisine', 'dining', 'bistro', 'pizzeria',
    'buffet', 'brasserie',
  ]),
  _SceneRule('美食', [
    'food', 'dish', 'plate', 'tableware', 'dessert', 'cake', 'bread', 'pizza',
    'sushi', 'noodle', 'pasta', 'hamburger', 'salad', 'breakfast', 'lunch',
    'dinner', 'meal', 'cooking', 'recipe', 'ingredient', 'fruit', 'snack',
    'baked goods',
  ], weight: 0.95, minScore: 0.55),
  _SceneRule('海边', [
    'beach', 'sea', 'ocean', 'coast', 'shore', 'seaside', 'wave', 'bay',
    'island', 'harbor', 'harbour', 'surf',
  ]),
  _SceneRule('公园', [
    'park', 'garden', 'lawn', 'playground', 'fountain', 'picnic',
    'botanical garden',
  ]),
  _SceneRule('山野', [
    'mountain', 'forest', 'hill', 'valley', 'lake', 'river', 'waterfall',
    'countryside', 'field', 'meadow', 'trail', 'hiking', 'nature', 'glacier',
    'desert',
  ]),
  _SceneRule('夜景', [
    'night', 'night sky', 'cityscape', 'fireworks', 'neon', 'dusk', 'twilight',
  ], weight: 0.9),
  _SceneRule('街头', [
    'street', 'road', 'city', 'town', 'sidewalk', 'alley', 'intersection',
    'traffic', 'urban area', 'skyscraper', 'building', 'architecture', 'bridge',
    'crosswalk', 'downtown', 'parking lot',
  ], weight: 0.9),
  _SceneRule('办公室', [
    'office', 'desk', 'workstation', 'computer', 'laptop', 'monitor',
    'keyboard', 'conference', 'meeting', 'whiteboard', 'coworking',
  ]),
  _SceneRule('展馆', [
    'museum', 'art gallery', 'gallery', 'exhibition', 'painting', 'sculpture',
    'aquarium', 'zoo', 'art', 'artifact',
  ]),
  _SceneRule('家里', [
    'living room', 'bedroom', 'room', 'interior design', 'furniture', 'sofa',
    'couch', 'bed', 'kitchen', 'bathroom', 'home', 'house', 'curtain', 'pillow',
  ], weight: 0.95),
  _SceneRule('聚会', [
    'wedding', 'party', 'birthday', 'concert', 'festival', 'crowd',
    'celebration', 'ceremony', 'stage', 'banquet',
  ], weight: 0.95),
  _SceneRule('宠物', [
    'dog', 'cat', 'puppy', 'kitten', 'pet', 'hamster', 'rabbit',
  ]),
  _SceneRule('运动', [
    'sport', 'gym', 'basketball', 'football', 'soccer', 'bicycle', 'biking',
    'running', 'swimming', 'tennis', 'yoga', 'fitness', 'stadium', 'skateboard',
  ]),
  // 人像压到最后：场景证据足够时优先给场景，只有在没有场景线索时才回落到人像
  _SceneRule('人像', [
    'selfie', 'portrait', 'smile', 'face', 'people', 'person', 'child', 'baby',
    'family', 'group',
  ], weight: 0.6),
];

/// 单张照片的推理结果。
///
/// [skipped] 表示这张被别的任务抢先处理/平台不可用，调用方不应落盘，
/// 否则会把「没算过」误记成「算过但没结果」。
class _Inference {
  final SceneTag? tag;
  final bool skipped;

  const _Inference({this.tag, this.skipped = false});
}

/// 端侧场景识别。
///
/// 用 ML Kit 图像标注（离线、无需联网）给照片打一个中文场景词，
/// 结果落盘到 `scene_tags` 盒子，界面只读不猜。
class SceneClassifier extends ChangeNotifier {
  SceneClassifier._();

  static final SceneClassifier instance = SceneClassifier._();

  /// 单轮后台识别的默认张数上限（只补最近的照片，避免首次启动跑几千张）。
  static const int defaultWarmUpLimit = 240;

  /// 单轮后台识别的时间预算，超时就等下次启动继续。
  static const Duration defaultBudget = Duration(seconds: 20);

  static const Duration _notifyInterval = Duration(milliseconds: 200);

  LocalRepository? _repository;
  ImageLabeler? _labeler;
  bool _platformUnavailable = false;
  bool _warming = false;
  final Set<String> _inFlight = <String>{};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _notifyTimer;

  /// 端侧模型是否可用。桌面端/未接入平台时降级为「不显示场景词」。
  bool get isAvailable => !_platformUnavailable;

  void attach(LocalRepository repository) {
    if (identical(_repository, repository)) return;
    _repository = repository;
  }

  // ──────────────────────────────────────────────
  //  读取（界面同步调用，走仓库内存缓存）
  // ──────────────────────────────────────────────

  SceneTag? tagFor(String photoId) => _repository?.getSceneRecord(photoId)?.validTag;

  String? labelFor(String photoId) => tagFor(photoId)?.label;

  /// 「31.2304, 121.4737」这种没经过反向地理编码的原始坐标。
  static bool looksLikeCoordinates(String? value) {
    if (value == null) return false;
    final text = value.trim();
    if (text.isEmpty) return false;
    return RegExp(r'^-?\d{1,3}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?$').hasMatch(text);
  }

  /// 能给人看的地名。原始坐标一律视为「没有信息」，返回 null。
  static String? readablePlace(String? location) {
    if (location == null) return null;
    final text = location.trim();
    if (text.isEmpty) return null;
    if (looksLikeCoordinates(text)) return null;
    return text;
  }

  /// 场景词 → 可读地名，都不存在时返回 null。
  String? placeLabelFor(Photo photo) {
    final scene = labelFor(photo.id);
    if (scene != null && scene.isNotEmpty) return scene;
    return readablePlace(photo.location);
  }

  /// 卡片副标题：场景词 → 可读地名 → 拍摄时间。
  ///
  /// 三个来源都是真实数据；全都没有时返回 null，由界面决定不渲染这一行。
  String? subtitleFor(Photo photo, {bool fallbackToTime = true}) {
    final label = placeLabelFor(photo);
    if (label != null) return label;

    if (!fallbackToTime) return null;
    final date = photo.dateTime;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ──────────────────────────────────────────────
  //  识别
  // ──────────────────────────────────────────────

  /// 后台补齐最近 [limit] 张照片的场景词。
  ///
  /// 已经有当前版本记录的照片直接跳过，因此重复调用是安全的；
  /// 单轮受 [budget] 限制，不会一直占着设备。
  Future<void> warmUp({
    int limit = defaultWarmUpLimit,
    Duration budget = defaultBudget,
  }) async {
    final repository = _repository;
    if (repository == null || _warming || _platformUnavailable) return;

    final photos = [...repository.getAllPhotos()]
      ..sort((a, b) => b.date.compareTo(a.date));

    _warming = true;
    final stopwatch = Stopwatch()..start();
    var classified = 0;
    try {
      for (final photo in photos.take(limit)) {
        if (stopwatch.elapsed > budget) break;
        if (_platformUnavailable) break;

        final existing = repository.getSceneRecord(photo.id);
        if (existing != null && existing.isUpToDate) continue;

        final result = await _classifyPhoto(photo);
        if (_platformUnavailable) break;
        if (result.skipped) continue;

        repository.saveSceneRecord(photo.id, SceneRecord(tag: result.tag));
        classified++;
        _notifyThrottled();
      }
    } catch (e) {
      debugPrint('[Scene] 后台识别中断: $e');
    } finally {
      _warming = false;
      stopwatch.stop();
      _notifyNow();
      if (classified > 0) {
        debugPrint('[Scene] 本轮识别 $classified 张，用时 ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }

  /// 立即识别指定照片（用于当前可见卡片，不等后台队列）。
  Future<void> classifyNow(Iterable<Photo> photos) async {
    final repository = _repository;
    if (repository == null || _platformUnavailable) return;
    for (final photo in photos) {
      if (_platformUnavailable) return;
      final existing = repository.getSceneRecord(photo.id);
      if (existing != null && existing.isUpToDate) continue;
      final result = await _classifyPhoto(photo);
      if (_platformUnavailable) return;
      if (result.skipped) continue;
      repository.saveSceneRecord(photo.id, SceneRecord(tag: result.tag));
      _notifyNow();
    }
  }

  Future<_Inference> _classifyPhoto(Photo photo) async {
    if (!_inFlight.add(photo.id)) return const _Inference(skipped: true);
    try {
      final path = _sourcePath(photo);
      if (path == null) return const _Inference();

      final labeler = await _ensureLabeler();
      if (labeler == null) return const _Inference(skipped: true);

      try {
        final labels = await labeler.processImage(InputImage.fromFilePath(path));
        return _Inference(tag: _bestTag(labels));
      } on MissingPluginException catch (e) {
        // 平台插件缺失（桌面端/未打进 APK）：整轮直接停，且不落盘，避免把
        // 「没算过」误记成「算过但没结果」
        _platformUnavailable = true;
        debugPrint('[Scene] 图像标注平台不可用，停止识别: $e');
        return const _Inference(skipped: true);
      } catch (e) {
        // 单张图片解码失败等，只跳过这一张
        debugPrint('[Scene] 识别失败 ${photo.id}: $e');
        return const _Inference();
      }
    } finally {
      _inFlight.remove(photo.id);
    }
  }

  /// 优先用 512px 缩略图推理：更快、更省内存，且对场景判断足够。
  String? _sourcePath(Photo photo) {
    for (final candidate in [photo.thumbnailPath, photo.path]) {
      if (candidate.isEmpty) continue;
      if (candidate.startsWith('assets/')) continue;
      try {
        if (File(candidate).existsSync()) return candidate;
      } catch (_) {}
    }
    return null;
  }

  Future<ImageLabeler?> _ensureLabeler() async {
    if (_platformUnavailable) return null;
    final existing = _labeler;
    if (existing != null) return existing;
    try {
      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.4),
      );
      _labeler = labeler;
      return labeler;
    } catch (e) {
      _platformUnavailable = true;
      debugPrint('[Scene] 图像标注不可用，场景词降级为时间显示: $e');
      return null;
    }
  }

  SceneTag? _bestTag(List<ImageLabel> labels) {
    if (labels.isEmpty) return null;
    final confidences = <String, double>{};
    for (final label in labels) {
      final key = label.label.toLowerCase();
      final current = confidences[key];
      if (current == null || current < label.confidence) {
        confidences[key] = label.confidence;
      }
    }
    return tagFromLabels(confidences);
  }

  /// 纯映射逻辑：英文标签置信度 → 中文场景词，便于单测。
  @visibleForTesting
  SceneTag? tagFromLabels(Map<String, double> confidences) {
    SceneTag? best;
    var bestScore = 0.0;
    var bestOrder = _rules.length;

    for (var order = 0; order < _rules.length; order++) {
      final rule = _rules[order];
      var ruleScore = 0.0;
      final hits = <String>[];

      confidences.forEach((label, confidence) {
        final text = label.toLowerCase();
        if (!_matches(text, rule.keys)) return;
        hits.add(label);
        final score = confidence * rule.weight;
        if (score > ruleScore) ruleScore = score;
      });

      if (ruleScore < rule.minScore) continue;
      if (ruleScore > bestScore || (ruleScore == bestScore && order < bestOrder)) {
        bestScore = ruleScore;
        bestOrder = order;
        best = SceneTag(label: rule.tag, confidence: ruleScore, rawLabels: hits);
      }
    }
    return best;
  }

  /// 按词边界匹配，避免 sea 命中 season、park 命中 parking 这类误报。
  bool _matches(String label, List<String> keys) {
    for (final key in keys) {
      if (_tokenHit(label, key)) return true;
    }
    return false;
  }

  bool _tokenHit(String label, String key) {
    if (label == key) return true;
    if (label == '${key}s') return true;
    if (label.startsWith('$key ')) return true;
    if (label.endsWith(' $key')) return true;
    if (label.contains(' $key ')) return true;
    if (label.endsWith(' ${key}s')) return true;
    return false;
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify) >= _notifyInterval) {
      _notifyNow();
      return;
    }
    _notifyTimer ??= Timer(_notifyInterval, () {
      _notifyTimer = null;
      _notifyNow();
    });
  }

  void _notifyNow() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _lastNotify = DateTime.now();
    notifyListeners();
  }

  Future<void> release() async {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    final labeler = _labeler;
    _labeler = null;
    if (labeler != null) {
      try {
        await labeler.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    final labeler = _labeler;
    _labeler = null;
    labeler?.close();
    super.dispose();
  }
}
