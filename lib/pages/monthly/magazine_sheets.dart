import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../components/app_button.dart';
import '../../components/app_chip.dart';
import '../../components/app_dialog.dart';
import '../../components/bottom_blur_bar.dart';
import '../../models/photo.dart';
import '../../repository/local_repository.dart';
import '../../services/image_helper.dart';
import '../../theme.dart';
import 'magazine_models.dart';
import 'quote_picker_sheet.dart';

// ─── 心情 / 天气选项和图标 ───
const List<String> magMoodOptions = ['愉快', '平静', '普通', '忧郁', '激动', '温馨', '充实', '疲惫'];
const List<String> magWeatherOptions = ['晴', '多云', '阴', '雨', '雪', '风', '雾'];

IconData magMoodIcon(String mood) => switch (mood) {
      '愉快' => Icons.sentiment_very_satisfied,
      '平静' => Icons.self_improvement,
      '普通' => Icons.sentiment_neutral,
      '忧郁' => Icons.sentiment_dissatisfied,
      '激动' => Icons.celebration_outlined,
      '温馨' => Icons.favorite,
      '充实' => Icons.auto_awesome,
      '疲惫' => Icons.battery_alert_outlined,
      _ => Icons.sentiment_satisfied,
    };

IconData magWeatherIcon(String weather) => switch (weather) {
      '晴' => Icons.wb_sunny,
      '多云' => Icons.cloud,
      '阴' => Icons.cloud_queue,
      '雨' => Icons.water_drop,
      '雪' => Icons.ac_unit,
      '风' => Icons.air,
      '雾' => Icons.foggy,
      _ => Icons.wb_sunny,
    };

