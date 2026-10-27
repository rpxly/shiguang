import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/app_button.dart';
import '../../models/photo.dart';
import '../../theme.dart';
import 'magazine_models.dart';
import 'magazine_templates.dart';

/// 模板编辑器：参考水印大师 app 的"所见即所得"交互。
/// 布局：顶部实时预览 + 中间横向模板缩略图 + 底部 Tab 分组参数。
/// 选模板不关闭弹窗，调参实时反映到预览，支持尺寸预设一键切换。
void showTemplateEditor({
  required BuildContext context,
  required MagPage page,
  required int year,
  required int month,
  required Photo? photo,
  required Map<String, ImgSize> imgSizeCache,
  required Future<ImgSize?> Function(String path) loadImageSize,
  required VoidCallback persist,
  required VoidCallback onChanged,
}) {
  HapticFeedback.selectionClick();
  int tab = 0; // 0=模板 1=边框 2=尺寸 3=字体
  bool linkMargins = page.marginTop == page.marginBottom &&
      page.marginTop == page.marginLeft &&
      page.marginTop == page.marginRight;
  bool linkPaddings = page.paddingTop == page.paddingBottom &&
      page.paddingTop == page.paddingLeft &&
      page.paddingTop == page.paddingRight;
  final cardWidth = MediaQuery.of(context).size.width - AppSpacings.xl * 2;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgElevated(context),
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final previewKey = GlobalKey();

        // 模板缩略图示意图标
        IconData templateIcon(MagTemplate t) {
          switch (t) {
            case MagTemplate.bottomWhite:
              return Icons.calendar_view_month;
            case MagTemplate.fullBleed:
              return Icons.fullscreen;
            case MagTemplate.polaroid:
              return Icons.photo_camera_back;
            case MagTemplate.centerLine:
              return Icons.horizontal_rule;
            case MagTemplate.stereoFrame:
              return Icons.filter_frames;
            case MagTemplate.filmGrain:
              return Icons.movie;
          }
        }

        // 判断某个尺寸预设是否当前选中
        bool isRatioSelected(double ratio) {
          if (ratio == 0) return page.imageHeight == 0;
          final target = (cardWidth * ratio).round();
          return (page.imageHeight.round() - target).abs() <= 2;
        }

        // Tab 按钮构造
        Widget buildTab(String label, int index, int current, VoidCallback onTap) {
          final selected = index == current;
          return Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent(ctx) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? AppFontWeights.semibold : AppFontWeights.normal,
                      color: selected ? Colors.white : AppColors.textSecondary(ctx),
                    )),
              ),
            ),
          );
        }

        // 顶部预览：用真实模板渲染，缩放适配预览区高度
        Widget buildPreview() {
          if (photo == null) {
            return Container(
              height: 280,
              color: GlassColors.surface(context),
              child: Center(child: Text('照片不存在', style: TextStyle(color: AppColors.textTertiary(context)))),
            );
          }
          final size = imgSizeCache[photo.path];
          // 缓存未命中时异步读取
          if (size == null) {
            loadImageSize(photo.path).then((s) {
              if (s != null) setSheetState(() {});
            });
          }
          return Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.md),
            decoration: BoxDecoration(
              color: GlassColors.surface(context),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: RepaintBoundary(
              key: previewKey,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: cardWidth,
                  child: renderSingleTemplate(ctx, page, photo, size, cardWidth),
                ),
              ),
            ),
          );
        }

        // 横向模板缩略图卡片
        Widget buildTemplateCard(MagTemplate t) {
          final selected = t == page.template;
          return GestureDetector(
            onTap: () {
              page.template = t;
              persist();
              setSheetState(() {});
              onChanged();
            },
            child: Container(
              width: 88,
              margin: const EdgeInsets.only(right: AppSpacings.sm),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent(context).withOpacity(0.1) : GlassColors.surface(context),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: selected ? AppColors.accent(context) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(templateIcon(t), size: 28,
                      color: selected ? AppColors.accent(context) : AppColors.textSecondary(context)),
                  const SizedBox(height: 6),
                  Text(t.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? AppFontWeights.semibold : AppFontWeights.normal,
                        color: selected ? AppColors.accent(context) : AppColors.textSecondary(context),
                      )),
                ],
              ),
            ),
          );
        }

        // 尺寸预设按钮
        Widget buildRatioChip(String label, double ratio) {
          // ratio = 目标 高/宽；0 表示原比例
          final selected = isRatioSelected(ratio);
          return GestureDetector(
            onTap: () {
              if (ratio == 0) {
                page.imageHeight = 0;
              } else {
                page.imageHeight = (cardWidth * ratio).roundToDouble();
              }
              persist();
              setSheetState(() {});
              onChanged();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent(context) : GlassColors.surface(context),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFontWeights.medium,
                    color: selected ? Colors.white : AppColors.textSecondary(context),
                  )),
            ),
          );
        }

        // 通用滑块行
        Widget buildSliderRow(String label, double value, double min, double max, int divisions,
            String Function(double) format, ValueChanged<double> onChangedValue) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: AppColors.textSecondary(context))),
                    Text(format(value), style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.accent(context))),
                  ],
                ),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: format(value),
                  activeColor: AppColors.accent(context),
                  inactiveColor: AppColors.divider(context),
                  // 拖动中只改内存 + 刷新预览，避免每个 tick 触发 Hive 写盘与整页 rebuild
                  onChanged: (v) {
                    onChangedValue(v);
                    setSheetState(() {});
                  },
                  // 松手后一次性持久化并同步到页面时光线
                  onChangeEnd: (v) {
                    persist();
                    onChanged();
                  },
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacings.sm),
              Container(width: 32, height: 4, decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: AppSpacings.sm),
              // 顶部实时预览
              buildPreview(),
              // Tab 切换
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                decoration: BoxDecoration(
                  color: GlassColors.surface(context),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    buildTab('模板', 0, tab, () => setSheetState(() => tab = 0)),
                    buildTab('边框', 1, tab, () => setSheetState(() => tab = 1)),
                    buildTab('尺寸', 2, tab, () => setSheetState(() => tab = 2)),
                    buildTab('字体', 3, tab, () => setSheetState(() => tab = 3)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacings.sm),
              // 操作区（按 Tab 切换内容）
              Flexible(
                child: tab == 0
                    ? SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                          children: MagTemplate.values.map(buildTemplateCard).toList(),
                        ),
                      )
                    : tab == 1
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: AppSpacings.sm),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── 外边距（卡片到内卡片）──
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: 4),
                                  child: Text('外边距', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.semibold, color: AppColors.textPrimary(context))),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: 2),
                                  child: Row(
                                    children: [
                                      Text('四方向联动', style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textSecondary(context))),
                                      const Spacer(),
                                      SizedBox(
                                        height: 24,
                                        child: Switch(
                                          value: linkMargins,
                                          activeColor: AppColors.accent(context),
                                          onChanged: (v) {
                                            if (v) {
                                              final avg = (page.marginTop + page.marginBottom + page.marginLeft + page.marginRight) / 4;
                                              page.marginTop = page.marginBottom = page.marginLeft = page.marginRight = avg.roundToDouble();
                                              persist();
                                            }
                                            setSheetState(() => linkMargins = v);
                                            onChanged();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (linkMargins)
                                  buildSliderRow('外边距', page.marginTop, 0, 60, 30, (v) => '${v.round()}px', (v) {
                                    page.marginTop = page.marginBottom = page.marginLeft = page.marginRight = v;
                                  })
                                else ...[
                                  buildSliderRow('外-上', page.marginTop, 0, 60, 30, (v) => '${v.round()}px', (v) => page.marginTop = v),
                                  buildSliderRow('外-下', page.marginBottom, 0, 60, 30, (v) => '${v.round()}px', (v) => page.marginBottom = v),
                                  buildSliderRow('外-左', page.marginLeft, 0, 60, 30, (v) => '${v.round()}px', (v) => page.marginLeft = v),
                                  buildSliderRow('外-右', page.marginRight, 0, 60, 30, (v) => '${v.round()}px', (v) => page.marginRight = v),
                                ],
                                Container(height: 1, color: AppColors.divider(context), margin: const EdgeInsets.symmetric(vertical: AppSpacings.sm)),
                                // ── 内边距（内卡片边到内容）──
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: 4),
                                  child: Text('内边距', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.semibold, color: AppColors.textPrimary(context))),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: 2),
                                  child: Row(
                                    children: [
                                      Text('四方向联动', style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textSecondary(context))),
                                      const Spacer(),
                                      SizedBox(
                                        height: 24,
                                        child: Switch(
                                          value: linkPaddings,
                                          activeColor: AppColors.accent(context),
                                          onChanged: (v) {
                                            if (v) {
                                              final avg = (page.paddingTop + page.paddingBottom + page.paddingLeft + page.paddingRight) / 4;
                                              page.paddingTop = page.paddingBottom = page.paddingLeft = page.paddingRight = avg.roundToDouble();
                                              persist();
                                            }
                                            setSheetState(() => linkPaddings = v);
                                            onChanged();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (linkPaddings)
                                  buildSliderRow('内边距', page.paddingTop, 0, 60, 30, (v) => '${v.round()}px', (v) {
                                    page.paddingTop = page.paddingBottom = page.paddingLeft = page.paddingRight = v;
                                  })
                                else ...[
                                  buildSliderRow('内-上', page.paddingTop, 0, 60, 30, (v) => '${v.round()}px', (v) => page.paddingTop = v),
                                  buildSliderRow('内-下', page.paddingBottom, 0, 60, 30, (v) => '${v.round()}px', (v) => page.paddingBottom = v),
                                  buildSliderRow('内-左', page.paddingLeft, 0, 60, 30, (v) => '${v.round()}px', (v) => page.paddingLeft = v),
                                  buildSliderRow('内-右', page.paddingRight, 0, 60, 30, (v) => '${v.round()}px', (v) => page.paddingRight = v),
                                ],
                                Container(height: 1, color: AppColors.divider(context), margin: const EdgeInsets.symmetric(vertical: AppSpacings.sm)),
                                buildSliderRow('圆角半径', page.cornerRadius, 0, 40, 20,
                                    (v) => '${v.round()}px', (v) => page.cornerRadius = v),
                                Container(height: 1, color: AppColors.divider(context), margin: const EdgeInsets.symmetric(vertical: AppSpacings.sm)),
                                buildSliderRow('图文间距', page.textMargin, 0, 80, 40,
                                    (v) => '${v.round()}px', (v) => page.textMargin = v),
                                // 胶片品牌切换 + 暗角强度（仅 filmGrain 模板显示）
                                if (page.template == MagTemplate.filmGrain) ...[
                                  Container(height: 1, color: AppColors.divider(context), margin: const EdgeInsets.symmetric(vertical: AppSpacings.sm)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                    child: Text('胶片品牌', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: AppColors.textSecondary(context))),
                                  ),
                                  const SizedBox(height: AppSpacings.sm),
                                  SizedBox(
                                    height: 36,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                      children: FilmBrand.values.map((b) {
                                        final selected = b == page.filmBrand;
                                        return GestureDetector(
                                          onTap: () {
                                            page.filmBrand = b;
                                            persist();
                                            setSheetState(() {});
                                            onChanged();
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(right: AppSpacings.sm),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: selected ? b.primaryColor : GlassColors.surface(context),
                                              borderRadius: BorderRadius.circular(AppRadii.full),
                                              border: Border.all(
                                                color: selected ? b.primaryColor : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                b.label,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: AppFontWeights.medium,
                                                  color: selected ? b.accentColor : AppColors.textSecondary(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  buildSliderRow('暗角强度', page.vignetteIntensity, 0, 1, 20,
                                      (v) => '${(v * 100).round()}%', (v) => page.vignetteIntensity = v),
                                ],
                              ],
                            ),
                          )
                        : tab == 2
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacings.sm),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                    child: Text('尺寸预设', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: AppColors.textSecondary(context))),
                                  ),
                                  const SizedBox(height: AppSpacings.sm),
                                  SizedBox(
                                    height: 36,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                      children: [
                                        buildRatioChip('原比例', 0),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('1:1', 1.0),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('4:3', 3 / 4),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('3:2', 2 / 3),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('16:9', 9 / 16),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('21:9', 9 / 21),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('3:4', 4 / 3),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('2:3', 3 / 2),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('9:16', 16 / 9),
                                        const SizedBox(width: AppSpacings.sm),
                                        buildRatioChip('4:5', 5 / 4),
                                      ],
                                    ),
                                  ),
                                  buildSliderRow('自定义高度', page.imageHeight, 0, 800, 80,
                                      (v) => v == 0 ? '自动' : '${v.round()}px', (v) => page.imageHeight = v),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                    child: Text('选"原比例"按图片真实宽高显示不裁切；横图建议用 16:9，竖图建议用 3:4 或 9:16',
                                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary(context))),
                                  ),
                                ],
                              )
                            // Tab 3: 字体样式选择
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacings.sm),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                    child: Text('字体样式', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: AppColors.textSecondary(context))),
                                  ),
                                  const SizedBox(height: AppSpacings.sm),
                                  SizedBox(
                                    height: 72,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
                                      children: MagFontStyle.values.map((f) {
                                        final selected = f == page.fontStyle;
                                        return GestureDetector(
                                          onTap: () {
                                            page.fontStyle = f;
                                            persist();
                                            setSheetState(() {});
                                            onChanged();
                                          },
                                          child: Container(
                                            width: 100,
                                            margin: const EdgeInsets.only(right: AppSpacings.sm),
                                            decoration: BoxDecoration(
                                              color: selected ? AppColors.accent(context).withOpacity(0.1) : GlassColors.surface(context),
                                              borderRadius: BorderRadius.circular(AppRadii.md),
                                              border: Border.all(
                                                color: selected ? AppColors.accent(context) : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'ABC\n文案',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: f.fontFamily,
                                                  fontWeight: f.fontWeight,
                                                  letterSpacing: f.letterSpacing,
                                                  color: selected ? AppColors.accent(context) : AppColors.textSecondary(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.sm),
                                    child: Text(page.fontStyle.label,
                                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
                                  ),
                                ],
                              ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacings.lg, 0, AppSpacings.lg, AppSpacings.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton.primary(
                        icon: Icons.ios_share,
                        label: '导出并分享',
                        onPressed: () async {
                          try {
                            final boundary = previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                            if (boundary == null) return;
                            final image = await boundary.toImage(pixelRatio: 2.0);
                            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                            if (byteData == null) return;
                            final tempDir = await getTemporaryDirectory();
                            final file = File('${tempDir.path}${Platform.pathSeparator}template_${page.id}.png');
                            await file.writeAsBytes(byteData.buffer.asUint8List());
                            await Share.shareXFiles([XFile(file.path)], text: '${year}年${month}月');
                          } catch (_) {}
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacings.md),
                    Expanded(
                      child: AppButton.secondary(
                        label: '完成',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
