import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../components/bottom_blur_bar.dart';
import '../components/empty_state.dart';
import '../components/glass_card.dart';
import '../components/glass_icon_button.dart';
import '../components/shimmer_skeleton.dart';
import '../components/app_dialog.dart';
import '../components/app_button.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../services/album_archive_service.dart';
import '../services/album_service.dart';
import '../services/image_helper.dart';
import '../utils/photo_grouping.dart';
import '../app_state.dart';
import 'albums_tab.dart';
import 'apply_moves_page.dart';
import 'slide_box_page.dart';

class OrganizePage extends StatefulWidget {
  final LocalRepository repository;
  final ValueChanged<Photo> onPhotoTap;
  final bool isScanning;
  final int scannedCount;
  final bool scanningComplete;

  const OrganizePage({
    super.key,
    required this.repository,
    required this.onPhotoTap,
    this.isScanning = false,
    this.scannedCount = 0,
    this.scanningComplete = false,
  });

  @override
  State<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends State<OrganizePage> with SingleTickerProviderStateMixin {
  final GlobalKey<AlbumsTabState> _albumsKey = GlobalKey<AlbumsTabState>();
  late final AlbumService _albumService = AlbumService(widget.repository);
  late final AlbumArchiveService _archiveService = AlbumArchiveService(
    repository: widget.repository,
    albumService: _albumService,
  );
  late TabController _tabController;
  List<Photo> _allPhotos = [];

  // 缓存：避免 build 中重复计算 / 同步查 DB
  List<Photo> _cachedUnorganized = [];
  List<MonthGroup> _cachedMonthGroups = [];
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void didUpdateWidget(OrganizePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在扫描开始 / 扫描完成状态变化时重载，扫描批次中不重复全量计算
    if (oldWidget.isScanning != widget.isScanning ||
        oldWidget.scanningComplete != widget.scanningComplete) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    // 复制后再排序，避免原地排序仓库共享缓存
    _allPhotos = [...widget.repository.getAllPhotos()]..sort((a, b) => b.date.compareTo(a.date));

    // 预计算缓存，避免 build 中重复计算和同步查 DB
    _cachedUnorganized = _allPhotos.where((p) => p.userMark.isEmpty).toList();
    _cachedMonthGroups = groupPhotosByMonth(_cachedUnorganized);
    _pendingCount = widget.repository.totalPendingCount;

    if (mounted) setState(() {});
  }

  Future<void> _openApplyPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApplyMovesPage(
          repository: widget.repository,
          archiveService: _archiveService,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
    _loadData();
    _albumsKey.currentState?.refresh();
  }

  Widget _buildPendingBanner() {
    if (_pendingCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _openApplyPage,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.accent.withOpacity(AppOpacities.accentBg),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: context.accent.withOpacity(AppOpacities.accentBorder),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outline, size: 18, color: context.accent),
              10.wGap,
              Expanded(
                child: Text(
                  '$_pendingCount 张已整理，点这里写入系统相册',
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: AppFontWeights.medium,
                    color: context.accent,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: context.accent),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            TabBar(
              controller: _tabController,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(width: 3, color: context.accent),
                insets: const EdgeInsets.symmetric(horizontal: 24),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: context.accent,
              unselectedLabelColor: context.textTertiary,
              labelStyle: const TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium),
              tabs: const [
                Tab(text: '未整理'),
                Tab(text: '相簿'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUnorganizedTab(),
                  _buildAlbumsTab(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacings.xl, AppSpacings.xl, AppSpacings.xl, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('整理',
                style: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: AppFontWeights.light, color: context.textPrimary,
                  letterSpacing: 1)),
              4.hGap,
              Text('共 ${_allPhotos.length} 张照片 · ${_cachedUnorganized.length} 张未整理',
                style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
            ],
          ),
          GlassIconButton(
            icon: Icons.more_horiz,
            onTap: () => _showMoreMenu(),
            tooltip: '更多操作',
            iconSize: 18,
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    final hasManifest = widget.repository.getLatestMoveManifest() != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: context.overlay,
      builder: (ctx) => BottomBlurBar(
        children: [
          _menuItem(ctx, Icons.refresh, '刷新相簿列表', () {
            Navigator.pop(ctx);
            _albumsKey.currentState?.refresh();
          }),
          if (hasManifest)
            _menuItem(ctx, Icons.undo, '撤销上次写入系统相册', () {
              Navigator.pop(ctx);
              _rollbackLastBatch();
            }),
          _menuItem(ctx, Icons.info_outline, '关于整理', () {
            Navigator.pop(ctx);
            _showAboutOrganizing();
          }),
        ],
      ),
    );
  }

  Future<void> _rollbackLastBatch() async {
    final manifest = widget.repository.getLatestMoveManifest();
    if (manifest == null) return;
    final count = (manifest['originalPaths'] as Map?)?.length ?? 0;
    final ok = await AppDialog.confirm(
      context,
      title: '撤销上次整理',
      message: '把上次写入的 $count 张照片移回原目录，不删除任何照片。',
      confirmLabel: '撤销',
    );
    if (ok != true || !mounted) return;
    final outcome = await _archiveService.rollbackLatest();
    if (!mounted) return;
    if (outcome.moved > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('已还原 ${outcome.moved} 张到原目录'),
          behavior: SnackBarBehavior.floating,
        ));
    } else if (outcome.failed > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${outcome.failed} 张未能还原，可稍后重试'),
          behavior: SnackBarBehavior.floating,
        ));
    }
    await _albumsKey.currentState?.refresh();
  }

  Widget _menuItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: GlassColors.bg(context),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.textSecondary),
              12.wGap,
              Text(label, style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAboutOrganizing() async {
    await AppDialog.show(
      context,
      title: '关于整理',
      icon: Icons.info_outline,
      subtitle: '滑动与按钮操作说明',
      children: [
        Text(
          '上滑删除照片\n下滑标记保留\n左滑设为精选\n右滑回看上一张\n\n点击底部按钮也可快速操作',
          style: TextStyle(fontSize: AppFontSizes.sm, color: context.textSecondary, height: AppLineHeights.relaxed),
        ),
      ],
      actions: [
        AppButton.primary(
          label: '知道了',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  未整理 Tab
  // ──────────────────────────────────────────────

  Widget _buildUnorganizedTab() {
    final unorganized = _cachedUnorganized;

    // 首次扫描且尚无数据：显示骨架屏，避免误显示「已整理完成」
    if (widget.isScanning && _allPhotos.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            8.hGap,
            Text(
              widget.scannedCount > 0
                  ? '正在扫描照片… 已扫描 ${widget.scannedCount} 张'
                  : '正在扫描照片…',
              style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary),
            ),
            16.hGap,
            const ShimmerSkeleton.box(height: 200, radius: AppRadii.lg),
            16.hGap,
            const ShimmerSkeleton.list(itemCount: 3, itemHeight: 72, padding: EdgeInsets.zero),
            80.hGap,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPendingBanner(),
          // 清理建议 / 精选入口
          _buildToolEntries(),
          16.hGap,

          if (unorganized.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: Icons.check_circle_outline,
                tone: EmptyStateTone.success,
                title: '所有照片已整理完成',
              ),
            )
          else ...[
            // 最近未整理照片大图
            _buildRecentHero(unorganized.first),
            20.hGap,

            // 统计数据
            _buildStatRow(unorganized),
            16.hGap,

            // 月份分组
            Text('按月份', style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: context.textTertiary)),
            8.hGap,
            ..._cachedMonthGroups.map((g) => _buildMonthGroupCard(g)),
          ],
          80.hGap,
        ],
      ),
    );
  }

  Widget _buildToolEntries() {
    return Row(
      children: [
        Expanded(
          child: _toolEntryCard(
            icon: Icons.cleaning_services_outlined,
            label: '清理建议',
            color: context.warning,
            onTap: () => context.read<AppState>().showCleanupPage(),
          ),
        ),
        12.wGap,
        Expanded(
          child: _toolEntryCard(
            icon: Icons.favorite_outline,
            label: '精选',
            color: context.accent,
            onTap: () => context.read<AppState>().showCuratedPage(),
          ),
        ),
      ],
    );
  }

  Widget _toolEntryCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.md),
        borderRadius: AppRadii.lg,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            8.wGap,
            Expanded(
              child: Text(label, style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
            ),
            Icon(Icons.chevron_right, size: 16, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHero(Photo photo) {
    final now = DateTime.now();
    final isThisWeek = photo.dateTime.isAfter(now.subtract(const Duration(days: 7)));
    final label = isThisWeek ? '本周' : '${photo.dateTime.month}月${photo.dateTime.day}日';

    return Semantics(
      button: true,
      label: '最近未整理照片，开始整理',
      child: GestureDetector(
        onTap: () => _openSlideBoxWith(_cachedUnorganized),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: [AppShadows.lgShadow(context)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              LocalImage(
                path: photo.thumbnailPath, width: double.infinity, height: 200, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(gradient: AppGradients.accent),
                  child: const Center(child: Icon(Icons.photo_album, size: 48, color: Colors.white24)),
                ),
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [context.scrim, Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                bottom: 16, left: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GlassColors.bg(context),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: context.accent),
                          4.wGap,
                          Text(label, style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent, fontWeight: AppFontWeights.medium)),
                        ],
                      ),
                    ),
                    8.wGap,
                    Text('开始整理', style: const TextStyle(fontSize: AppFontSizes.base, color: Colors.white, fontWeight: AppFontWeights.medium)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(List<Photo> unorganized) {
    final videoCount = unorganized.where((p) => p.path.endsWith('.mp4') || p.path.endsWith('.mov')).length;
    final screenshotCount = unorganized.where((p) => p.category == '截图').length;

    return Column(
      children: [
        _statItem(context, '所有未整理', unorganized.length, null, () {
          _openSlideBoxWith(unorganized);
        }),
        if (videoCount > 0)
          _statItem(context, '未整理的视频', videoCount, null, () {
            _openSlideBoxWith(unorganized.where((p) => p.path.endsWith('.mp4') || p.path.endsWith('.mov')).toList());
          }),
        if (screenshotCount > 0)
          _statItem(context, '未整理的截图', screenshotCount, null, () {
            _openSlideBoxWith(unorganized.where((p) => p.category == '截图').toList());
          }),
        ..._cachedMonthGroups.take(6).map((g) {
          final now = DateTime.now();
          final isCurrentMonth = g.photos.first.dateTime.year == now.year && g.photos.first.dateTime.month == now.month;
          return _statItem(context, g.label, g.photos.length, isCurrentMonth, () {
            _openSlideBoxWith(g.photos);
          });
        }),
      ],
    );
  }

  Widget _statItem(BuildContext context, String label, int count, bool? isCurrentMonth, VoidCallback onTap) {
    final color = isCurrentMonth == true ? context.success : (isCurrentMonth == false ? context.accentSoft : null);
    return Semantics(
      button: true,
      label: '$label，$count 张',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.divider, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontSize: AppFontSizes.sm, color: context.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (color ?? context.accent).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text('$count', style: TextStyle(fontSize: AppFontSizes.xs, fontWeight: AppFontWeights.semibold, color: color ?? context.accent)),
              ),
              8.wGap,
              Icon(Icons.chevron_right, size: 16, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGroupCard(MonthGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.label, style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
              8.wGap,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.accent.withOpacity(AppOpacities.accentBg),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text('${group.photos.length}', style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent)),
              ),
            ],
          ),
          8.hGap,
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: min(group.photos.length, 6),
              itemBuilder: (context, index) {
                final photo = group.photos[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: LocalImage(
                      path: photo.thumbnailPath, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72, height: 72, color: context.surface,
                        child: Icon(Icons.broken_image_outlined, size: 24, color: context.textTertiary),
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

  void _openSlideBoxWith(List<Photo> photos) {
    if (photos.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SlideBoxPage(
          photos: photos,
          repository: widget.repository,
          title: '整理',
          onBack: () => Navigator.of(context).pop(),
          onDataChanged: _loadData,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  相簿 Tab
  // ──────────────────────────────────────────────

  Widget _buildAlbumsTab() {
    return AlbumsTab(
      key: _albumsKey,
      repository: widget.repository,
      onOpenPhotos: _openSlideBoxWith,
    );
  }
}
