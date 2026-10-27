import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_background.dart';
import '../components/glass_card.dart';
import '../components/nav_header.dart';
import '../repository/local_repository.dart';
import '../services/monthly_recap_service.dart';
import '../services/llama_cpp_backend.dart';
import '../services/on_device_ai_service.dart';
import '../services/scene_classifier_service.dart';
import '../theme.dart';

/// 端侧 AI 诊断页（POC 用，随 debug 包一起发）。
///
/// 这一页解决两个现实问题：
/// 1. **不用装 NDK 也能先验证提示词质量** —— 「复制提示词」把它粘到桌面版
///    llama.cpp，就能用同一份 GGUF 模型看中文产出够不够用；
/// 2. **接线后只需在这一页看结果** —— 设备闸门、模型进度、流式 token、
///    兜底原因全部显示在同一屏，避免在月刊页反复点。
class OnDeviceAiPage extends StatefulWidget {
  final LocalRepository repository;
  final VoidCallback onBack;

  const OnDeviceAiPage({super.key, required this.repository, required this.onBack});

  @override
  State<OnDeviceAiPage> createState() => _OnDeviceAiPageState();
}

class _OnDeviceAiPageState extends State<OnDeviceAiPage> {
  static const MonthlyRecapService _recapService = MonthlyRecapService();

  /// 已接线的服务：模型路径异步解析（应用专属外部目录优先），
  /// 后端为 llama_cpp_dart 0.2.2 的真实实现。解析完成前保持 null。
  OnDeviceAiService? _aiService;
  String? _modelPathError;

  /// POC 测速旁路：绕过内存闸门，覆盖 3.7GB 低配机（仅本诊断页可用）。
  bool _bypassGate = false;

  DeviceAiStatus? _status;
  PromptBundle? _prompt;
  bool _inspecting = true;
  bool _running = false;

