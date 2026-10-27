import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_button.dart';
import '../components/app_dialog.dart';
import '../components/bottom_blur_bar.dart';
import '../components/empty_state.dart';
import '../components/glass_folder_card.dart';
import '../components/staggered_fade_in.dart';
import '../models/album.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../services/album_archive_service.dart';
import '../services/album_service.dart';
import '../services/photo_move_service.dart';
import '../theme.dart';
import 'apply_moves_page.dart';
import 'pick_photos_page.dart';

/// 相簿 Tab。
///
/// 「相簿 = 系统目录」：列表、计数、封面全部从 MediaStore 的 bucket 派生，
/// App 只保存名称/排序/草稿状态。整理结果通过「待应用队列」一次性写入系统。
class AlbumsTab extends StatefulWidget {
  final LocalRepository repository;
  final ValueChanged<List<Photo>> onOpenPhotos;

  const AlbumsTab({
    super.key,
    required this.repository,
    required this.onOpenPhotos,
  });

  @override
  State<AlbumsTab> createState() => AlbumsTabState();
}

class AlbumsTabState extends State<AlbumsTab> {
  late final AlbumService _albumService = AlbumService(widget.repository);
  late final AlbumArchiveService _archiveService = AlbumArchiveService(
    repository: widget.repository,
    albumService: _albumService,
  );

