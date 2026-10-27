import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/models/photo.dart';
import 'package:shiguang/services/monthly_recap_service.dart';
import 'package:shiguang/services/on_device_ai_service.dart';

Photo _photo(int day, {required String id, bool hasFace = false, int hour = 12}) {
  return Photo(
    id: id,
    path: '/tmp/$id.jpg',
    thumbnailPath: '/tmp/t$id.jpg',
    date: DateTime(2026, 8, day, hour),
    fileSize: 1024,
    hasFace: hasFace,
  );
}

MonthlyFacts _facts() {
  const recap = MonthlyRecapService();
  final photos = [for (var i = 1; i <= 8; i++) _photo(i, id: 'p$i', hasFace: i <= 3)];
  return recap.collectFacts(
    photos,
    year: 2026,
    month: 8,
    sceneOf: (id) => '海边',
    placeOf: (loc) => loc,
  );
}

/// 可控的假推理后端，用来验证流式装配与失败兜底。
class _FakeBackend implements LlamaBackend {
  final List<String> tokens;
  final bool failOnLoad;
  final bool throwMidStream;

  bool loaded = false;
  bool disposed = false;
  String? seenPrompt;
  int? seenMaxTokens;

  _FakeBackend({
    this.tokens = const ['这个月', '有八张', '照片。'],
    this.failOnLoad = false,
    this.throwMidStream = false,
  });

  @override
  Future<void> load(String modelPath) async {
    if (failOnLoad) throw StateError('boom');
    loaded = true;
  }