  String _output = '';
  final List<String> _notes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// 先解析模型路径、装好已接线的服务，再做首次检测。
  Future<void> _bootstrap() async {
    try {
      final modelPath = await defaultModelPath();
      if (!mounted) return;
      setState(() {
        _aiService = _buildService(modelPath);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelPathError = '模型路径解析失败：$e');
    }
    _inspect();
  }

  OnDeviceAiService _buildService(String modelPath) => OnDeviceAiService(
        modelPath: modelPath,
        // isolate 模式：模型加载与推理都在子 isolate，不卡 UI。
        // 需要看 llama.cpp native 日志时把 verbose 改成 true（会写
        // app_flutter/llama_stderr.log）。
        backend: LlamaCppBackend(maxTokens: kDefaultMaxTokens),
        bypassMemoryGate: _bypassGate,
      );

  /// 切换内存闸门旁路后重建服务并重新检测。
  Future<void> _toggleBypass(bool value) async {
    if (_bypassGate == value) return;
    setState(() {
      _bypassGate = value;
      final path = _status?.modelPath;
      if (path != null && path.isNotEmpty) {
        _aiService = _buildService(path);
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _inspect();
  }

  Future<void> _inspect() async {
    final service = _aiService;
    if (service == null) return; // 等待 _bootstrap 完成，保持「检测中」
    setState(() => _inspecting = true);
    final status = await service.inspect();
    if (!mounted) return;
    setState(() {
      _status = status;
      _inspecting = false;
    });
  }

  /// 取本月照片并聚合成事实。
  MonthlyFacts _monthFacts() {
    final now = DateTime.now();
    final photos = widget.repository
        .getAllPhotos()
        .where((p) => p.dateTime.year == now.year && p.dateTime.month == now.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return _recapService.collectFacts(
      photos,
      year: now.year,
      month: now.month,
      sceneOf: SceneClassifier.instance.labelFor,
      placeOf: SceneClassifier.readablePlace,
    );
  }

  NarrationRequest _request() {
    final facts = _monthFacts();
    final meta = widget.repository.getMagazineMeta(facts.year, facts.month);
    return NarrationRequest(
      facts: facts,
      mood: meta?['mood'] as String?,
      weather: meta?['weather'] as String?,
      steps: (meta?['healthSteps'] as int?) ?? 0,
    );
  }

  Future<void> _run() async {
    final service = _aiService;
    if (service == null) {
      setState(() => _notes.add('服务初始化中，请稍候'));
      return;
    }
    final request = _request();
    if (request.facts.isEmpty) {
      setState(() => _notes.add('本月没有照片，先扫描相册'));
      return;
    }
    setState(() {
      _running = true;
      _output = '';
      _notes.clear();
    });

    await for (final event in service.narrate(request)) {
      if (!mounted) return;
      switch (event) {
        case NarrationStatus(:final message):
          setState(() => _notes.add(message));
        case NarrationToken(:final token):
          setState(() => _output += token);
        case NarrationDone(:final text, :final fromFallback, :final note):
          setState(() {
            _output = text;
            if (fromFallback) _notes.add('来自规则版');
            if (note != null) _notes.add(note);
          });
        case NarrationFailed(:final reason):
          setState(() => _notes.add('失败：$reason'));
      }
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _showPrompt() async {
    final request = _request();
    if (request.facts.isEmpty) {
      setState(() => _notes.add('本月没有照片，提示词为空'));
      return;
    }
    final prompt = const RecapPromptBuilder().build(request);
    setState(() => _prompt = prompt);
  }

  Future<void> _copyPrompt() async {
    final prompt = _prompt ?? const RecapPromptBuilder().build(_request());
    await Clipboard.setData(ClipboardData(text: prompt.toChatMl()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('提示词已复制，可直接粘到桌面版 llama.cpp')));
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            NavHeader(title: '端侧 AI 诊断', subtitle: 'Phase 0 · POC', onBack: widget.onBack),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacings.lg,
                AppSpacings.lg,
                AppSpacings.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(context),
                  16.hGap,
                  _buildWiringCard(context),
                  16.hGap,
                  _buildTrialCard(context),
                  16.hGap,
                  _buildPromptCard(context),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status = _status;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, '设备与模型'),
          if (_inspecting)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('检测中…', style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textTertiary(context))),
            )
          else if (status != null) ...[
            _kv(context, '系统', '${status.profile.os} / ${status.profile.abi}'),
            _kv(context, '内存', '${status.profile.totalRamMb}MB 总 / ${status.profile.freeRamMb}MB 可用'),
            _kv(context, '模型文件', status.modelPath.isEmpty ? '未配置' : status.modelPath),
            _kv(
              context,
              '模型体积',
              '${(status.modelBytes / 1024 / 1024).toStringAsFixed(0)}MB'
              ' / 期望 ${(kExpectedModelBytes / 1024 / 1024).toStringAsFixed(0)}MB',
            ),
            12.hGap,
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: LinearProgressIndicator(
                value: status.modelProgress,
                minHeight: 4,
                backgroundColor: AppColors.divider(context),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent(context)),
              ),
            ),
            12.hGap,
            Row(
              children: [
                Icon(
                  status.canRun ? Icons.check_circle_outline : Icons.info_outline,
                  size: 16,
                  color: status.canRun ? AppColors.success : AppColors.textTertiary(context),
                ),
                6.wGap,
                Expanded(
                  child: Text(
                    status.canRun ? '可跑端侧模型' : status.reason,
                    style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textSecondary(context)),
                  ),
                ),
                GestureDetector(
                  onTap: _inspect,
                  behavior: HitTestBehavior.opaque,
                  child: Text('重新检测',
                      style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.accent(context))),
                ),
              ],
            ),
            8.hGap,
            // POC 测速旁路：#10 需要在 3.7GB 低配机上拿到真实速度/内存数据，
            // 但产品闸门不变，正式链路永远走默认（false）。
            Row(
              children: [
                Expanded(
                  child: Text(
                    '低配实测（绕过内存闸门）',
                    style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context)),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: _bypassGate,
                    onChanged: _toggleBypass,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWiringCard(BuildContext context) {
    final steps = <String>[
      'NDK 26.1 + CMake 3.22.1 就绪',
      'libllama.so（llama.cpp 4ffc47c，16KB 对齐）已打入 jniLibs',
      'llama_cpp_dart 0.2.2（meta/ffi 依赖已 override 兼容）',
      'llama_cpp_backend.dart 已实现 LlamaBackend',
      'kOnDeviceLlmWired = true，后端已注入本页',
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, '接线状态'),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              kOnDeviceLlmWired ? '当前：已接线' : '当前：未接线（所有请求自动走规则版）',
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                color: kOnDeviceLlmWired ? AppColors.success : AppColors.textTertiary(context),
              ),
            ),
          ),
          10.hGap,
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✓ ',
                        style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.success)),
                    Expanded(
                      child: Text(s,
                          style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textSecondary(context))),
                    ),
                  ],
                ),
              )),
          if (_modelPathError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('· $_modelPathError',
                  style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.error)),
            ),
        ],
      ),
    );
  }

  Widget _buildTrialCard(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, '试跑'),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  label: _running ? '生成中…' : '生成本月摘要',
                  icon: Icons.auto_awesome,
                  onTap: _running ? null : _run,
                ),
              ),
              10.wGap,
              Expanded(
                child: _actionButton(
                  context,
                  label: '刷新状态',
                  icon: Icons.refresh,
                  onTap: _inspecting ? null : _inspect,
                ),
              ),
            ],
          ),
          if (_output.isNotEmpty) ...[
            12.hGap,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlassColors.surface(context),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: SelectableText(
                _output,
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  height: 1.7,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
          if (_notes.isNotEmpty) ...[
            10.hGap,
            ..._notes.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $n',
                      style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptCard(BuildContext context) {
    final prompt = _prompt;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, '发给模型的提示词'),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '复制后粘到桌面版 llama.cpp，可在不装 NDK 的情况下先验证 1.7B 的中文产出。',
              style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context), height: 1.5),
            ),
          ),
          10.hGap,
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  label: prompt == null ? '预览提示词' : '收起',
                  icon: Icons.visibility_outlined,
                  onTap: prompt == null ? _showPrompt : () => setState(() => _prompt = null),
                ),
              ),
              10.wGap,
              Expanded(
                child: _actionButton(
                  context,
                  label: '复制提示词',
                  icon: Icons.copy_all_outlined,
                  onTap: _copyPrompt,
                ),
              ),
            ],
          ),
          if (prompt != null && prompt.user.isNotEmpty) ...[
            12.hGap,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlassColors.surface(context),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: SelectableText(
                prompt.user,
                style: TextStyle(
                  fontSize: AppFontSizes.xs,
                  height: 1.7,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GlassColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: GlassColors.borderSubtle(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: enabled ? AppColors.accent(context) : AppColors.textTertiary(context)),
            6.wGap,
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                fontWeight: AppFontWeights.medium,
                color: enabled ? AppColors.textPrimary(context) : AppColors.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppFontSizes.base,
        fontWeight: AppFontWeights.medium,
        color: AppColors.textPrimary(context),
      ),
    );
  }

  Widget _kv(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(key, style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textSecondary(context))),
          ),
        ],
      ),
    );
  }
}
