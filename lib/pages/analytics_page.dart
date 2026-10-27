import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_background.dart';
import '../components/glass_card.dart';
import '../components/nav_header.dart';
import '../services/analytics_service.dart';
import '../theme.dart';

/// 「使用数据」调试页：把本地埋点攒出来的漏斗摆在屏幕上。
///
/// 只做一件事——让「62% 进入 / 41% 生成」这类数字有真实来源可查。
/// 数据全程在本机 `analytics/events.jsonl`，不联网、不上传。
class AnalyticsPage extends StatefulWidget {
  final VoidCallback onBack;

  const AnalyticsPage({super.key, required this.onBack});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = true;
  FunnelReport? _report;
  int _windowDays = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final service = AnalyticsService.instance;
    await service.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _report = service.funnel(days: _windowDays);
      _loading = false;
    });
  }

  Future<void> _copy() async {
    final data = AnalyticsService.instance.dumpJsonl();
    if (data.isEmpty) {
      _snack('还没有任何事件');
      return;
    }
    await Clipboard.setData(ClipboardData(text: data));
    if (mounted) _snack('已复制 ${data.split('\n').length} 条原始事件');
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空埋点？'),
        content: const Text('本地记录会被删除，已采集的基线无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('清空')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AnalyticsService.instance.reset();
    await _load();
    if (mounted) _snack('已清空');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return GlassScaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            NavHeader(title: '使用数据', subtitle: '本地埋点 · 只落盘不联网', onBack: widget.onBack),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacings.lg, AppSpacings.lg, AppSpacings.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    GlassCard(child: Text('读取中…', style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textTertiary(context))))
                  else if (report == null)
                    GlassCard(child: Text('暂无数据', style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textTertiary(context))))
                  else ...[
                    _buildFunnelCard(context, report),
                    16.hGap,
                    _buildCountCard(context, report),
                    16.hGap,
                    _buildRecentCard(context, report),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFunnelCard(BuildContext context, FunnelReport report) {
    final total = report.organizedDays;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title(context, '近 $_windowDays 天漏斗')),
              8.wGap,
              ...([7, 30].map((d) => GestureDetector(
                    onTap: () async {
                      setState(() => _windowDays = d);
                      await _load();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        '$d 天',
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          fontWeight: _windowDays == d ? AppFontWeights.semibold : AppFontWeights.normal,
                          color: _windowDays == d ? AppColors.accent(context) : AppColors.textTertiary(context),
                        ),
                      ),
                    ),
                  ))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '分母是「有整理完成的天数」，同一天点开多次只算一次。',
              style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context), height: 1.5),
            ),
          ),
          14.hGap,
          _stage(context, '整理完成', total, total, report.rateText(total == 0 ? null : 1)),
          10.hGap,
          _stage(context, '进入月刊', report.openedDays, total, report.rateText(report.enterRate)),
          10.hGap,
          _stage(context, '产出内容', report.generatedDays, total, report.rateText(report.generateRate)),
          10.hGap,
          _stage(context, '导出分享', report.exportedDays, total, report.rateText(report.exportRate)),
          12.hGap,
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GlassColors.surface(context),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  report.isSampleEnough ? Icons.check_circle_outline : Icons.info_outline,
                  size: 14,
                  color: report.isSampleEnough ? AppColors.success : AppColors.textTertiary(context),
                ),
                6.wGap,
                Expanded(
                  child: Text(
                    report.isSampleEnough
                        ? '样本 $total 天，比率可读。仍需注意这是单机数据，不能当全网基线。'
                        : '样本只有 $total 天（<5 天），比率只能看方向、不能写结论。再攒几天。',
                    style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textSecondary(context), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(BuildContext context, String label, int value, int total, String rate) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textSecondary(context))),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.divider(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent(context)),
            ),
          ),
        ),
        8.wGap,
        SizedBox(
          width: 76,
          child: Text(
            '$value/$total 天 · $rate',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textPrimary(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildCountCard(BuildContext context, FunnelReport report) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, '事件计数（全量）'),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '不受上方时间窗限制，用来核对上面几个比率的分母。',
              style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context), height: 1.5),
            ),
          ),
          10.hGap,
          _kv(context, '整理完成', '${report.countOf(AnalyticsEvent.organizeCompleted)} 次'),
          _kv(context, '进入月刊', '${report.countOf(AnalyticsEvent.magazineOpened)} 次'),
          _kv(context, '产出内容', '${report.countOf(AnalyticsEvent.magazineGenerated)} 次'),
          _kv(context, '导出分享', '${report.countOf(AnalyticsEvent.magazineExported)} 次'),
          if (report.filePath != null) ...[
            10.hGap,
            Text(
              report.filePath!,
              style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context)),
            ),
          ],
          12.hGap,
          Row(
            children: [
              Expanded(child: _button(context, '复制原始数据', Icons.copy_all_outlined, _copy)),
              10.wGap,
              Expanded(child: _button(context, '清空', Icons.delete_outline, _reset)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(BuildContext context, FunnelReport report) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, '最近 ${report.recent.length} 条'),
          if (report.recent.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('还没有事件。去整理一次照片、开一次月刊就会有记录。',
                  style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
            )
          else
            ...report.recent.map((r) {
              final t = r.time;
              final time = '${t.month}/${t.day} '
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              final props = r.props.isEmpty
                  ? ''
                  : ' · ${r.props.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(time, style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
                    ),
                    Expanded(
                      child: Text(
                        '${r.event}$props',
                        style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) {
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
        children: [
          SizedBox(
            width: 76,
            child: Text(key, style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textSecondary(context))),
          ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, String label, IconData icon, VoidCallback onTap) {
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
            Icon(icon, size: 15, color: AppColors.accent(context)),
            6.wGap,
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                fontWeight: AppFontWeights.medium,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
