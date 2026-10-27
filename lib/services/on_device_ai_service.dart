import 'dart:async';
import 'dart:io';

import 'monthly_recap_service.dart';

/// 端侧大模型叙事 —— **POC 骨架（尚未接线）**。
///
/// 现状（2026-10-27 核实）：接口、提示词、设备闸门、降级链路均已就绪，
/// 唯一缺的是 llama.cpp 的 native 库与它在 Dart 侧的那一层适配。
///
/// 这个开关保持 false 时，[OnDeviceAiService.narrate] 会**先给规则版结果**、
/// 再返回 AI 不可用的原因，因此整条 UI 链路现在就能做完并上线，
/// 不必等 NDK 与 1.1GB 模型下载到位。
///
/// 把 [kOnDeviceLlmWired] 改成 true 的唯一前提是：
/// 1. 装好 NDK 26.1 + CMake 3.22.1，按 ABI 编译出 `libllama.so` 并打进 jniLibs；
/// 2. `pubspec.yaml` 增加 `llama_cpp_dart: ^0.2.2`（Dart ≥3.2，兼容本项目 3.4.4）；
/// 3. 新建 `lib/services/llama_cpp_backend.dart`，用 `LlamaParent` +
///    `LlamaLoad(path: modelPath, format: ChatMLFormat())` 实现 [LlamaBackend]，
///    在 `load()` 里 `Llama.libraryPath = 'libllama.so'`；
/// 4. 在 [OnDeviceAiService] 的构造里注入这个实现。
///
/// 第 3 步的适配代码约 30 行，是这条路线里唯一需要 NDK 的部分。
const bool kOnDeviceLlmWired = false;

/// 模型文件名。换成 Qwen2.5-1.5B-Instruct 时同步改这里。
const String kDefaultModelFileName = 'qwen3-1.7b-instruct-q4_k_m.gguf';

/// 1.7B Q4_K_M 的典型体积，用于「文件是否下完」的判断。
const int kExpectedModelBytes = 1100 * 1024 * 1024;

/// 低于这个总内存不跑 1.5B 以上模型（1.1~1.4GB 常驻会触发 LMK）。
const int kMinTotalRamMb = 4096;

/// 低于这么多可用内存就先不加载模型。
const int kMinFreeRamMb = 1500;

/// 事实行数低于该值时不交给模型，直接走规则版。
///
/// 离线验证（2026-10-27）实测规律：提示词事实行 ≥4 时模型严格守规矩；
/// <4 时会用想象补画面（编造「阳光透过云层」「清晨的草地」，后者与
/// 「21 点拍摄」自相矛盾）。规则版在零线索场景下的输出是诚实且可接受的，
/// 两者正好互补。
const int kMinFactRows = 4;

/// 默认生成上限。
const int kDefaultMaxTokens = 150;

/// 设备画像：只用 dart:io 读，不引入任何插件。
class DeviceProfile {
  final String os;
  final String abi;
  final int totalRamMb;
  final int freeRamMb;

  const DeviceProfile({
    required this.os,
    required this.abi,
    required this.totalRamMb,
    required this.freeRamMb,
  });

  bool get isAndroid => os.toLowerCase().contains('android');

  /// arm64 是 `llama_flutter_android` 与常见 llama.cpp 预编译包的唯一 ABI。
  bool get isArm64 => abi.toLowerCase().contains('arm64') ||
      abi.toLowerCase().contains('aarch64');

  /// 内存是否够跑 1.7B Q4。
  bool get passesMemoryGate =>
      totalRamMb >= kMinTotalRamMb && freeRamMb >= kMinFreeRamMb;

  /// 读取设备画像。
  ///
  /// Android 上 `/proc/meminfo` 可读，桌面端读不到时退化为 0（不阻断桌面调试）。
  static Future<DeviceProfile> read() async {
    var total = 0;
    var free = 0;
    try {
      final info = await File('/proc/meminfo').readAsString();
      total = _meminfoToMb(info, 'MemTotal');
      free = _meminfoToMb(info, 'MemAvailable');
    } catch (_) {
      // 非 Android / 无权限：保持 0，由调用方按「无法判断」处理
    }
    return DeviceProfile(
      os: Platform.operatingSystem,
      abi: _abiOf(Platform.version),
      totalRamMb: total,
      freeRamMb: free,
    );
  }

  static int _meminfoToMb(String content, String key) {
    for (final line in content.split('\n')) {
      if (!line.startsWith('$key:')) continue;
      final kb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return kb ~/ 1024;
    }
    return 0;
  }

