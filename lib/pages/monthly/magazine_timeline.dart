import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../components/empty_state.dart';
import '../../components/staggered_fade_in.dart';
import '../../models/photo.dart';
import '../../theme.dart';
import 'magazine_models.dart';
import 'magazine_templates.dart';

/// 时光线渲染所需的外部依赖与回调（由月刊页统一注入）。
class MagazineTimelineHost {
  final BuildContext context;
  final int year;
  final int month;
  final List<Photo> photos;
  final List<MagPage> pages;
  final Map<String, ImgSize> imgSizeCache;
  final Map<String, GlobalKey> exportKeys;
  final String Function(DateTime date) randomCaption;
  /// 打开导出面板（单页 / 多页 / 单张）。
  final VoidCallback onExport;
  final ValueChanged<MagPage> onEditCaption;
  final ValueChanged<Photo> onCreatePage;
  final void Function(Photo photo, MagPage? page) onEditTemplate;
  final Future<void> Function(Photo photo) onExportPhoto;
  final Future<void> Function(Photo photo) onDeletePhoto;

  /// 一键成刊（不传则不显示入口）。
  final VoidCallback? onDraft;

  const MagazineTimelineHost({
    required this.context,
    required this.year,
    required this.month,
    required this.photos,
    required this.pages,
    required this.imgSizeCache,
    required this.exportKeys,
    required this.randomCaption,
    required this.onExport,
    required this.onEditCaption,
    required this.onCreatePage,
    required this.onEditTemplate,
    required this.onExportPhoto,
    required this.onDeletePhoto,
    this.onDraft,
  });
}

// ─── 时光线视图 ────────────────────────────────────────────────
Widget buildTimelineView(MagazineTimelineHost host) {
  final context = host.context;
  final count = host.photos.length;
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
        child: Row(
          children: [
            Icon(Icons.timeline, size: 18, color: AppColors.accent(context)),
            8.wGap,
            Text('${host.year}年${host.month}月 时光线',
              style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: AppColors.textPrimary(context))),
            const Spacer(),
            if (host.onDraft != null) ...[
              GestureDetector(
                onTap: host.onDraft,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: AppColors.accent(context)),
                    3.wGap,
                    Text('一键成刊',
                        style: TextStyle(fontSize: 11, color: AppColors.accent(context))),
                  ],
                ),
              ),
              10.wGap,
            ],
            Text('$count/12 张',
              style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textTertiary(context))),
          ],
        ),
      ),
      const SizedBox(height: AppSpacings.lg),
      ...host.photos.asMap().entries.map((entry) {
        return StaggeredFadeIn(
          index: entry.key,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacings.xl,
              right: AppSpacings.xl,
              bottom: entry.key < count - 1 ? AppSpacings.lg : 0,
            ),
            // RepaintBoundary 避免单个条目变化导致其他条目重绘
            child: RepaintBoundary(
              child: _buildTimelineEntry(host, entry.value, entry.key == count - 1),
            ),
          ),
        );
      }),
      const SizedBox(height: AppSpacings.lg),
      // 导出全部按钮
      if (count >= 2)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
          child: AppButton.primary(
            icon: Icons.ios_share_outlined,
            label: '导出月刊',
            onPressed: host.onExport,
          ),
        ),
      const SizedBox(height: AppSpacings.lg),
    ],
  );
}