void showMoodPicker(BuildContext context, {required String current, required ValueChanged<String> onSelected}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: context.overlay,
    builder: (ctx) => BottomBlurBar(
      blur: false,
      title: '选择心情',
      subtitle: '标记本月的心情基调',
      icon: Icons.mood_outlined,
      children: [
        Wrap(spacing: 10, runSpacing: 10,
          children: magMoodOptions.map((m) => _buildOptionChip(
            ctx: ctx,
            label: m,
            icon: magMoodIcon(m),
            isSelected: current == m,
            onTap: () {
              onSelected(m);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ],
    ),
  );
}

void showWeatherPicker(BuildContext context, {required String current, required ValueChanged<String> onSelected}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: context.overlay,
    builder: (ctx) => BottomBlurBar(
      blur: false,
      title: '选择天气',
      subtitle: '记录本月的天气印象',
      icon: Icons.wb_cloudy_outlined,
      children: [
        Wrap(spacing: 10, runSpacing: 10,
          children: magWeatherOptions.map((w) => _buildOptionChip(
            ctx: ctx,
            label: w,
            icon: magWeatherIcon(w),
            isSelected: current == w,
            onTap: () {
              onSelected(w);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ],
    ),
  );
}

/// 通用选项 chip：未选中为 elevated 卡片 + border，选中为 accent 渐变 + 阴影 + 白文字。
Widget _buildOptionChip({
  required BuildContext ctx,
  required String label,
  required IconData icon,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: AppTransitions.fast,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isSelected ? AppGradients.accent : null,
        color: isSelected ? null : ctx.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: isSelected
            ? null
            : Border.all(color: ctx.borderSubtle),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.accent(ctx).withOpacity(0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : ctx.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: isSelected ? AppFontWeights.semibold : AppFontWeights.normal,
              color: isSelected ? Colors.white : ctx.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 手动填写本月步数（自动读取失败或需修正时的兜底入口）。
/// 输入校验：仅允许非负整数；留空则视为 0。
void showStepsPicker(BuildContext context,
    {required int year, required int month, required int currentSteps, required ValueChanged<int> onSaved}) {
  final controller = TextEditingController(text: currentSteps > 0 ? '$currentSteps' : '');
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: context.overlay,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: BottomBlurBar(
        blur: false,
        title: '填写步数',
        subtitle: '$year 年 $month 月的步数',
        icon: Icons.directions_walk_outlined,
        iconGradient: AppGradients.ocean,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: '如 120000',
              hintStyle: TextStyle(color: AppColors.textTertiary(context)),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: AppGradients.ocean,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(Icons.directions_walk, size: 18, color: Colors.white),
              ),
              prefixIconConstraints: const BoxConstraints(maxWidth: 52, maxHeight: 52),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: BorderSide(color: AppColors.accent(context), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: AppSpacings.lg),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: '取消',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: AppSpacings.md),
              Expanded(
                child: AppButton.primary(
                  label: '保存',
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim()) ?? 0;
                    onSaved(value);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── 批量导入 ──────────────────────────────────────────────────
Future<void> showImporter({
  required BuildContext context,
  required int year,
  required int month,
  required List<MagPage> pages,
  required List<Photo> monthPhotos,
  required Map<String, ImgSize> imgSizeCache,
  required ImagePicker picker,
  required LocalRepository repository,
  required String Function(DateTime date) randomCaption,
  required Future<ImgSize?> Function(String path) loadImageSize,
  required VoidCallback persist,
  required ValueChanged<bool> setLoading,
}) async {
  HapticFeedback.lightImpact();
  final maxNew = 12 - monthPhotos.length;
  if (maxNew <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('每月最多12张照片，已达上限')));
    return;
  }

  try {
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 95,
    );
    if (images.isEmpty) return;
    if (!context.mounted) return;

    // 超出剩余配额的照片截断
    final toImport = images.length > maxNew ? images.sublist(0, maxNew) : images;
    if (images.length > maxNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('每月最多12张，已导入剩余 $maxNew 张配额')));
    }

    setLoading(true);

    final appDir = await getApplicationDocumentsDirectory();
    final magDir = Directory('${appDir.path}${Platform.pathSeparator}magazine${Platform.pathSeparator}$year${Platform.pathSeparator}$month');
    if (!await magDir.exists()) {
      await magDir.create(recursive: true);
    }

    // 收集本轮导入的照片和 MagPage，循环结束后统一刷新
    final newPhotos = <Photo>[];
    final newPages = <MagPage>[];
    final newSizeFutures = <Future<ImgSize?>>[];
    final newPaths = <String>[];

    for (final image in toImport) {
      if (!context.mounted) break;
      // id 加上自增索引避免微秒级冲突
      final ts = DateTime.now().microsecondsSinceEpoch;
      final idx = newPhotos.length;
      final id = 'mag_${ts}_${idx}_${image.name.hashCode.abs()}';
      final ext = image.name.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext) ? ext : 'jpg';
      final destPath = '${magDir.path}${Platform.pathSeparator}$id.$safeExt';
      await File(image.path).copy(destPath);

      // 照片日期：当前月用今天，历史月份用该月15号
      final now = DateTime.now();
      final photoDate = (now.year == year && now.month == month)
          ? now
          : DateTime(year, month, 15);

      final photo = Photo(
        id: id,
        path: destPath,
        thumbnailPath: destPath,
        date: photoDate,
        fileSize: await File(destPath).length(),
      );
      repository.savePhoto(photo);
      newPhotos.add(photo);

      final page = MagPage(
        id: 'p_${ts}_${idx}_$id',
        photoIds: [id],
        template: MagTemplate.bottomWhite,
        caption: randomCaption(photoDate),
      );
      newPages.add(page);

      // 异步加载图片尺寸（不阻塞 UI）
      newPaths.add(destPath);
      newSizeFutures.add(loadImageSize(destPath));
    }

    // 统一更新内存数据
    pages.addAll(newPages);
    monthPhotos.addAll(newPhotos);
    persist();

    // 等待尺寸加载完成（最多 5 秒，超时由 loadImageSize 内部处理）
    final results = await Future.wait(newSizeFutures);
    for (var i = 0; i < results.length; i++) {
      if (results[i] != null) imgSizeCache[newPaths[i]] = results[i]!;
    }

    if (context.mounted) {
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${newPhotos.length} 张照片')));
    }
  } catch (e) {
    debugPrint('[MagPage] 导入失败: $e');
    if (context.mounted) {
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')));
    }
  }
}

// ─── 文案编辑 ──────────────────────────────────────────────────
void editCaption(BuildContext context,
    {required MagPage page,
    required int year,
    required int month,
    required VoidCallback onSaved,
    LocalRepository? repository}) {
  final controller = TextEditingController(text: page.caption);
  AppDialog.show(
    context,
    title: '编辑文案',
    subtitle: '$year 年 $month 月月刊配图',
    icon: Icons.edit_outlined,
    children: [
      Container(
        decoration: BoxDecoration(
          color: GlassColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.divider(context)),
        ),
        padding: const EdgeInsets.all(AppSpacings.md),
        child: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          style: TextStyle(fontSize: AppFontSizes.base, color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: '输入艺术文案...',
            hintStyle: TextStyle(color: AppColors.textTertiary(context)),
          ),
        ),
      ),
      AppSpacings.md.hGap,
      // 从文案库挑选一条填入输入框
      Align(
        alignment: Alignment.centerRight,
        child: AppChip.action(
          label: '选文案',
          icon: Icons.format_quote,
          onTap: () async {
            final quote = await showQuotePicker(context, repository: repository);
            if (quote != null) {
              controller.text = formatQuoteAsCaption(quote);
            }
          },
        ),
      ),
    ],
    actions: [
      AppButton.secondary(
        label: '取消',
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton.primary(
        label: '保存',
        onPressed: () {
          page.caption = controller.text.trim();
          onSaved();
          Navigator.of(context).pop();
        },
      ),
    ],
  );
}

// ─── 分享选项 ──────────────────────────────────────────────────
void showShareOptions(
  BuildContext context, {
  required VoidCallback onSingleExport,
  required VoidCallback onSinglePage,
  required VoidCallback onMultiPage,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: context.overlay,
    builder: (ctx) => BottomBlurBar(
      blur: false,
      title: '导出月刊',
      subtitle: '选择导出方式，分享你的月刊',
      icon: Icons.ios_share_outlined,
      children: [
        _shareOption(
          ctx, Icons.dashboard_customize_outlined, '单页月刊',
          '一页排完：大图 + 图注 + 落款，适合直接发',
          AppGradients.ocean,
          () { Navigator.pop(ctx); onSinglePage(); },
        ),
        10.hGap,
        _shareOption(
          ctx, Icons.auto_stories_outlined, '多页画册',
          '封面 + 内页 + 统计页，适合存档和打印',
          AppGradients.accent,
          () { Navigator.pop(ctx); onMultiPage(); },
        ),
        10.hGap,
        _shareOption(
          ctx, Icons.photo_library_outlined, '单张导出',
          '逐张选择照片，用艺术模板导出',
          AppGradients.accentSoft,
          () { Navigator.pop(ctx); onSingleExport(); },
        ),
      ],
    ),
  );
}

Widget _shareOption(BuildContext ctx, IconData icon, String title, String subtitle, LinearGradient gradient, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ctx.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: ctx.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          16.wGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.semibold, color: AppColors.textPrimary(ctx))),
                2.hGap,
                Text(subtitle, style: TextStyle(fontSize: AppFontSizes.sm, color: ctx.textTertiary, height: 1.4)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: ctx.textTertiary),
        ],
      ),
    ),
  );
}

