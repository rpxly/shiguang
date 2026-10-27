import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 本地埋点（只落盘，不联网）。
///
/// 存在的原因：方向清单里「62% 进入月刊」「41% 生成」这两组数是**示例数据**，
/// 不能拿去支撑「AI 叙事值不值得做」的决策。这个服务负责把真实的
/// 「整理完成 → 进入月刊 → 生成 → 导出」四段记下来，攒够一周再看。
///
/// 三条设计约束：
/// 1. **不引入第三方 SDK**：一个 JSONL 文件足矣，不联网、不上传、不影响启动；
/// 2. **不阻塞 UI**：`log()` 是同步返回的，写盘异步排队，写失败静默（埋点不能弄崩业务）；
/// 3. **可核对**：每条记录带时间戳与 props，比率能一路回查到原始事件。
class AnalyticsService {
  AnalyticsService({Directory? dirOverride}) : _dirOverride = dirOverride;

  /// 全局单例。业务代码只该用这个。
  static final AnalyticsService instance = AnalyticsService();

  /// 单文件上限。超过后按行裁剪（保留最新的 [_maxLines] 条），
  /// 避免一个用户攒一年把文件撑到几十 MB。
  static const int _maxLines = 5000;

  final Directory? _dirOverride;

  File? _file;
  final List<AnalyticsRecord> _records = [];
  Future<void>? _loading;
  Future<void> _writeQueue = Future<void>.value();

  /// 落盘失败原因（调试页展示用，不影响业务）。
  String? lastError;

  bool get isReady => _file != null;

