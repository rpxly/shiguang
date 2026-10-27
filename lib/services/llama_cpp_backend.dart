import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'on_device_ai_service.dart';

/// 把进程的 native stderr（fd 2）重定向到文件。
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
    this.verbose = false,
  }) : threads = threads ?? min(Platform.numberOfProcessors, 8);

  /// 生成的 token 上限（对应 llama.cpp 的 nPredict）。
  final int maxTokens;

  /// 上下文长度。提示词约 400~500 token + 150 生成，1024 够用；
  /// 1.7B 在 GQA 下 1024 的 KV cache 约 60MB，对 4GB 机更友好。
  final int contextSize;

  /// 推理线程数。默认取 CPU 核数、封顶 8（小核参与反而拖慢）。
  final int threads;

  /// 打开 llama.cpp 自身日志。
  ///
  /// 包内默认会 `llama_log_set(null)` 把 native 日志全部静音，加载失败时
  /// 只剩一句「Could not load model at …」。POC 排障期开成 true，
  /// 日志会以 `llama native [level] …` 打到 logcat（tag: flutter）。
  final bool verbose;

  LlamaParent? _parent;

  @override
  Future<void> load(String modelPath) async {
    // Android 默认找 libmtmd.so，纯文本链路必须覆盖。
    Llama.libraryPath = 'libllama.so';

    // POC 排障：把 native stderr 落到文件，失败时能把真实报错带出来。
    final logPath = '${File(modelPath).parent.path}/llama_stderr.log';
    if (verbose) _redirectStderrTo(logPath);

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
      // 两个必须覆盖的默认值（2026-10-27 真机实测）：
      // - mainGpu 包内默认 0，但纯 CPU 构建下 llama.cpp 要求 -1，
      //   否则直接报 "invalid value for main_gpu: 0 (available devices: 0)" 并返回 null；
      // - nGpuLayers 包内默认 99，CPU-only 环境没有意义，显式 0 更省心。
      modelParams: ModelParams()
        ..mainGpu = -1
        ..nGpuLayers = 0,
      contextParams: contextParams,
      samplingParams: sampling,
      verbose: verbose,
    );

    final parent = LlamaParent(loadCommand);
    try {
      // init() 内部等待 ready：模型加载完成（或失败）才返回。
      await parent.init();
    } catch (_) {
      final native = _drainNativeLog(logPath);
      if (native.isNotEmpty) {
        print('=== llama native log ===\n$native\n=== end ===');
      }
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

/// 直连实现：**不用 isolate**，在当前 isolate 里直接调 `Llama`。
///
/// 用途有二：
/// 1. 排障对照——若它在真机能加载、而 isolate 版不能，问题就锁定在
///    llama_cpp_dart 的 isolate 通道上；
/// 2. 兜底实现——POC 场景一次生成 60~90 字，主 isolate 阻塞 5~20 秒
///    可接受，正式版再换回 isolate。
class LlamaDirectBackend implements LlamaBackend {
  LlamaDirectBackend({
    this.maxTokens = kDefaultMaxTokens,
    this.contextSize = 1024,
    int? threads,
    this.verbose = true,
  }) : threads = threads ?? min(Platform.numberOfProcessors, 8);

  final int maxTokens;
  final int contextSize;
  final int threads;
  final bool verbose;

  Llama? _llama;

  @override
  Future<void> load(String modelPath) async {
    Llama.libraryPath = 'libllama.so';
    final logPath = '${File(modelPath).parent.path}/llama_stderr.log';
    if (verbose) _redirectStderrTo(logPath);

    final contextParams = ContextParams()
      ..nCtx = contextSize
      ..nBatch = 256
      ..nUbatch = 256
      ..nThreads = threads
      ..nThreadsBatch = threads
      ..nPredict = maxTokens;

    final sampling = SamplerParams()
      ..temp = 0.7
      ..topK = 20
      ..topP = 0.8
      ..penaltyRepeat = 1.05;

    try {
      _llama = Llama(
        modelPath,
        // mainGpu 必须 -1：纯 CPU 构建下传 0 会被 llama.cpp 判为非法，
        // 直接返回 null（详见 LlamaCppBackend.load 的注释）。
        modelParams: ModelParams()
          ..mainGpu = -1
          ..nGpuLayers = 0,
        contextParams: contextParams,
        samplerParams: sampling,
        verbose: verbose,
      );
    } catch (e) {
      // 把 native 的真实报错带出来，否则只有一句 Could not load model。
      final native = _drainNativeLog(logPath);
      if (native.isNotEmpty) {
        print('=== llama native log ===\n$native\n=== end ===');
      }
      rethrow;
    }
  }

  @override
  Stream<String> generate(String prompt, {int maxTokens = kDefaultMaxTokens}) async* {
    final llama = _llama;
    if (llama == null) throw StateError('模型未加载，请先调用 load()');
    llama.setPrompt(prompt);
    while (true) {
      final (token, done) = llama.getNext();
      if (token.isNotEmpty) yield token;
      if (done) break;
    }
  }

  @override
  Future<void> dispose() async {
    final llama = _llama;
    _llama = null;
    llama?.dispose();
  }
}

/// 把进程的 native stderr（fd 2）重定向到文件。
///
/// 为什么不用日志回调：`NativeCallable.listener` 是异步投递，等 Dart 侧
/// 拿到回调时 ggml 的日志缓冲已经失效（实测只能解出乱码）。dup2 是
/// 同步的，llama.cpp 默认 logger 写 stderr 的每一行都会落盘。
void _redirectStderrTo(String path) {
  final libc = ffi.DynamicLibrary.process();
  final open = libc.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Int32, ffi.Int32),
      int Function(ffi.Pointer<Utf8>, int, int)>('open');
  final dup2 = libc.lookupFunction<ffi.Int32 Function(ffi.Int32, ffi.Int32),
      int Function(int, int)>('dup2');
  final pathPtr = path.toNativeUtf8();
  // O_WRONLY(1) | O_CREAT(0x40) | O_TRUNC(0x200)，权限 0666(0x1B6)
  final fd = open(pathPtr, 0x241, 0x1B6);
  malloc.free(pathPtr);
  if (fd < 0) return;
  dup2(fd, 2);
}

/// 读走并清空 native 日志文件，返回尾部 [maxLines] 行。
String _drainNativeLog(String path, {int maxLines = 40}) {
  try {
    final file = File(path);
    if (!file.existsSync()) return '';
    final lines = file.readAsLinesSync();
    file.writeAsStringSync('');
    final tail = lines.length > maxLines
        ? lines.sublist(lines.length - maxLines)
        : lines;
    return tail.join('\n');
  } catch (_) {
    return '';
  }
}

/// POC 阶段的模型默认落位：**应用内部目录**（`/data/user/0/<pkg>/app_flutter`）。
///
/// 2026-10-27 真机实测：模型放在 `/storage/emulated/0/Android/data/<pkg>/files`
/// 时，同样一份 `.so` 在应用内加载会卡死（同一模型用独立 probe 程序 5 秒内成功），
/// 换到应用内部目录后解决——外部目录走 FUSE，1GB 级 mmap 在应用进程里表现不稳定。
///
/// 推送方式（debug 包可直接 run-as）：
/// ```
/// adb push qwen3-1.7b-instruct-q4_k_m.gguf /data/local/tmp/
/// adb shell run-as com.example.shiguang cp \
///   /data/local/tmp/qwen3-1.7b-instruct-q4_k_m.gguf files/../app_flutter/
/// ```
Future<String> defaultModelPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$kDefaultModelFileName';
}
