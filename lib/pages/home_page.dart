import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../components/glass_card.dart';
import '../components/app_button.dart';
import '../components/shimmer_skeleton.dart';
import '../components/staggered_fade_in.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../services/image_helper.dart';
import '../services/scene_classifier_service.dart';
import '../app_state.dart';
import 'film_index_page.dart';
import 'slide_box_page.dart';
import 'watermark_page.dart';

class HomePage extends StatefulWidget {
  final LocalRepository repository;
  final VoidCallback onMagazineTap;
  final VoidCallback onScreenshotFilter;
  final VoidCallback onSettingsTap;
  final VoidCallback? onScanTap;
  final VoidCallback? onCleanupTap;
  final VoidCallback? onCuratedTap;
  final bool isScanning;
  final int scannedCount;
  final bool scanningComplete;
  final int scanTotal;

  const HomePage({
    super.key,
    required this.repository,
    required this.onMagazineTap,
    required this.onScreenshotFilter,
    required this.onSettingsTap,
    this.onScanTap,
    this.onCleanupTap,
    this.onCuratedTap,
    this.isScanning = false,
    this.scannedCount = 0,
    this.scanningComplete = false,
    this.scanTotal = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _totalPhotos = 0;
  int _organizedCount = 0;
  int _unorganizedCount = 0;
  int _curatedCount = 0;
  List<Photo> _recentMemories = [];
  Photo? _heroPhoto;
  Map<String, List<Photo>> _timelineGroups = {};
  int _lastDataVersion = 0;

  // 缓存：避免统计卡片点击时重新同步查 DB
  List<Photo> _cachedAllPhotos = [];
  List<Photo> _cachedOrganized = [];
  List<Photo> _cachedUnorganized = [];

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 扫描开始 / 扫描完成时才全量重算，扫描批次中仅由父级刷新进度文案
    if (oldWidget.scanningComplete != widget.scanningComplete ||
        oldWidget.isScanning != widget.isScanning) {
      _loadData();
      if (widget.scanningComplete) _classifyVisiblePhotos();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    SceneClassifier.instance.addListener(_onSceneChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().addListener(_onAppStateChanged);
      _classifyVisiblePhotos();
    });
  }

  @override
  void dispose() {
    SceneClassifier.instance.removeListener(_onSceneChanged);
    context.read<AppState>().removeListener(_onAppStateChanged);
    super.dispose();
  }

  /// 场景词识别完成后卡片副标题会从时间切换成场景，需要重绘。
  void _onSceneChanged() {
    if (mounted) setState(() {});
  }

  /// 先识别首屏可见的几张，再交给后台补齐最近的照片。
  void _classifyVisiblePhotos() {
    unawaited(_classifySequentially());
  }

  Future<void> _classifySequentially() async {
    final visible = <Photo>[
      if (_heroPhoto != null) _heroPhoto!,
      ..._recentMemories,
    ];
    // 串行执行：先首屏，再后台补齐，避免同一张图被并发推理两次
    await SceneClassifier.instance.classifyNow(visible);
    await SceneClassifier.instance.warmUp();
  }

  void _onAppStateChanged() {
    final appState = context.read<AppState>();
    if (_lastDataVersion != appState.dataVersion) {
      _lastDataVersion = appState.dataVersion;
      if (mounted) _loadData();
    }
  }

  void _loadData() {
    // 复制后再排序，避免原地修改仓库共享缓存
    final photos = [...widget.repository.getAllPhotos()]
      ..sort((a, b) => b.date.compareTo(a.date));
    _totalPhotos = photos.length;
    _cachedAllPhotos = photos;

    // 单次遍历统计 + 分类
    int organized = 0, curated = 0;
    final organizedList = <Photo>[];
    final unorganizedList = <Photo>[];
    for (final p in photos) {
      if (p.userMark.isNotEmpty) {
        organized++;
        organizedList.add(p);
      } else {
        unorganizedList.add(p);
      }
      if (p.isFavorite) curated++;
    }
    _organizedCount = organized;
    _unorganizedCount = _totalPhotos - organized;
    _curatedCount = curated;
    _cachedOrganized = organizedList;
    _cachedUnorganized = unorganizedList;

    _recentMemories = photos.take(8).toList();
    _heroPhoto = _getRandomMemoryPhoto(photos);
    _buildTimeline(organizedList);
    if (mounted) setState(() {});
  }

  Photo? _getRandomMemoryPhoto(List<Photo> photos) {
    final curated = photos.where((p) => p.isFavorite).toList();
    if (curated.isNotEmpty) {
      curated.shuffle();
      return curated.first;
    }
    final organized = photos.where((p) => p.userMark.isNotEmpty).toList();
    if (organized.isNotEmpty) {
      organized.shuffle();
      return organized.first;
    }
    return null;
  }

  /// 大图卡片副标题：场景词 / 可读地名 / 日期。
  /// 原始 GPS 坐标（形如 "31.2304, 121.4737"）没有可读性，直接不展示。
  String _heroSubtitle(Photo? photo) {
    if (photo == null) return '共 $_totalPhotos 张照片，记录生活的点滴';
    final parts = <String>[];
    final scene = SceneClassifier.instance.labelFor(photo.id);
    if (scene != null && scene.isNotEmpty) parts.add(scene);
    final place = SceneClassifier.readablePlace(photo.location);
    if (place != null) parts.add(place);
    parts.add('${photo.dateTime.month}月${photo.dateTime.day}日');
    return parts.join(' · ');
  }

  void _buildTimeline(List<Photo> organized) {
    _timelineGroups = {};
    for (final photo in organized) {
      final key = '${photo.dateTime.year}-${photo.dateTime.month.toString().padLeft(2, '0')}';
      _timelineGroups.putIfAbsent(key, () => []).add(photo);
    }
    final sortedKeys = _timelineGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    final newMap = <String, List<Photo>>{};
    for (final key in sortedKeys.take(6)) {
      newMap[key] = _timelineGroups[key]!;
    }
    _timelineGroups = newMap;
  }

  void _openSlideBoxWith(List<Photo> photos, {String title = '整理'}) {
    if (photos.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SlideBoxPage(
          photos: photos,
          repository: widget.repository,
          title: title,
          onBack: () => Navigator.of(context).pop(),
          onDataChanged: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 首次扫描且尚无数据时显示骨架屏
    if (widget.isScanning && _totalPhotos == 0) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
        child: Column(
          children: [
            12.hGap,
            _buildHeader(context),
            20.hGap,
            const ShimmerSkeleton.box(width: double.infinity, height: 260, radius: AppRadii.xl),
            24.hGap,
            Row(
              children: const [
                Expanded(child: ShimmerSkeleton.box(height: 80, radius: AppRadii.lg)),
                SizedBox(width: 12),
                Expanded(child: ShimmerSkeleton.box(height: 80, radius: AppRadii.lg)),
                SizedBox(width: 12),
                Expanded(child: ShimmerSkeleton.box(height: 80, radius: AppRadii.lg)),
              ],
            ),
            24.hGap,
            const ShimmerSkeleton.list(itemCount: 3, itemHeight: 80),
            96.hGap,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
      child: Column(
        children: [
          12.hGap,
          _buildHeader(context),
          20.hGap,
          StaggeredFadeIn(index: 0, child: _buildMemorySection(context)),
          24.hGap,
          StaggeredFadeIn(index: 1, child: _buildStatsSection(context)),
          24.hGap,
          StaggeredFadeIn(index: 2, child: _buildToolsSection(context)),
          24.hGap,
          StaggeredFadeIn(index: 3, child: _buildRecentSection(context)),
          24.hGap,
          _buildTimelineSection(context),
          96.hGap,
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('欢迎回来', style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary)),
            if (widget.isScanning) ...[
              2.hGap,
              Text(
                widget.scanTotal > 0
                    ? '已扫描 ${widget.scannedCount}/${widget.scanTotal} 张'
                    : '已扫描 ${widget.scannedCount} 张',
                style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent),
              ),
            ],
            2.gap,
            Text('拾光', style: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: AppFontWeights.light, color: context.textPrimary, letterSpacing: 2)),
          ],
        ),
        Row(
          children: [
            _iconBtn(context, Icons.settings_outlined, widget.onSettingsTap, tooltip: '设置'),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback? onTap, {String? tooltip}) {
    return Semantics(
      button: true,
      label: tooltip,
      child: AppButton.circle(
        icon: icon,
        onPressed: onTap,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.md,
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  区域1: 我的回忆
  // ──────────────────────────────────────────────

  Widget _buildMemorySection(BuildContext context) {
    final heroPhoto = _heroPhoto;
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '精选回忆，我的回忆',
        child: GestureDetector(
          onTap: widget.onCuratedTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onCuratedTap!();
                },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: [AppShadows.lgShadow(context)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity, height: 260,
                    child: heroPhoto != null
                        ? LocalImage(
                            // 大图用原图按屏幕解码，缩略图会糊
                            path: heroPhoto.path, fit: BoxFit.cover,
                            cacheWidth: resolveCacheSize(
                              MediaQuery.of(context).size.width,
                              MediaQuery.of(context).devicePixelRatio,
                            ),
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(gradient: AppGradients.accent),
                              child: Center(child: Icon(Icons.photo_album, size: 64, color: Colors.white.withOpacity(0.3))),
                            ),
                          )
                        : Image.asset(
                            'assets/hero-memories.jpg',
                            width: double.infinity,
                            height: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 260,
                              decoration: const BoxDecoration(gradient: AppGradients.accent),
                              child: Center(child: Icon(Icons.photo_album, size: 64, color: Colors.white.withOpacity(0.3))),
                            ),
                          ),
                  ),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, context.scrim.withOpacity(0.3), context.scrim],
                        stops: const [0, 0.3, 0.6, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: GlassColors.bg(context), borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: context.accent),
                              4.wGap,
                              Text('精选回忆', style: TextStyle(fontSize: AppFontSizes.xs, fontWeight: AppFontWeights.semibold, color: context.accent)),
                            ],
                          ),
                        ),
                        16.hGap,
                        Text('我的回忆', style: const TextStyle(fontSize: AppFontSizes.xxxl, fontWeight: AppFontWeights.light, color: Colors.white, height: 1.25, letterSpacing: -0.02)),
                        8.hGap,
                        Text(_heroSubtitle(heroPhoto),
                          style: TextStyle(fontSize: AppFontSizes.base, color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                  if (_curatedCount > 0)
                    Positioned(
                      top: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: GlassColors.bg(context),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite, size: 12, color: context.accent),
                            4.wGap,
                            Text('$_curatedCount', style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent, fontWeight: AppFontWeights.semibold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  区域2: 整理统计
  // ──────────────────────────────────────────────

  Widget _buildStatsSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _statCard(context, Icons.photo_library_outlined, '$_totalPhotos', '照片总数', context.accent, () {
            _openSlideBoxWith(_cachedAllPhotos, title: '全部照片');
          }),
        ),
        12.wGap,
        Expanded(
          child: _statCard(context, Icons.check_circle_outline, '$_organizedCount', '已整理', context.success, () {
            _openSlideBoxWith(_cachedOrganized, title: '已整理');
          }),
        ),
        12.wGap,
        Expanded(
          child: _statCard(context, Icons.pending_outlined, '$_unorganizedCount', '未整理', context.warning, () {
            _openSlideBoxWith(_cachedUnorganized, title: '未整理');
          }),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String value, String label, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: '$label，$value',
      child: GlassCard(
        padding: const EdgeInsets.all(12), borderRadius: AppRadii.lg,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            8.hGap,
            Text(value, style: TextStyle(fontSize: AppFontSizes.xl, fontWeight: AppFontWeights.semibold, color: context.textPrimary, height: 1.1)),
            2.hGap,
            Text(label, style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  区域3: 工具
  // ──────────────────────────────────────────────

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('工具', style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.md),
          borderRadius: AppRadii.lg,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FilmIndexPage(repository: widget.repository),
              ),
            );
          },
          child: Row(
            children: [
              Icon(Icons.photo_size_select_large_outlined, size: 20, color: context.accent),
              12.wGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('胶片索引', style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
                    2.hGap,
                    Text('按月浏览全部照片索引', style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: context.textTertiary),
            ],
          ),
        ),
        8.hGap,
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.md),
          borderRadius: AppRadii.lg,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WatermarkPage(repository: widget.repository),
              ),
            );
          },
          child: Row(
            children: [
              Icon(Icons.branding_watermark_outlined, size: 20, color: context.info),
              12.wGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('水印', style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
                    2.hGap,
                    Text('杂志风边框 · 相机时间地点水印', style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: context.textTertiary),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  区域4: 最近记忆
  // ──────────────────────────────────────────────

  Widget _buildRecentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('最近记忆', style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
              GestureDetector(
                onTap: widget.onMagazineTap,
                child: Row(
                  children: [
                    Text('查看全部', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: context.accent)),
                    2.wGap,
                    Icon(Icons.chevron_right, size: 16, color: context.accent),
                  ],
                ),
              ),
            ],
          ),
        ),
        16.hGap,
        SizedBox(
          height: 152,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _recentMemories.length,
            itemBuilder: (context, index) {
              final memory = _recentMemories[index];
              return Padding(
                padding: EdgeInsets.only(right: index < _recentMemories.length - 1 ? 12 : 0),
                child: _buildMemoryCard(context, memory),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryCard(BuildContext context, Photo photo) {
    final dateText = '${photo.dateTime.month}月${photo.dateTime.day}日';
    // 场景词（端侧识别）→ 可读地名 → 拍摄时间，都是真实数据；都没有则不显示
    final subtitle = SceneClassifier.instance.subtitleFor(photo);

    return Semantics(
      button: true,
      label: subtitle == null ? '$dateText照片' : '$dateText照片，$subtitle',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.read<AppState>().selectPhoto(photo);
        },
        child: SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Stack(
                  children: [
                    LocalImage(
                      path: photo.thumbnailPath, width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100,
                        decoration: const BoxDecoration(gradient: AppGradients.accentSoft),
                        child: Center(child: Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.5), size: 28)),
                      ),
                    ),
                    if (photo.isFavorite)
                      Positioned(
                        top: 4, right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.favorite, size: 10, color: AppColors.error),
                        ),
                      ),
                  ],
                ),
              ),
              8.hGap,
              Text(dateText,
                style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 10, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  区域4: 整理时间线
  // ──────────────────────────────────────────────

  Widget _buildTimelineSection(BuildContext context) {
    if (_timelineGroups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('整理时光', style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
        ),
        ..._timelineGroups.entries.toList().asMap().entries.map((e) =>
            StaggeredFadeIn(index: 4 + e.key, child: _buildTimelineGroup(context, e.value.key, e.value.value))),
      ],
    );
  }

  Widget _buildTimelineGroup(BuildContext context, String key, List<Photo> photos) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    final monthNames = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    final label = '$year ${monthNames[month - 1]}';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: '$label，${photos.length} 张，查看月刊',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onMagazineTap();
                },
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 16,
                      decoration: BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    10.wGap,
                    Text(label, style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
                    8.wGap,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.accent.withOpacity(AppOpacities.accentBg),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text('${photos.length}', style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent)),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: context.textTertiary),
                  ],
                ),
              ),
            ),
            12.hGap,
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: min(photos.length, 8),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                      button: true,
                      label: '${photo.dateTime.month}月${photo.dateTime.day}日照片',
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.read<AppState>().selectPhoto(photo);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: LocalImage(
                            path: photo.thumbnailPath, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80, height: 80, color: context.surface,
                              child: Icon(Icons.broken_image_outlined, size: 28, color: context.textTertiary),
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
      ),
    );
  }
}