  /// 读取历史记录。可重复调用，只会真正加载一次。
  Future<void> ensureLoaded() {
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final dir = _dirOverride ?? await _dirOf();
      final file = File('${dir.path}${Platform.pathSeparator}events.jsonl');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      _file = file;
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final record = AnalyticsRecord.tryParse(line);
        if (record != null) _records.add(record);
      }
      _records.sort((a, b) => a.time.compareTo(b.time));
      if (_records.length > _maxLines) {
        _records.removeRange(0, _records.length - _maxLines);
      }
    } catch (e) {
      // 拿不到目录（比如单元测试没装插件）时退化成纯内存，功能不残废。
      lastError = '埋点目录不可用：$e';
      debugPrint('[Analytics] $lastError');
      _file = null;
    }
  }

  Future<Directory> _dirOf() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}analytics');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 记一条事件。**同步返回**，不 await、不抛异常。
  void log(AnalyticsEvent event, {Map<String, Object?> props = const {}}) {
    final record = AnalyticsRecord(
      time: DateTime.now(),
      event: event.key,
      props: Map<String, Object?>.from(props),
    );
    _records.add(record);
    if (_records.length > _maxLines) {
      _records.removeRange(0, _records.length - _maxLines);
    }
    // 排队写盘：串行、失败静默。不 await，UI 线程不等 IO。
    _writeQueue = _writeQueue.then((_) => _append(record)).catchError((Object e) {
      lastError = '写埋点失败：$e';
      debugPrint('[Analytics] $lastError');
    });
  }

  Future<void> _append(AnalyticsRecord record) async {
    await ensureLoaded();
    final file = _file;
    if (file == null) return; // 纯内存模式
    await file.writeAsString('${record.toJsonLine()}\n', mode: FileMode.append, flush: true);
  }

  /// 等写盘队列清空。测试与「导出前确保落盘」用；业务代码不需要 await。
  Future<void> flush() => _writeQueue;

  /// 聚合最近 [days] 天（含今天）的漏斗。按「天」去重：
  /// 同一天点开十次月刊只算一次进入，避免刷点击把比率刷高。
  FunnelReport funnel({int days = 7}) {
    final today = _dayOf(DateTime.now());
    final buckets = <DateTime, Map<String, int>>{};
    for (var i = days - 1; i >= 0; i--) {
      buckets[today.subtract(Duration(days: i))] = <String, int>{};
    }
    final counts = <String, int>{};
    for (final record in _records) {
      counts[record.event] = (counts[record.event] ?? 0) + 1;
      final day = buckets[_dayOf(record.time)];
      if (day != null) day[record.event] = (day[record.event] ?? 0) + 1;
    }

    final rows = buckets.entries
        .map((e) => FunnelDay(
              date: e.key,
              counts: e.value,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final recent = _records.length <= 20
        ? _records.reversed.toList()
        : _records.sublist(_records.length - 20).reversed.toList();

    return FunnelReport(days: rows, eventCounts: counts, recent: recent, filePath: _file?.path);
  }

  /// 导出的原文（贴给别人看 / 自己 grep 都方便）。
  String dumpJsonl() => _records.map((r) => r.toJsonLine()).join('\n');

  /// 清空（含磁盘）。调试页的「清空」按钮用。
  Future<void> reset() async {
    _records.clear();
    lastError = null;
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString('', flush: true);
    } catch (e) {
      lastError = '清空失败：$e';
    }
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// 事件名。**key 一旦上线就不能改**（历史数据靠它对齐）。
enum AnalyticsEvent {
  /// 用户真正把整理结果落盘了（移动/归档成功，moved > 0）。
  organizeCompleted('organize_completed'),

  /// 打开月刊页。
  magazineOpened('magazine_opened'),

  /// 用户产出了月刊内容。props.source = ai / quote / manual / page_add
  magazineGenerated('magazine_generated'),

  /// 导出动作完成（分享面板已唤起）。props.type = single / a4 / template
  magazineExported('magazine_exported');

  const AnalyticsEvent(this.key);
  final String key;
}

@immutable
class AnalyticsRecord {
  const AnalyticsRecord({required this.time, required this.event, required this.props});

  final DateTime time;
  final String event;
  final Map<String, Object?> props;

  String toJsonLine() => jsonEncode({
        't': time.toIso8601String(),
        'e': event,
        if (props.isNotEmpty) 'p': props,
      });

  static AnalyticsRecord? tryParse(String line) {
    try {
      final map = jsonDecode(line) as Map<String, dynamic>;
      final time = DateTime.tryParse(map['t'] as String? ?? '');
      final event = map['e'] as String?;
      if (time == null || event == null) return null;
      final rawProps = map['p'];
      return AnalyticsRecord(
        time: time,
        event: event,
        props: rawProps is Map<String, dynamic> ? Map<String, Object?>.from(rawProps) : const {},
      );
    } catch (_) {
      return null; // 单行坏了跳过，不让一条脏数据废掉整个文件
    }
  }
}

@immutable
class FunnelDay {
  const FunnelDay({required this.date, required this.counts});

  final DateTime date;
  final Map<String, int> counts;

  int count(AnalyticsEvent event) => counts[event.key] ?? 0;

  bool get hasOrganize => count(AnalyticsEvent.organizeCompleted) > 0;
  bool get hasOpened => count(AnalyticsEvent.magazineOpened) > 0;
  bool get hasGenerated => count(AnalyticsEvent.magazineGenerated) > 0;
  bool get hasExported => count(AnalyticsEvent.magazineExported) > 0;
}

/// 漏斗结果。
///
/// **读法**：分母是「有整理完成的天数」，不是「用户数」。单机一周最多 7 个样本，
/// 所以 [isSampleEnough] 为 false 时比率只能当方向看，不能当结论写进文档。
class FunnelReport {
  const FunnelReport({
    required this.days,
    required this.eventCounts,
    required this.recent,
    this.filePath,
  });

  final List<FunnelDay> days;
  final Map<String, int> eventCounts;
  final List<AnalyticsRecord> recent;
  final String? filePath;

  int get organizedDays => days.where((d) => d.hasOrganize).length;
  int get openedDays => days.where((d) => d.hasOrganize && d.hasOpened).length;
  int get generatedDays => days.where((d) => d.hasOrganize && d.hasGenerated).length;
  int get exportedDays => days.where((d) => d.hasOrganize && d.hasExported).length;

  /// 样本 <5 天时不做百分比结论。
  bool get isSampleEnough => organizedDays >= 5;

  double? get enterRate => _rate(openedDays);
  double? get generateRate => _rate(generatedDays);
  double? get exportRate => _rate(exportedDays);

  double? _rate(int numerator) =>
      organizedDays == 0 ? null : numerator / organizedDays;

  /// 全量计数（不受 [days] 窗口限制），用来对账。
  int countOf(AnalyticsEvent event) => eventCounts[event.key] ?? 0;

  String rateText(double? rate) =>
      rate == null ? '—' : '${(rate * 100).toStringAsFixed(0)}%';
}