void showSingleExportPicker(BuildContext context, {required List<Photo> photos, required void Function(Photo) onExport}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: context.overlay,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      margin: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 12),
      decoration: BoxDecoration(
        color: GlassColors.bgHeavy(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
        border: Border(top: BorderSide(color: GlassColors.border(context), width: 0.5)),
        boxShadow: const [AppShadows.sheetShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 把手
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(color: context.isDark ? const Color(0x4DFFFFFF) : const Color(0x4D3C3C43), borderRadius: BorderRadius.circular(999)),
          )),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent(context).withOpacity(0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.photo_library_outlined, size: 22, color: Colors.white),
                ),
                const SizedBox(width: AppSpacings.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('选择要导出的照片',
                          style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.semibold, color: AppColors.textPrimary(context), letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text('共 ${photos.length} 张照片',
                          style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacings.lg),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: AppSpacings.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.divider.withOpacity(0),
                  context.divider,
                  context.divider.withOpacity(0),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final photo = photos[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    onExport(photo);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LocalImage(path: photo.thumbnailPath, fit: BoxFit.cover,
                          cacheWidth: (MediaQuery.of(context).size.width / 3 * MediaQuery.of(context).devicePixelRatio).round(),
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(gradient: AppGradients.accentSoft),
                            child: const Icon(Icons.image_outlined, color: Colors.white38, size: 24)),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                colors: [context.scrim, Colors.transparent],
                              ),
                            ),
                            child: Text('${photo.dateTime.month}/${photo.dateTime.day}',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: AppFontWeights.medium)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