  static String _abiOf(String version) {
    final lower = version.toLowerCase();
    if (lower.contains('arm64') || lower.contains('aarch64')) return 'arm64-v8a';
    if (lower.contains('arm')) return 'armeabi-v7a';
    if (lower.contains('x64')) return 'x86_64';
    return version;
  }

  @override
  String toString() =>
      '$os / $abi / ${totalRamMb}MB 总内存 / ${freeRamMb}MB 可用';
}

/// 端侧 AI 当前能不能用，以及为什么不能用。
class DeviceAiStatus {
  final bool canRun;
  final String reason;
  final DeviceProfile profile;
  final String modelPath;
  final int modelBytes;

  const DeviceAiStatus({
    required this.canRun,
    required this.reason,
    required this.profile,
    required this.modelPath,
    required this.modelBytes,
  });

  bool get modelReady => modelBytes >= kExpectedModelBytes * 0.95;

  double get modelProgress =>
      (modelBytes / kExpectedModelBytes).clamp(0.0, 1.0).toDouble();

  @override
  String toString() =>
      'canRun=$canRun reason=$reason\n${profile.toString()}\n模型：$modelPath ($modelBytes B)';
}

/// 一次叙事请求的输入：事实 + 用户手填的元数据。
class NarrationRequest {
  final MonthlyFacts facts;
  final String? mood;
  final String? weather;
  final int steps;

  const NarrationRequest({
    required this.facts,
    this.mood,
    this.weather,
    this.steps = 0,
  });
}

/// 提示词包：分开存 system / user，便于换模型时只改一层。
class PromptBundle {
  final String system;
  final String user;

  const PromptBundle({required this.system, required this.user});

  /// ChatML 拼装（Qwen 系列用 ChatML）。
  String toChatMl() => '<|im_start|>system\n$system<|im_end|>\n'
      '<|im_start|>user\n$user<|im_end|>\n'
      '<|im_start|>assistant\n';

  @override
  String toString() => toChatMl();
}

/// 提示词构造。纯函数，可离线校验：把 [PromptBundle.toChatMl] 的输出
/// 粘到桌面版 llama.cpp 里，就能在**不装 NDK、不买设备**的前提下
/// 先判断 1.7B 的中文叙事质量够不够用。
class RecapPromptBuilder {
  const RecapPromptBuilder();

  static const String _system = '你是一个帮用户写"月度照片回顾"的中文写作助手。'
      '你只能使用用户给出的事实，绝不补充事实里没有的地点、人物、天气或事件。'
      '你不写标题、不分点、不加引号、不写结尾祝福语。';

  /// 事实行数。低于 [kMinFactRows] 时调用方应直接走规则版。
  ///
  /// 离线验证的幻觉规律：事实越薄，模型越倾向用想象补画面。
  int factRowCount(NarrationRequest request) => _factLines(request).length;

  List<String> _factLines(NarrationRequest request) {
    final facts = request.facts;
    final lines = <String>[
      '月份：${facts.year} 年 ${facts.month} 月',
      '照片：${facts.photoCount} 张，分布在 ${facts.activeDays} 天',
    ];

    if (facts.topScenes.isNotEmpty) {
      final scenes = facts.topScenes
          .take(2)
          .map((s) => '$s ${facts.sceneCounts[s]} 张')
          .join('、');
      lines.add('场景：$scenes');
    }
    if (facts.topPlaces.isNotEmpty) {
      lines.add('地点：${facts.topPlaces.take(2).join('、')}');
    }
    if (facts.faceCount > 0) {
      lines.add('有人出镜：${facts.faceCount} 张');
    }
    if (facts.favoriteCount > 0) {
      lines.add('精选：${facts.favoriteCount} 张');
    }
    if (facts.nightCount > 0) {
      lines.add('夜间拍摄：${facts.nightCount} 张');
    }
    if (facts.busiestDay != null && facts.busiestDayCount > 1) {
      lines.add('拍得最多的一天：${facts.busiestDay} 号，${facts.busiestDayCount} 张');
    }
    if (request.mood != null && request.mood!.trim().isNotEmpty) {
      lines.add('用户填写的心情：${request.mood!.trim()}');
    }
    if (request.weather != null && request.weather!.trim().isNotEmpty) {
      lines.add('用户填写的天气：${request.weather!.trim()}');
    }
    if (request.steps > 0) {
      lines.add('当月步数：${request.steps}');
    }
    return lines;
  }