  @override
  Stream<String> generate(String prompt, {int maxTokens = 256}) async* {
    seenPrompt = prompt;
    seenMaxTokens = maxTokens;
    for (final token in tokens) {
      if (throwMidStream) throw StateError('stream broken');
      yield token;
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// 永远只吐第一个 token 之后就卡住，用来验证超时兜底。
class _HangingBackend implements LlamaBackend {
  @override
  Future<void> load(String modelPath) async {}

  @override
  Stream<String> generate(String prompt, {int maxTokens = 256}) =>
      Stream<String>.periodic(const Duration(seconds: 5), (i) => 'x');

  @override
  Future<void> dispose() async {}
}

/// 「接线后、设备与模型都合格」的状态，用于绕过真实文件检测。
DeviceAiStatus _readyStatus() => const DeviceAiStatus(
      canRun: true,
      reason: '可用',
      profile: DeviceProfile(
        os: 'android',
        abi: 'arm64-v8a',
        totalRamMb: 8192,
        freeRamMb: 4096,
      ),
      modelPath: '/tmp/model.gguf',
      modelBytes: kExpectedModelBytes,
    );

void main() {
  group('提示词构造', () {
    const builder = RecapPromptBuilder();

    test('只写事实里有的字段，没填的不出现', () {
      final prompt = builder.build(NarrationRequest(facts: _facts()));
      expect(prompt.user, contains('2026 年 8 月'));
      expect(prompt.user, contains('8 张'));
      expect(prompt.user, contains('海边 8 张'));
      expect(prompt.user, isNot(contains('心情')));
      expect(prompt.user, isNot(contains('步数')));
      expect(prompt.user, endsWith('直接输出正文。/no_think'));
    });

    test('填了心情/天气/步数才注入', () {
      final prompt = builder.build(NarrationRequest(
        facts: _facts(),
        mood: '平静',
        weather: '晴',
        steps: 123456,
      ));
      expect(prompt.user, contains('平静'));
      expect(prompt.user, contains('晴'));
      expect(prompt.user, contains('123456'));
    });

    test('user 消息末尾带 /no_think 软开关（离线验证的硬约束）', () {
      final prompt = builder.build(NarrationRequest(facts: _facts()));
      expect(prompt.user, endsWith('直接输出正文。/no_think'));
    });

    test('精选与夜间拍摄行按事实注入', () {
      const recap = MonthlyRecapService();
      final photos = [
        _photo(1, id: 'k1', hasFace: false),
        _photo(2, id: 'k2', hour: 22),
        _photo(3, id: 'k3', hour: 23),
      ];
      final facts = recap.collectFacts(photos, year: 2026, month: 8);
      final prompt = builder.build(NarrationRequest(facts: facts));
      expect(prompt.user, contains('夜间拍摄：2 张'));
      expect(prompt.user, isNot(contains('精选')));
      expect(prompt.user, isNot(contains('有人出镜')));
    });

    test('factRowCount：数据厚 ≥4，单张照片只有 2 行', () {
      final rich = builder.factRowCount(NarrationRequest(facts: _facts()));
      expect(rich, greaterThanOrEqualTo(4));

      const recap = MonthlyRecapService();
      final single = recap.collectFacts(
        [_photo(26, id: 's1')],
        year: 2026,
        month: 8,
      );
      final thin = builder.factRowCount(NarrationRequest(facts: single));
      expect(thin, 2);
      expect(thin, lessThan(kMinFactRows));
    });

    test('system 里有禁止编造的约束', () {
      final prompt = builder.build(NarrationRequest(facts: _facts()));
      expect(prompt.system, contains('绝不补充'));
      expect(prompt.toChatMl(), contains('<|im_start|>system'));
      expect(prompt.toChatMl(), endsWith('<|im_start|>assistant\n'));
    });
  });

  group('设备闸门', () {
    test('读设备画像不抛异常（桌面端也要能跑）', () async {
      final profile = await DeviceProfile.read();
      expect(profile.os, isNotEmpty);
      expect(profile.abi, isNotEmpty);
    });

    test('默认构造（已接线）：桌面端 canRun 为 false 且给出原因', () async {
      final status = await const OnDeviceAiService().inspect();
      expect(status.canRun, isFalse);
      // 桌面端：'仅 Android 走端侧推理'；无模型路径：'模型未下载或未下完'
      expect(status.reason, isNotEmpty);
    });
  });

  group('叙事降级链路', () {
    test('默认构造（已接线）：设备不达标时先给规则版，并带上原因', () async {
      final events = await const OnDeviceAiService()
          .narrate(NarrationRequest(facts: _facts()))
          .toList();

      final done = events.whereType<NarrationDone>().single;
      expect(done.fromFallback, isTrue);
      expect(done.text, contains('8 张照片'));
      expect(done.note, isNotEmpty); // 桌面端为「仅 Android 走端侧推理」
      expect(events.whereType<NarrationFailed>(), isEmpty);
    });

    test('没有照片时返回失败而不是空文本', () async {
      const recap = MonthlyRecapService();
      final empty = recap.collectFacts([], year: 2026, month: 8);
      final events = await const OnDeviceAiService()
          .narrate(NarrationRequest(facts: empty))
          .toList();
      expect(events.whereType<NarrationFailed>(), isNotEmpty);
      expect(events.whereType<NarrationDone>(), isEmpty);
    });

    test('接线后：流式吐出 token，最终文本为拼接结果', () async {
      final backend = _FakeBackend(tokens: const ['这个月', '有八张', '照片。']);
      final service = OnDeviceAiService(
        wired: true,
        backend: backend,
        inspectOverride: (_) async => _readyStatus(),
      );

      final events = await service.narrate(NarrationRequest(facts: _facts())).toList();
      final tokens = events.whereType<NarrationToken>();
      final done = events.whereType<NarrationDone>().single;

      expect(tokens.length, 3);
      expect(done.fromFallback, isFalse);
      expect(done.text, '这个月有八张照片。');
      expect(backend.loaded, isTrue);
      expect(backend.disposed, isTrue);
      expect(backend.seenPrompt, contains('<|im_start|>assistant'));
    });

    test('模型加载失败时回落到规则版，不抛给 UI', () async {
      final service = OnDeviceAiService(
        wired: true,
        backend: _FakeBackend(failOnLoad: true),
        inspectOverride: (_) async => _readyStatus(),
      );

      final events = await service.narrate(NarrationRequest(facts: _facts())).toList();
      final done = events.whereType<NarrationDone>().single;
      expect(done.fromFallback, isTrue);
      expect(done.note, contains('模型加载失败'));
      expect(done.text, contains('8 张照片'));
    });

    test('生成中途失败也回落到规则版', () async {
      final service = OnDeviceAiService(
        wired: true,
        backend: _FakeBackend(throwMidStream: true),
        inspectOverride: (_) async => _readyStatus(),
      );

      final events = await service.narrate(NarrationRequest(facts: _facts())).toList();
      final done = events.whereType<NarrationDone>().single;
      expect(done.fromFallback, isTrue);
      expect(done.note, contains('生成中断'));
    });

    test('事实行不足时直接走规则版，即使设备与模型都可用', () async {
      const recap = MonthlyRecapService();
      final single = recap.collectFacts(
        [_photo(26, id: 's1')],
        year: 2026,
        month: 8,
      );
      final backend = _FakeBackend();
      final service = OnDeviceAiService(
        wired: true,
        backend: backend,
        inspectOverride: (_) async => _readyStatus(),
      );

      final events = await service.narrate(NarrationRequest(facts: single)).toList();
      final done = events.whereType<NarrationDone>().single;
      expect(done.fromFallback, isTrue);
      expect(done.note, contains('事实不足'));
      expect(backend.loaded, isFalse, reason: '门控命中时不应加载模型');
    });

    test('接线后生成上限为 150（验证结论：短输出无需更大窗口）', () async {
      final backend = _FakeBackend();
      final service = OnDeviceAiService(
        wired: true,
        backend: backend,
        inspectOverride: (_) async => _readyStatus(),
      );

      await service.narrate(NarrationRequest(facts: _facts())).toList();
      expect(backend.seenMaxTokens, kDefaultMaxTokens);
      expect(backend.seenMaxTokens, 150);
    });

    test('超时也回落到规则版', () async {
      final service = OnDeviceAiService(
        wired: true,
        backend: _HangingBackend(),
        timeout: const Duration(milliseconds: 80),
        inspectOverride: (_) async => _readyStatus(),
      );

      final events = await service.narrate(NarrationRequest(facts: _facts())).toList();
      final done = events.whereType<NarrationDone>().single;
      expect(done.fromFallback, isTrue);
    });
  });

  group('NarrationEvent 语义', () {
    test('Done 带兜底标记与备注字段', () {
      const event = NarrationDone('文案', fromFallback: true, note: '原因');
      expect(event.fromFallback, isTrue);
      expect(event.note, '原因');
    });

    test('Status / Token 可携带内容', () {
      expect(const NarrationStatus('加载中').message, '加载中');
      expect(const NarrationToken('字').token, '字');
    });
  });
}
