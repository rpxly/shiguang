import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../components/glass_card.dart';
import '../components/glass_icon_button.dart';
import '../components/loading_overlay.dart';
import '../components/bottom_blur_bar.dart';
import '../components/app_button.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../services/image_helper.dart';
import '../services/scene_classifier_service.dart';
import '../components/app_background.dart';

class PhotoDetailPage extends StatefulWidget {
  final Photo photo;
  final LocalRepository repository;
  final VoidCallback onBack;
  final Future<void> Function() onDelete;
  final ValueChanged<Photo> onSimilarPhotoTap;

  const PhotoDetailPage({
    super.key,
    required this.photo,
    required this.repository,
    required this.onBack,
    required this.onDelete,
    required this.onSimilarPhotoTap,
  });

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  List<Photo> _allPhotos = [];
  List<Photo> _similarPhotos = [];
  bool _isDeleting = false;
  // 图片真实尺寸（用于按比例显示，避免模糊）
  double? _imgWidth;
  double? _imgHeight;
  bool _imgSizeLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadImageSize();
  }

  void _loadData() {
    _allPhotos = widget.repository.getAllPhotos();
    final cat = widget.photo.category;
    final sameCategory = <Photo>[];
    final sameMonth = <Photo>[];
    final others = <Photo>[];
    final sameCategoryIds = <String>{};

    // 单次遍历完成分类，并用 id Set 去重，避免 List.contains 的 O(n²)
    for (final p in _allPhotos) {
      if (p.id == widget.photo.id) continue;
      final isSameCategory = cat != null && p.category == cat;
      final isSameMonth = p.dateTime.year == widget.photo.dateTime.year &&
          p.dateTime.month == widget.photo.dateTime.month;
      if (isSameCategory) {
        sameCategory.add(p);
        sameCategoryIds.add(p.id);
      }
      if (isSameMonth) {
        sameMonth.add(p);
      }
      if (!isSameCategory && !isSameMonth) others.add(p);
    }

    _similarPhotos = [
      ...sameCategory,
      ...sameMonth.where((p) => !sameCategoryIds.contains(p.id)),
      ...others,
    ].take(6).toList();
  }

  Future<void> _loadImageSize() async {
    try {
      final file = File(widget.photo.path);
      if (!await file.exists()) {
        if (mounted) setState(() => _imgSizeLoading = false);
        return;
      }
      // 用 ImageProvider 异步解析尺寸，避免主线程同步解码整张图片
      final completer = Completer<ImageInfo?>();
      final stream = FileImage(file).resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          completer.complete(info);
          stream.removeListener(listener);
        },
        onError: (e, _) {
          completer.complete(null);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final info = await completer.future.timeout(const Duration(seconds: 5));
      if (mounted && info != null) {
        setState(() {
          _imgWidth = info.image.width.toDouble();
          _imgHeight = info.image.height.toDouble();
          _imgSizeLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _imgSizeLoading = false);
  }

  void _showDeleteConfirmation() {
    if (widget.repository.getSkipDeleteConfirm()) {
      setState(() => _isDeleting = true);
      widget.onDelete().then((_) {
        if (mounted) setState(() => _isDeleting = false);
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: context.overlay,
      builder: (ctx) => _DeleteConfirmationSheet(
        photo: widget.photo,
        repository: widget.repository,
        onDelete: () {
          Navigator.pop(ctx);
          setState(() => _isDeleting = true);
          widget.onDelete().then((_) {
            if (mounted) setState(() => _isDeleting = false);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                // 液态玻璃顶栏：内容滚动到顶栏下方时获得真模糊过渡，
                // 填充自上而下渐隐，与状态栏 Scrim 同一套玻璃语言
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            GlassColors.bgMedium(context),
                            GlassColors.bgMedium(context).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                leading: Center(
                  child: GlassIconButton(
                    icon: Icons.close,
                    onTap: widget.onBack,
                    tooltip: '关闭',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    child: _buildHeroImage(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildMetadataSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (_similarPhotos.isNotEmpty)
                SliverToBoxAdapter(child: _buildSimilarPhotosSection(context)),
              SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          if (_isDeleting)
            const LoadingOverlay(message: '正在删除...'),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// 按图片真实比例显示，避免模糊
  Widget _buildHeroImage() {
    if (_imgSizeLoading) {
      return Container(
        height: 360,
        color: context.surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 按屏幕宽度等比缩放
    final screenWidth = MediaQuery.of(context).size.width - 40;
    double? displayHeight;
    if (_imgWidth != null && _imgHeight != null && _imgWidth! > 0) {
      displayHeight = screenWidth * (_imgHeight! / _imgWidth!);
      // 限制最大高度避免过长
      displayHeight = displayHeight.clamp(200.0, 600.0);
    } else {
      displayHeight = 360;
    }

    final cacheW = (screenWidth * MediaQuery.of(context).devicePixelRatio).round();
    return InteractiveViewer(
      child: LocalImage(
        path: widget.photo.path,
        width: screenWidth,
        height: displayHeight,
        fit: BoxFit.contain,
        cacheWidth: cacheW,
        errorBuilder: (_, __, ___) => Container(
          height: displayHeight!,
          decoration: const BoxDecoration(gradient: AppGradients.accentSoft),
          child: Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.white.withOpacity(0.3))),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    // 融合版：全宽厚玻璃操作栏（bgHeavy 稳定可读）+ 顶部镜面发丝线
    final spec = GlassSpec.resolve(context, GlassTier.thick);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
        child: CustomPaint(
          foregroundPainter: GlassHairlinePainter(
            radius: 0,
            topColor: spec.topHighlight,
            bottomColor: Colors.transparent,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: spec.fill,
              border: Border(
                top: BorderSide(color: spec.border, width: 0.5),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 12,
              left: 20,
              right: 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('${widget.photo.dateTime.year}/${widget.photo.dateTime.month}/${widget.photo.dateTime.day}',
                    style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary)),
                ),
                GestureDetector(
                  onTap: _showDeleteConfirmation,
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    label: '删除照片',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: context.error.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadii.full)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: context.error),
                          4.wGap,
                          Text('删除', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: context.error)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSection(BuildContext context) {
    final scene = SceneClassifier.instance.labelFor(widget.photo.id);
    final place = SceneClassifier.readablePlace(widget.photo.location);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: AppRadii.lg,
        child: Column(
          children: [
            _metadataRow(context, Icons.calendar_today_outlined, '拍摄时间', _formatDate(widget.photo.dateTime)),
            Container(height: 1, color: context.divider),
            _metadataRow(context, Icons.landscape_outlined, '场景', scene ?? '未识别'),
            Container(height: 1, color: context.divider),
            // EXIF 里只有原始经纬度时不再当「地点」展示，避免出现 31.2304, 121.4737
            _metadataRow(context, Icons.place_outlined, '拍摄地点', place ?? '未记录'),
            Container(height: 1, color: context.divider),
            _metadataRow(context, Icons.storage_outlined, '文件大小', _formatFileSize(widget.photo.fileSize)),
            Container(height: 1, color: context.divider),
            _metadataRow(context, Icons.collections_outlined, '同月份照片', '${_allPhotos.where((p) => p.dateTime.month == widget.photo.dateTime.month && p.dateTime.year == widget.photo.dateTime.year).length} 张'),
          ],
        ),
      ),
    );
  }

  Widget _metadataRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textTertiary),
          8.wGap,
          Text(label, style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSimilarPhotosSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('相似照片', style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
          ),
          16.hGap,
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _similarPhotos.length,
              itemBuilder: (context, index) {
                final p = _similarPhotos[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < _similarPhotos.length - 1 ? 8 : 0),
                  child: Semantics(
                    button: true,
                    label: '相似照片 ${p.dateTime.month}月${p.dateTime.day}日',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSimilarPhotoTap(p);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: LocalImage(
                          path: p.thumbnailPath, width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80, height: 80,
                            decoration: const BoxDecoration(gradient: AppGradients.accentSoft),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    double value = bytes / 1024;
    for (final unit in units) {
      if (value < 1024) {
        // 小于 10 MB 保留 1 位小数，否则取整
        final formatted = value < 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
        return '$formatted $unit';
      }
      value /= 1024;
    }
    return '${value.toStringAsFixed(1)} TB';
  }
}

class _DeleteConfirmationSheet extends StatefulWidget {
  final Photo photo;
  final LocalRepository repository;
  final VoidCallback onDelete;

  const _DeleteConfirmationSheet({required this.photo, required this.repository, required this.onDelete});

  @override
  State<_DeleteConfirmationSheet> createState() => _DeleteConfirmationSheetState();
}

class _DeleteConfirmationSheetState extends State<_DeleteConfirmationSheet> {
  bool _dontAskAgain = false;

  void _onConfirm() {
    if (_dontAskAgain) widget.repository.setSkipDeleteConfirm(true);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return BottomBlurBar(
      title: '确认删除这张照片？',
      subtitle: '删除后无法恢复',
      icon: Icons.delete_outline,
      iconGradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B)]),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: LocalImage(
            path: widget.photo.thumbnailPath, width: double.infinity, height: 120, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120, color: context.surface,
              child: Center(child: Icon(Icons.image_outlined, color: context.textTertiary, size: 32)),
            ),
          ),
        ),
        AppSpacings.lg.hGap,
        GestureDetector(
          onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_dontAskAgain ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: context.textTertiary),
              6.wGap,
              Text('不再提醒', style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary)),
            ],
          ),
        ),
        AppSpacings.lg.hGap,
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: '取消',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            AppSpacings.md.wGap,
            Expanded(
              flex: 2,
              child: AppButton.danger(
                icon: Icons.delete_outline,
                label: '删除',
                onPressed: _onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
