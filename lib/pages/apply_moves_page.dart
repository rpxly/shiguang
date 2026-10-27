import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_card.dart';
import '../components/nav_header.dart';
import '../repository/local_repository.dart';
import '../services/album_archive_service.dart';
import '../services/analytics_service.dart';
import '../theme.dart';
import '../components/app_background.dart';

/// 「写入系统相册」的确认 / 进度 / 结果页。
///
/// 设计原则：
/// - 移动只改目录，不复制、不占额外空间 —— 必须在确认页讲清楚
/// - 一次授权打包成一批，避免每张都弹窗
/// - 结果页给「撤销这次整理」，回滚到**原始目录**
class ApplyMovesPage extends StatefulWidget {
  final LocalRepository repository;
  final AlbumArchiveService archiveService;
  final VoidCallback onBack;

  const ApplyMovesPage({
    super.key,
    required this.repository,
    required this.archiveService,
    required this.onBack,
  });

  @override
  State<ApplyMovesPage> createState() => _ApplyMovesPageState();
}

enum _Phase { confirm, running, done }

class _ApplyMovesPageState extends State<ApplyMovesPage> {
  _Phase _phase = _Phase.confirm;
  ArchiveProgress? _progress;
  ArchiveOutcome? _outcome;
  String? _error;
  bool _rollingBack = false;

  /// 相簿 id → 待应用张数
  late final Map<String, int> _pending;
  late final Map<String, String> _names;

  @override
  void initState() {
    super.initState();
    _pending = {
      for (final entry in widget.repository.getPendingMoves().entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.length,
    };
    _names = {
      for (final album in widget.repository.getAllAlbums()) album.id: album.name,
    };
  }

  int get _total => _pending.values.fold(0, (sum, count) => sum + count);

  Future<void> _apply() async {
    setState(() {
      _phase = _Phase.running;
      _error = null;
    });
    try {
      final outcome = await widget.archiveService.applyPending(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _phase = _Phase.done;
      });
      // 埋点：真正的「整理完成」= 有照片被移动落盘。
      // alreadyThere/blocked/failed 都算没整理成，不算进漏斗分母。
      if (outcome.moved > 0) {
        AnalyticsService.instance.log(
          AnalyticsEvent.organizeCompleted,
          props: {'moves': outcome.moved, 'failed': outcome.failed},
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _phase = _Phase.done;
      });
    }
  }

  Future<void> _rollback() async {
    setState(() => _rollingBack = true);
    try {
      final outcome = await widget.archiveService.rollbackLatest();
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _rollingBack = false;
        _phase = _Phase.done;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已还原 ${outcome.moved} 张到原目录'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rollingBack = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Column(
        children: [
          NavHeader(
            title: _phase == _Phase.confirm ? '写入系统相册' : '整理结果',
            onBack: () {
              if (_phase == _Phase.running) return;
              widget.onBack();
            },
            leading: _phase == _Phase.running
                ? const SizedBox(width: 40)
                : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  switch (_phase) {
                    _Phase.confirm => _buildConfirm(context),
                    _Phase.running => _buildRunning(context),
                    _Phase.done => _buildDone(context),
                  },
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 40,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        8.hGap,
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_total 张照片将被归档',
                style: TextStyle(
                  fontSize: AppFontSizes.lg,
                  fontWeight: AppFontWeights.medium,
                  color: context.textPrimary,
                ),
              ),
              6.hGap,
              Text(
                '移动到 Pictures/拾光/ 下按相簿分目录。'
                '只改目录、不复制文件，占用空间不变；原目录里将不再保留这些照片。',
                style: TextStyle(
                  fontSize: AppFontSizes.xs,
                  color: context.textTertiary,
                  height: AppLineHeights.relaxed,
                ),
              ),
              6.hGap,
              Text(
                '系统可能会询问一次「允许拾光修改这些照片」，这是改目录所必需，请选择允许。',
                style: TextStyle(
                  fontSize: AppFontSizes.xs,
                  color: context.textTertiary,
                  height: AppLineHeights.relaxed,
                ),
              ),
            ],
          ),
        ),
        16.hGap,
        ..._pending.entries.map((entry) {
          final name = _names[entry.key] ?? '未知相簿';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacings.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: GlassColors.bg(context),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: GlassColors.borderSubtle(context)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 18, color: context.accent),
                10.wGap,
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSizes.sm,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${entry.value} 张',
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }),
        24.hGap,
        AppButton.primary(
          icon: Icons.drive_file_move_outline,
          label: '开始整理',
          onPressed: _apply,
        ),
        8.hGap,
        AppButton.secondary(
          label: '取消',
          onPressed: widget.onBack,
        ),
      ],
    );
  }

  Widget _buildRunning(BuildContext context) {
    final p = _progress;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: p?.ratio,
              strokeWidth: 3,
              color: context.accent,
              backgroundColor: context.surface,
            ),
          ),
          24.hGap,
          Text(
            p == null ? '正在准备…' : '${p.done} / ${p.total}',
            style: TextStyle(
              fontSize: AppFontSizes.base,
              color: context.textPrimary,
              fontWeight: AppFontWeights.medium,
            ),
          ),
          8.hGap,
          Text(
            p == null ? '' : '正在写入「${p.albumName}」',
            style: TextStyle(
              fontSize: AppFontSizes.xs,
              color: context.textTertiary,
            ),
          ),
          20.hGap,
          Text(
            '请不要离开此页面',
            style: TextStyle(
              fontSize: AppFontSizes.xs,
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final outcome = _outcome;
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          20.hGap,
          Icon(Icons.error_outline, size: 40, color: context.error),
          12.hGap,
          Text(
            '整理未完成',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: AppFontWeights.medium,
              color: context.textPrimary,
            ),
          ),
          8.hGap,
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
          ),
          24.hGap,
          AppButton.secondary(label: '返回', onPressed: widget.onBack),
        ],
      );
    }
    if (outcome == null) return const SizedBox.shrink();

    final failures = outcome.failures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        16.hGap,
        Icon(Icons.check_circle_outline, size: 44, color: context.success),
        12.hGap,
        Text(
          outcome.summary,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppFontSizes.lg,
            fontWeight: AppFontWeights.medium,
            color: context.textPrimary,
          ),
        ),
        6.hGap,
        Text(
          '耗时 ${(outcome.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒'
          '${failures.isEmpty ? '' : ' · ${failures.length} 张未完成'}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
        ),
        if (failures.isNotEmpty) ...[
          20.hGap,
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '未完成的照片',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: AppFontWeights.medium,
                    color: context.textPrimary,
                  ),
                ),
                6.hGap,
                Text(
                  '这些照片仍留在原处，可稍后重试。微信 / QQ 等聊天目录默认不移动。',
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: context.textTertiary,
                    height: AppLineHeights.relaxed,
                  ),
                ),
                10.hGap,
                ...failures.take(5).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '· ${f.error ?? '未知原因'}',
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          color: context.textSecondary,
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
        24.hGap,
        AppButton.primary(label: '完成', onPressed: widget.onBack),
        if (outcome.moved > 0) ...[
          8.hGap,
          AppButton.ghost(
            icon: Icons.undo,
            label: _rollingBack ? '正在还原…' : '撤销这次整理',
            onPressed: _rollingBack ? null : _rollback,
          ),
        ],
      ],
    );
  }
}