  List<AlbumEntry> _entries = const [];
  bool _loading = true;
  late bool _hideEmpty;
  bool _reorderMode = false;
  int _pendingTotal = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hideEmpty = widget.repository.getHideEmptyAlbums();
    _refresh();
  }

  /// 供外部（整理页「刷新相簿列表」）调用
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final entries = await _albumService.refresh();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _pendingTotal = widget.repository.totalPendingCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('[AlbumsTab] 刷新失败: $error');
    }
  }

  int get _emptyCount => _entries.where((e) => e.isEmpty).length;

  List<AlbumEntry> get _visibleEntries => _hideEmpty
      ? _entries.where((e) => !e.isEmpty).toList()
      : _entries;

  // ──────────────────────────────────────────────
  //  相簿操作
  // ──────────────────────────────────────────────

  Future<void> _createAlbum() async {
    final name = await AppDialog.input(
      context,
      title: '新建相簿',
      hint: '相簿名称',
      icon: Icons.create_new_folder_outlined,
      confirmLabel: '创建',
    );
    if (name == null || name.trim().isEmpty) return;
    final albumName = ArchivePaths.sanitizeAlbumName(name);
    final exists = _entries.any((e) => e.album.name == albumName);
    if (exists) {
      _toast('已存在同名相簿');
      return;
    }
    widget.repository.saveAlbum(Album(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: albumName,
      order: _entries.length,
    ));
    await _refresh();
    if (!mounted) return;
    _toast('相簿已创建，整理时把照片拖进来即可落盘');
  }

  Future<void> _renameAlbum(AlbumEntry entry) async {
    final name = await AppDialog.input(
      context,
      title: '重命名',
      hint: '相簿名称',
      initialValue: entry.album.name,
      icon: Icons.edit_outlined,
      confirmLabel: '保存',
    );
    if (name == null || name.trim().isEmpty) return;
    final nextName = ArchivePaths.sanitizeAlbumName(name);
    if (nextName == entry.album.name) return;

    // 草稿相簿只改名字，不涉及文件
    if (!entry.album.isPhysical) {
      widget.repository.saveAlbum(entry.album.copyWith(name: nextName));
      await _refresh();
      return;
    }

    final targetDir = ArchivePaths.albumDir(nextName);
    final targetNorm = ArchivePaths.normalize(targetDir);
    if (_entries.any((e) => ArchivePaths.normalize(e.album.relativePath ?? '') == targetNorm)) {
      _toast('已存在同名目录，请换一个名字');
      return;
    }
    if (entry.count > 0) {
      final ok = await _confirm(
        title: '重命名相簿',
        message: '${entry.count} 张照片会移动到「$nextName」目录，不占额外空间。',
        confirmLabel: '重命名',
      );
      if (!ok) return;
      await _runBusy(() async {
        final outcome = await _archiveService.moveAlbumTo(entry.album, targetDir);
        if (outcome.failed > 0) {
          if (mounted) _toast('${outcome.failed} 张未能移动，已保留原目录');
          return;
        }
        entry.album
          ..name = nextName
          ..relativePath = targetNorm;
        widget.repository.saveAlbum(entry.album);
      });
    } else {
      entry.album
        ..name = nextName
        ..relativePath = targetNorm;
      widget.repository.saveAlbum(entry.album);
    }
    await _refresh();
  }

  Future<void> _addPhotos(AlbumEntry entry) async {
    final all = [...widget.repository.getAllPhotos()]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (all.isEmpty) {
      _toast('还没有可添加的照片');
      return;
    }
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => PickPhotosPage(
          photos: all,
          albumName: entry.album.name,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    for (final id in picked) {
      widget.repository.addPendingMove(entry.album.id, id);
    }
    await _refresh();
    if (!mounted) return;
    _toast('已加入 ${picked.length} 张，点上方横幅写入系统相册');
  }

  Future<void> _deleteAlbum(AlbumEntry entry) async {
    if (entry.count == 0 && entry.pending == 0) {
      await _doDelete(entry, deletePhotos: false);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: context.overlay,
      builder: (ctx) => BottomBlurBar(
        children: [
          Text(
            '删除「${entry.album.name}」',
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: AppFontWeights.medium,
              color: context.textPrimary,
            ),
          ),
          8.hGap,
          Text(
            entry.count > 0
                ? '相簿内有 ${entry.count} 张照片，请选择处理方式'
                : '相簿内暂无照片，仅有 ${entry.pending} 张待应用',
            style: TextStyle(fontSize: AppFontSizes.sm, color: context.textSecondary),
          ),
          20.hGap,
          _sheetOption(
            ctx,
            icon: Icons.folder_outlined,
            title: '仅删除相簿',
            subtitle: entry.count > 0 ? '照片移回 DCIM/Camera，不删除' : '照片保留在原处',
            color: context.info,
            onTap: () {
              Navigator.pop(ctx);
              _doDelete(entry, deletePhotos: false);
            },
          ),
          8.hGap,
          if (entry.count > 0)
            _sheetOption(
              ctx,
              icon: Icons.delete_outline,
              title: '同时删除照片',
              subtitle: '删除 ${entry.count} 张照片，不可恢复',
              color: context.error,
              onTap: () {
                Navigator.pop(ctx);
                _doDelete(entry, deletePhotos: true);
              },
            ),
        ],
      ),
    );
  }

  Widget _sheetOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: GlassColors.bg(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            12.wGap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppFontSizes.base,
                      fontWeight: AppFontWeights.medium,
                      color: context.textPrimary,
                    ),
                  ),
                  2.hGap,
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doDelete(AlbumEntry entry, {required bool deletePhotos}) async {
    await _runBusy(() async {
      if (entry.count > 0) {
        if (deletePhotos) {
          final bucket = entry.bucket;
          if (bucket != null) {
            final photos = await _albumService.photosInBucket(bucket);
            await widget.repository.deletePhotos(
              photos.map((photo) => photo.id).toList(),
            );
          }
        } else {
          await _archiveService.moveAlbumTo(entry.album, 'DCIM/Camera');
        }
      }
      widget.repository.deleteAlbum(entry.album.id);
    });
    await _refresh();
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      debugPrint('[AlbumsTab] 操作失败: $error');
      if (mounted) _toast('操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: context.overlay,
      builder: (ctx) => BottomBlurBar(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: AppFontWeights.medium,
              color: context.textPrimary,
            ),
          ),
          8.hGap,
          Text(
            message,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              color: context.textSecondary,
              height: AppLineHeights.relaxed,
            ),
          ),
          20.hGap,
          AppButton.primary(
            label: confirmLabel,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          8.hGap,
          AppButton.secondary(
            label: '取消',
            onPressed: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _openAlbum(AlbumEntry entry) async {
    if (entry.pending > 0 && entry.count == 0) {
      _toast('有 ${entry.pending} 张待应用，先点上方「写入系统相册」');
      return;
    }
    final bucket = entry.bucket;
    if (bucket == null) {
      _toast('相簿还没有照片，整理时把照片拖进来');
      return;
    }
    final photos = await _albumService.photosInBucket(bucket);
    if (photos.isEmpty) {
      _toast('相簿为空');
      return;
    }
    widget.onOpenPhotos(photos);
  }

  void _openApplyPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApplyMovesPage(
          repository: widget.repository,
          archiveService: _archiveService,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
    await _refresh();
  }

  void _reorder(AlbumEntry dragged, AlbumEntry target) {
    final oldIndex = _entries.indexWhere((e) => e.album.id == dragged.album.id);
    final newIndex = _entries.indexWhere((e) => e.album.id == target.album.id);
    if (oldIndex < 0 || newIndex < 0 || oldIndex == newIndex) return;
    setState(() {
      final list = [..._entries];
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _entries = list;
      widget.repository.reorderAlbums([for (final e in list) e.album]);
    });
    HapticFeedback.selectionClick();
  }

  // ──────────────────────────────────────────────
  //  UI
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: context.accent),
        ),
      );
    }

    final entries = _visibleEntries;

    return Stack(
      children: [
        Column(
          children: [
            _buildToolbar(context),
            if (_pendingTotal > 0) _buildPendingBanner(context),
            Expanded(
              child: entries.isEmpty && _entries.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        const EmptyState(
                          icon: Icons.photo_album_outlined,
                          title: '暂无相簿',
                          subtitle: '点击下方按钮新建相簿',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
                          child: OutlinedButton.icon(
                            onPressed: _createAlbum,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('新建相簿'),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacings.xl,
                        AppSpacings.md,
                        AppSpacings.xl,
                        80,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: entries.length + 1,
                      itemBuilder: (context, index) {
                        if (index == entries.length) return _buildCreateCard();
                        return _buildAlbumCard(entries[index], index);
                      },
                    ),
            ),
          ],
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: context.overlay,
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: context.accent),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacings.xl, AppSpacings.sm, AppSpacings.xl, 0),
      child: Row(
        children: [
          Text(
            _reorderMode
                ? '拖动卡片调整顺序'
                : '${_entries.length} 个相簿${_hideEmpty && _emptyCount > 0 ? ' · 已隐藏 $_emptyCount 个空相簿' : ''}',
            style: TextStyle(
              fontSize: AppFontSizes.xs,
              color: _reorderMode ? context.accent : context.textTertiary,
            ),
          ),
          const Spacer(),
          if (_entries.length > 1)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _reorderMode = !_reorderMode);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _reorderMode ? '完成' : '排序',
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: _reorderMode ? context.accent : context.textTertiary,
                  ),
                ),
              ),
            ),
          if (_emptyCount > 0 && !_reorderMode)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _hideEmpty = !_hideEmpty);
                widget.repository.setHideEmptyAlbums(_hideEmpty);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _hideEmpty
                      ? context.accent.withOpacity(AppOpacities.accentBg)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(
                    color: _hideEmpty
                        ? context.accent.withOpacity(AppOpacities.accentBorder)
                        : GlassColors.borderSubtle(context),
                  ),
                ),
                child: Text(
                  '隐藏空相簿',
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: _hideEmpty ? context.accent : context.textTertiary,
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh, size: 18, color: context.textTertiary),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacings.xl, AppSpacings.sm, AppSpacings.xl, 0),
      child: GestureDetector(
        onTap: _openApplyPage,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.accent.withOpacity(AppOpacities.accentBg),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: context.accent.withOpacity(AppOpacities.accentBorder)),
          ),
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outline, size: 18, color: context.accent),
              10.wGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_pendingTotal 张待写入系统相册',
                      style: TextStyle(
                        fontSize: AppFontSizes.sm,
                        fontWeight: AppFontWeights.medium,
                        color: context.accent,
                      ),
                    ),
                    2.hGap,
                    Text(
                      '只改目录，不占额外空间',
                      style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: context.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumCard(AlbumEntry entry, int index) {
    final album = entry.album;
    final covers = [
      for (final id in entry.coverIds)
        widget.repository.getPhoto(id)?.thumbnailPath,
    ];
    final meta = entry.pending > 0
        ? '${entry.count} 张 · 待应用 ${entry.pending}'
        : '${entry.count} 张';
    final card = GlassFolderCard(
      label: album.name,
      meta: meta,
      covers: covers,
      isLocalSync: album.isPhysical,
      onTap: _reorderMode ? null : () => _openAlbum(entry),
      onMore: _reorderMode
          ? null
          : () {
              HapticFeedback.selectionClick();
              _showAlbumActions(entry);
            },
      // 长按 → 操作菜单（排序模式下让位给拖动）
      onLongPress: _reorderMode
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _showAlbumActions(entry);
            },
    );
    final effectiveCard = entry.count == 0 ? Opacity(opacity: 0.65, child: card) : card;

    final tileW = (MediaQuery.of(context).size.width - AppSpacings.xl * 2 - 16) / 2;
    final tileH = tileW / 1.35;

    return StaggeredFadeIn(
      index: index,
      child: Semantics(
        button: true,
        label: '相簿 ${album.name}，${entry.count} 张',
        child: _reorderMode
            ? _buildReorderableCard(entry, meta, covers, effectiveCard, tileW, tileH)
            : effectiveCard,
      ),
    );
  }

  /// 排序模式：卡片直接拖动换位（无需长按，长按留给操作菜单）
  Widget _buildReorderableCard(
    AlbumEntry entry,
    String meta,
    List<String?> covers,
    Widget card,
    double tileW,
    double tileH,
  ) {
    final album = entry.album;
    return DragTarget<AlbumEntry>(
      onWillAcceptWithDetails: (details) => details.data.album.id != album.id,
      onAcceptWithDetails: (details) => _reorder(details.data, entry),
      builder: (context, candidate, _) {
        return Draggable<AlbumEntry>(
          data: entry,
          maxSimultaneousDrags: 1,
          onDragStarted: () => HapticFeedback.mediumImpact(),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          feedback: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: tileW,
              height: tileH,
              child: GlassFolderCard(
                label: album.name,
                meta: meta,
                covers: covers,
                isLocalSync: album.isPhysical,
                highlighted: true,
              ),
            ),
          ),
          child: candidate.isNotEmpty
              ? GlassFolderCard(
                  label: album.name,
                  meta: meta,
                  covers: covers,
                  isLocalSync: album.isPhysical,
                  highlighted: true,
                )
              : card,
        );
      },
    );
  }

  Widget _buildCreateCard() {
    return GlassFolderCard(
      label: '新建相簿',
      meta: '点击创建',
      emphasized: true,
      onTap: _createAlbum,
    );
  }

  void _showAlbumActions(AlbumEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: context.overlay,
      builder: (ctx) => BottomBlurBar(
        children: [
          Text(
            entry.album.name,
            style: TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: AppFontWeights.medium,
              color: context.textPrimary,
            ),
          ),
          8.hGap,
          Text(
            entry.album.isPhysical
                ? '${entry.count} 张 · ${entry.album.relativePath}'
                : '草稿相簿 · 暂无照片',
            style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
          ),
          16.hGap,
          _sheetOption(
            ctx,
            icon: Icons.add_photo_alternate_outlined,
            title: '添加照片',
            subtitle: '从现有照片中多选，稍后统一落盘',
            color: context.accent,
            onTap: () {
              Navigator.pop(ctx);
              _addPhotos(entry);
            },
          ),
          8.hGap,
          _sheetOption(
            ctx,
            icon: Icons.edit_outlined,
            title: '重命名',
            subtitle: entry.album.isPhysical ? '照片会跟随目录改名' : '仅修改相簿名称',
            color: context.info,
            onTap: () {
              Navigator.pop(ctx);
              _renameAlbum(entry);
            },
          ),
          8.hGap,
          _sheetOption(
            ctx,
            icon: Icons.delete_outline,
            title: '删除相簿',
            subtitle: '可选保留或同时删除照片',
            color: context.error,
            onTap: () {
              Navigator.pop(ctx);
              _deleteAlbum(entry);
            },
          ),
        ],
      ),
    );
  }
}
