import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'on_device_ai_service.dart';

/// [LlamaBackend] 的真实实现：llama_cpp_dart 0.2.2（isolate 模式）。
///
/// 以下事项均经包源码（llama_cpp_dart-0.2.2）核实，README 有过时之处：
/// - `Llama.libraryPath` 在 Android 上默认是 `libmtmd.so`（多模态库），
///   本项目只编译了纯文本链路，必须在 [load] 里改成 `libllama.so`；
///   [LlamaParent.init] 会把该值传给子 isolate 打开动态库。
/// - 0.2.2 的 `LlamaLoad` **没有** format 参数；formatter 是
///   `LlamaParent` 的第二个位置参数。我们传入的提示词已经是
///   [PromptBundle.toChatMl] 拼装好的 ChatML 成品，所以**不传
///   formatter**，让它原样进模型；停止由 Qwen3 GGUF 自带的
///   `<|im_end|>` EOS 保证。
/// - `sendPrompt` 返回的是 **promptId**（不是正文）；正文 token 从
///   [LlamaParent.stream]（broadcast 流）收，结束信号用
///   [LlamaParent.waitForCompletion]。
/// - 生成上限在加载期通过 `ContextParams.nPredict` 生效，无法逐次请求
///   调整；[generate] 的 `maxTokens` 参数只为满足 [LlamaBackend] 契约，
///   实际生效值取 [LlamaCppBackend.maxTokens]。
class LlamaCppBackend implements LlamaBackend {
  LlamaCppBackend({
    this.maxTokens = kDefaultMaxTokens,
    this.contextSize = 1024,
    int? threads,
  }) : threads = threads ?? min(Platform.numberOfProcessors, 8);

  /// 生成的 token 上限（对应 llama.cpp 的 nPredict）。
  final int maxTokens;

  /// 上下文长度。提示词约 400~500 token + 150 生成，1024 够用；
  /// 1.7B 在 GQA 下 1024 的 KV cache 约 60MB，对 4GB 机更友好。
  final int contextSize;

  /// 推理线程数。默认取 CPU 核数、封顶 8（小核参与反而拖慢）。
  final int threads;

  LlamaParent? _parent;

  @override
  Future<void> load(String modelPath) async {
    // Android 默认找 libmtmd.so，纯文本链路必须覆盖。
    Llama.libraryPath = 'libllama.so';

    final contextParams = ContextParams()
      ..nCtx = contextSize
      ..nBatch = 256
      ..nUbatch = 256
      ..nThreads = threads
      ..nThreadsBatch = threads
      ..nPredict = maxTokens;

    // Qwen3 非思考模式的推荐采样参数。
    final sampling = SamplerParams()
      ..temp = 0.7
      ..topK = 20
      ..topP = 0.8
      ..penaltyRepeat = 1.05;

    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: ModelParams(),
      contextParams: contextParams,
      samplingParams: sampling,
      verbose: false,
    );

    final parent = LlamaParent(loadCommand);
    try {
      // init() 内部等待 ready：模型加载完成（或失败）才返回。
      await parent.init();
    } catch (_) {
      try {
        await parent.dispose();
      } catch (_) {}
      rethrow;
    }
    _parent = parent;
  }

  @override
  Stream<String> generate(String prompt, {int maxTokens = kDefaultMaxTokens}) {
    // maxTokens 的生效点在 load() 的 nPredict，见类文档。
    late final StreamController<String> controller;
    StreamSubscription<String>? sub;

    controller = StreamController<String>(
      onListen: () async {
        final parent = _parent;
        if (parent == null) {
          controller.addError(StateError('模型未加载，请先调用 load()'));
          await controller.close();
          return;
        }
        sub = parent.stream.listen(
          controller.add,
          onError: controller.addError,
          cancelOnError: true,
        );
        try {
          final promptId = await parent.sendPrompt(prompt);
          await parent.waitForCompletion(promptId);
        } catch (e) {
          controller.addError(e);
        } finally {
          await sub?.cancel();
          sub = null;
        }
        await controller.close();
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () async {
        await sub?.cancel();
        sub = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    final parent = _parent;
    _parent = null;
    if (parent == null) return;
    try {
      await parent.stop();
    } catch (_) {}
    await parent.dispose();
  }
}

/// POC 阶段的模型默认落位：
/// 优先应用专属外部目录（`adb push` 可直接写入），
/// 其次应用文档目录。
///
/// 推送命令（包名以实际构建为准）：
/// `adb push qwen3-1.7b-instruct-q4_k_m.gguf /sdcard/Android/data/com.example.shiguang/files/`
Future<String> defaultModelPath() async {
  final dir = await getExternalStorageDirectory();
  final base = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
  return '$base/$kDefaultModelFileName';
}