  PromptBundle build(NarrationRequest request) {
    final lines = _factLines(request);

    final user = StringBuffer()
      ..writeln('下面是这个月的真实情况：')
      ..writeln(lines.map((l) => '- $l').join('\n'))
      ..writeln()
      ..writeln('请写 3 句中文，连贯成一段，总长 60~90 字。')
      ..writeln('要求：')
      ..writeln('1. 只用上面列出的事实，不新增任何细节；')
      ..writeln('2. 第一句说数量和分布，第二句说画面内容，第三句收尾；')
      ..writeln('3. 语气克制具体，禁止「时光荏苒」「岁月如歌」这类套话；')
      ..writeln('4. 不要出现"照片"以外的名词猜测。')
      // Qwen3 的思考软开关：必须放在 user 消息末尾。2026-10-27 离线验证实测，
      // 不关 thinking 时 220 个 token 全部耗在 <think> 内部，正文零输出。
      ..write('直接输出正文。/no_think');

    return PromptBundle(system: _system, user: user.toString());
  }
}

/// 叙事过程事件：状态提示 / 增量 token / 结束 / 失败。
sealed class NarrationEvent {
  const NarrationEvent();
}

/// 进度提示，例如「正在加载模型」「正在生成」。
class NarrationStatus extends NarrationEvent {
  final String message;
  const NarrationStatus(this.message);
}

/// 增量文本（流式打字）。
class NarrationToken extends NarrationEvent {
  final String token;
  const NarrationToken(this.token);
}

/// 结束，带完整文本。
///
/// [fromFallback] 为 true 表示这段文本来自规则版而不是模型；
/// [note] 说明为什么走了兜底，UI 可以直接显示成一行灰字。
class NarrationDone extends NarrationEvent {
  final String text;
  final bool fromFallback;
  final String? note;
  const NarrationDone(this.text, {this.fromFallback = false, this.note});
}

/// 失败，带可读原因（用于 UI 提示与埋点）。
class NarrationFailed extends NarrationEvent {
  final String reason;
  const NarrationFailed(this.reason);
}

/// native 推理层的最小接口。
///
/// 真实实现放在 `llama_cpp_backend.dart`，本文件不 import 任何推理插件，
/// 这样在 NDK 就位前 `flutter analyze` / `flutter build` 全绿。
abstract class LlamaBackend {
  Future<void> load(String modelPath);

  Stream<String> generate(String prompt, {int maxTokens});

  Future<void> dispose();
}

/// 未接线时的占位实现：一调用就抛，且不产生任何副作用。
class NotWiredLlamaBackend implements LlamaBackend {
  const NotWiredLlamaBackend();

  @override
  Future<void> load(String modelPath) async {
    throw StateError('端侧推理未接线：缺少 libllama.so 与 llama_cpp_dart 适配层');
  }

  @override
  Stream<String> generate(String prompt, {int maxTokens = 256}) {
    return Stream<String>.error(
      StateError('端侧推理未接线：缺少 libllama.so 与 llama_cpp_dart 适配层'),
    );
  }

  @override
  Future<void> dispose() async {}
}

/// 端侧 AI 叙事的对外门面。
///
/// 设计要点：**永不空手而归**。任何一步（未接线 / 内存不足 / 模型缺失 /
/// 生成超时）失败时，都先把规则版摘要吐出去，再报失败原因。
/// 这样 UI 不需要写两套：先看到规则版，AI 版本到了替上或留在原地。
class OnDeviceAiService {
  final String? modelPath;
  final LlamaBackend backend;
  final RecapPromptBuilder promptBuilder;
  final MonthlyRecapService recapService;

  /// 是否已接线。默认取编译期开关 [kOnDeviceLlmWired]；
  /// 单测与 POC 调试可以显式传 true 来验证「接线后」的完整链路。
  final bool wired;

  /// 生成上限。离线验证（2026-10-27）实测 60~90 字 ≈ 60~90 token，
  /// 150 已留一倍余量——上限越大，未关思考时浪费越多。
  final int maxTokens;

  /// 生成总超时。中低端机 1.7B 实测 3~8 tok/s，超时按 90 秒兜底。
  final Duration timeout;

  /// 旁路：注入后 [inspect] 不再走真实检测。
  ///
  /// 只用于单测与 POC 页调试「接线后」的完整链路——真实安装包不应传这个参数，
  /// 否则会把「模型没下载」误判成可用。
  final Future<DeviceAiStatus> Function(String modelPath)? inspectOverride;

