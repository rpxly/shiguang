import 'dart:convert';

/// 端侧场景识别的结果。
///
/// 只承载「ML Kit 图像标签 → 中文场景词」这一条链路，不做任何猜测：
/// 如果标签集合里没有足够可信的场景证据，就不会产生 [SceneTag]，
/// 界面宁可不显示，也不编一个地名出来。
class SceneTag {
  /// 中文场景词，如「餐厅」「海边」。
  final String label;

  /// 该场景词对应的最高标签置信度 0~1。
  final double confidence;

  /// ML Kit 原始标签（英文），仅用于排查映射问题。
  final List<String> rawLabels;

  const SceneTag({
    required this.label,
    required this.confidence,
    this.rawLabels = const [],
  });

  @override
  String toString() => 'SceneTag($label, ${confidence.toStringAsFixed(2)})';
}

/// 落盘记录。
///
/// 区分「识别出场景词」与「识别过但没有结论」：后者同样要记下来，
/// 否则每次启动都会重复推理同一张照片。
class SceneRecord {
  /// 规则表版本。升级映射表后旧记录自动失效并重算。
  static const int currentVersion = 1;

  final int version;
  final SceneTag? tag;

  const SceneRecord({this.version = currentVersion, this.tag});

  bool get isUpToDate => version == currentVersion;

  /// 只有版本一致的结果才可信。
  SceneTag? get validTag => isUpToDate ? tag : null;

  String encode() => jsonEncode({
        'v': version,
        if (tag != null) 'label': tag!.label,
        if (tag != null) 'conf': tag!.confidence,
        if (tag != null && tag!.rawLabels.isNotEmpty) 'raw': tag!.rawLabels,
      });

  static SceneRecord? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final version = decoded['v'] is int ? decoded['v'] as int : 0;
      final label = decoded['label'];
      if (label is! String || label.isEmpty) {
        return SceneRecord(version: version);
      }
      final confidence = decoded['conf'];
      final rawLabels = decoded['raw'];
      return SceneRecord(
        version: version,
        tag: SceneTag(
          label: label,
          confidence: confidence is num ? confidence.toDouble() : 0,
          rawLabels: rawLabels is List
              ? rawLabels.whereType<String>().toList(growable: false)
              : const [],
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