Widget _buildTimelineEntry(MagazineTimelineHost host, Photo photo, bool isLast) {
  final context = host.context;
  // 实时从 pages 获取最新的 MagPage（编辑器修改后会更新 pages）
  final pageIndex = host.pages.indexWhere((p) => p.photoIds.contains(photo.id));
  final page = pageIndex >= 0 ? host.pages[pageIndex] : null;
  // 图片尺寸由页面集中预加载，build 中不再触发异步 setState（避免死循环卡顿）
  final size = host.imgSizeCache[photo.path];
  host.exportKeys.putIfAbsent(photo.id, () => GlobalKey());

  // 若无对应 MagPage（理论上不会发生，photos 来源于 pages），兜底创建
  final renderPage = page ?? MagPage(
    id: 'p_${DateTime.now().microsecondsSinceEpoch}_${photo.id}',
    photoIds: [photo.id],
    template: MagTemplate.bottomWhite,
    caption: host.randomCaption(photo.dateTime),
  );

  // 入口处直接计算 cardWidth，避免在布局树中使用 LayoutBuilder（与 IntrinsicHeight 冲突会导致高度塌陷）
  // cardWidth = 屏幕宽 - 时光线左右 padding(AppSpacings.xl * 2) - 时间线宽(24) - 间距(12)
  final cardWidth = MediaQuery.of(context).size.width - AppSpacings.xl * 2 - 24 - 12;

  // 时间线竖线：用 Stack 绝对定位，不依赖 IntrinsicHeight
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 时间线圆点 + 竖线（竖线用固定高度，足够覆盖卡片）
      SizedBox(
        width: 24,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 竖线（如果不是最后一条）
            if (!isLast)
              Positioned(
                top: 16,
                bottom: 0,
                child: Container(width: 1, color: AppColors.divider(context)),
              ),
            // 圆点
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      12.wGap,
      // 卡片区域
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: GlassColors.bg(context),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: GlassColors.border(context), width: 1),
            boxShadow: [
              BoxShadow(
                color: GlassColors.shadow(context),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模板渲染区（导出快照范围）：直接渲染，不再套 LayoutBuilder
                // 模板内部已有自己的 margin / cornerRadius / ClipRRect，外层只保留圆角裁剪
                RepaintBoundary(
                  key: host.exportKeys[photo.id],
                  child: renderSingleTemplate(context, renderPage, photo, size, cardWidth),
                ),
                // 操作按钮行（不纳入导出快照）
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      _timelineOpBtn(context, Icons.text_fields, '文案', () {
                        if (page != null) {
                          host.onEditCaption(page);
                        } else {
                          host.onCreatePage(photo);
                        }
                      }),
                      const SizedBox(width: AppSpacings.md),
                      _timelineOpBtn(context, Icons.image, '模板', () {
                        host.onEditTemplate(photo, page);
                      }),
                      const SizedBox(width: AppSpacings.md),
                      _timelineOpBtn(context, Icons.share_outlined, '导出', () {
                        host.onExportPhoto(photo);
                      }),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => host.onDeletePhoto(photo),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline, size: 16, color: AppColors.textTertiary(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _timelineOpBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary(context)),
        4.wGap,
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary(context))),
      ],
    ),
  );
}

// ─── 空态 ─────────────────────────────────────────────────────
Widget buildTimelineEmpty(
  BuildContext context, {
  required VoidCallback onImport,
  VoidCallback? onDraft,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacings.x6l),
    child: EmptyState(
      icon: Icons.auto_awesome,
      title: '这个月还没有成册',
      subtitle: onDraft == null
          ? '点击右上角「导入照片」，最多12张'
          : '点一下，从本月照片里挑 9 张排成一册；也可以自己一张张导入',
      ctaLabel: onDraft == null ? '导入照片' : '一键成刊',
      ctaIcon: onDraft == null ? Icons.add_photo_alternate_outlined : Icons.auto_awesome,
      onCta: onDraft ?? onImport,
      secondaryLabel: onDraft == null ? null : '手动导入照片',
      secondaryIcon: Icons.add_photo_alternate_outlined,
      onSecondary: onDraft == null ? null : onImport,
    ),
  );
}

/// 删除确认：确认后由调用方移除数据并持久化。
Future<void> confirmDeleteTimelinePhoto(
  BuildContext context,
  Photo photo, {
  required int year,
  required int month,
  required VoidCallback onConfirmed,
}) async {
  HapticFeedback.heavyImpact();
  final confirmed = await AppDialog.confirm(
    context,
    title: '删除照片',
    message: '确定要从$year年$month月时光线中移除这张照片吗？',
    danger: true,
    icon: Icons.delete_outline,
    confirmLabel: '删除',
  );
  if (confirmed != true) return;
  onConfirmed();
}