  const OnDeviceAiService({
    this.modelPath,
    this.backend = const NotWiredLlamaBackend(),
    this.promptBuilder = const RecapPromptBuilder(),
    this.recapService = const MonthlyRecapService(),
    this.wired = kOnDeviceLlmWired,
    this.maxTokens = kDefaultMaxTokens,
    this.timeout = const Duration(seconds: 90),
    this.inspectOverride,
  });

  /// 检查可用性。UI 用它决定是否显示「AI 叙事」入口。
  Future<DeviceAiStatus> inspect() async {
    final override = inspectOverride;
    if (override != null) return override(modelPath ?? '');
    final profile = await DeviceProfile.read();
    final path = modelPath ?? '';
    var bytes = 0;
    if (path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) bytes = await file.length();
      } catch (_) {}
    }

    String? reason;
    if (!wired) {
      reason = '端侧推理未接线（Phase 0 待启动）';
    } else if (!profile.isAndroid) {
      reason = '仅 Android 走端侧推理';
    } else if (!profile.isArm64) {
      reason = '仅支持 arm64-v8a 设备';
    } else if (profile.totalRamMb > 0 && profile.totalRamMb < kMinTotalRamMb) {
      reason = '内存不足（需 ${kMinTotalRamMb}MB 以上，当前 ${profile.totalRamMb}MB）';
    } else if (path.isEmpty || bytes < kExpectedModelBytes * 0.95) {
      reason = '模型未下载或未下完（${(bytes / 1024 / 1024).toStringAsFixed(0)}MB）';
    } else if (profile.freeRamMb > 0 && profile.freeRamMb < kMinFreeRamMb) {
      reason = '可用内存偏低（${profile.freeRamMb}MB），稍后再试';
    }

    return DeviceAiStatus(
      canRun: reason == null,
      reason: reason ?? '可用',
      profile: profile,
      modelPath: path,
      modelBytes: bytes,
    );
  }

  /// 生成月度叙事。规则版永远先到，AI 版本到了再补一次 [NarrationDone]。
  Stream<NarrationEvent> narrate(NarrationRequest request) async* {
    final recap = recapService.build(
      request.facts,
      mood: request.mood,
      weather: request.weather,
      steps: request.steps,
    );

    // 门控一：事实行不足时不交给模型（离线验证实测：模型会用想象补画面）。
    // 这条门控优先级最高——即使模型可用、内存充足也走规则版。
    final factRows = promptBuilder.factRowCount(request);
    if (factRows < kMinFactRows) {
      if (recap == null) {
        yield const NarrationFailed('本月还没有可用于生成的照片');
        return;
      }
      yield const NarrationStatus('照片内容线索太少，先用规则版');
      yield NarrationDone(
        recap.text,
        fromFallback: true,
        note: '事实不足（$factRows 行 < $kMinFactRows 行），未调用模型',
      );
      return;
    }

    final status = await inspect();
    if (!status.canRun) {
      // 先把可用的兜底交出去，再说明为什么没走 AI。
      if (recap == null) {
        yield const NarrationFailed('本月还没有可用于生成的照片');
        return;
      }
      yield const NarrationStatus('先用规则版');
      yield NarrationDone(recap.text, fromFallback: true, note: status.reason);
      return;
    }

    final prompt = promptBuilder.build(request);
    yield const NarrationStatus('正在加载模型…');

    try {
      await backend.load(status.modelPath);
    } catch (e) {
      if (recap != null) {
        yield NarrationDone(
          recap.text,
          fromFallback: true,
          note: '模型加载失败，已用规则版：$e',
        );
      } else {
        yield NarrationFailed('模型加载失败：$e');
      }
      return;
    }

    yield const NarrationStatus('正在生成…');
    final buffer = StringBuffer();
    try {
      await for (final token
          in backend.generate(prompt.toChatMl(), maxTokens: maxTokens).timeout(timeout)) {
        buffer.write(token);
        yield NarrationToken(token);
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) {
        if (recap != null) {
          yield NarrationDone(recap.text, fromFallback: true, note: '模型返回空文本');
        } else {
          yield const NarrationFailed('模型返回空文本');
        }
        return;
      }
      yield NarrationDone(text);
    } catch (e) {
      if (recap != null) {
        yield NarrationDone(recap.text, fromFallback: true, note: '生成中断，已用规则版：$e');
      } else {
        yield NarrationFailed('生成失败：$e');
      }
    } finally {
      try {
        await backend.dispose();
      } catch (_) {}
    }
  }
}
