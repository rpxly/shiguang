import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../components/empty_state.dart';
import '../components/app_dialog.dart';
import '../components/app_button.dart';
import '../components/loading_overlay.dart';
import '../models/photo.dart';
import '../models/album.dart';
import '../repository/local_repository.dart';
import '../services/image_helper.dart';
import '../services/scene_classifier_service.dart';
import '../components/app_background.dart';

enum _SwipeAction { none, delete, favorite, keep }

enum _UndoAction { delete, favorite, keep, album }

/// 单次操作的撤销记录
class _UndoEntry {
  final _UndoAction action;
  final Photo photo;
  final int index;
  final String prevMark;
  final bool prevFavorite;
  final String? albumId;

  _UndoEntry({
    required this.action,
    required this.photo,
    required this.index,
    required this.prevMark,
    required this.prevFavorite,
    this.albumId,
  });
}

class SlideBoxPage extends StatefulWidget {
  final List<Photo> photos;
  final LocalRepository repository;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onDataChanged;

  const SlideBoxPage({
    super.key,
    required this.photos,
    required this.repository,
    this.title = '整理',
    required this.onBack,
    required this.onDataChanged,
  });

  @override
  State<SlideBoxPage> createState() => _SlideBoxPageState();
}

class _SlideBoxPageState extends State<SlideBoxPage> with TickerProviderStateMixin {
  late List<Photo> _photos;
  int _currentIndex = 0;
  final List<Photo> _deleteQueue = [];
  final List<_UndoEntry> _history = [];
  int _processedCount = 0;

  Offset _dragOffset = Offset.zero;
  _SwipeAction _swipeAction = _SwipeAction.none;
  bool _isAnimating = false;
  bool _isDeleting = false;
  double _opacity = 1.0;
  double _horizontalShift = 0.0;

  List<Album> _albums = [];

  static const double _deleteThreshold = -120;
  static const double _keepThreshold = 120;
  static const double _favoriteThreshold = 80;
  static const double _horizontalThreshold = 80;

  Photo? get _currentPhoto => _currentIndex < _photos.length ? _photos[_currentIndex] : null;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _albums = widget.repository.getAllAlbums();
  }

  void _prevPhoto() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _resetGesture();
    }
  }

  void _nextPhoto() {
    if (_currentIndex < _photos.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _resetGesture();
    } else {
      widget.onDataChanged();
      widget.onBack();
    }
  }

  void _deleteCurrent() {
    if (_currentPhoto == null) return;
    final photo = _currentPhoto!;
    setState(() {
      _deleteQueue.add(photo);
      _history.add(_UndoEntry(
        action: _UndoAction.delete,
        photo: photo,
        index: _currentIndex,
        prevMark: photo.userMark,
        prevFavorite: photo.isFavorite,
      ));
      _processedCount++;
      _photos.removeAt(_currentIndex);
    });
    widget.repository.recordOrganized(1);
    if (_photos.isEmpty) {
      _performDelete();
    } else {
      _resetGesture();
      _showDeleteUndoSnackBar();
    }
  }

  void _showDeleteUndoSnackBar() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('已放入待删除（${_deleteQueue.length}）', style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
        action: SnackBarAction(
          label: '撤销',
          onPressed: _undoLast,
        ),
      ));
  }

  void _favoriteCurrent() {
    if (_currentPhoto == null) return;
    final photo = _currentPhoto!;
    widget.repository.savePhoto(photo.copyWith(
      isFavorite: true,
      userMark: 'keep',
    ));
    widget.repository.recordOrganized(1);
    _history.add(_UndoEntry(
      action: _UndoAction.favorite,
      photo: photo,
      index: _currentIndex,
      prevMark: photo.userMark,
      prevFavorite: photo.isFavorite,
    ));
    _processedCount++;
    _nextPhoto();
  }

  void _keepCurrent() {
    if (_currentPhoto == null) return;
    final photo = _currentPhoto!;
    widget.repository.savePhoto(photo.copyWith(
      userMark: 'keep',
    ));
    widget.repository.recordOrganized(1);
    _history.add(_UndoEntry(
      action: _UndoAction.keep,
      photo: photo,
      index: _currentIndex,
      prevMark: photo.userMark,
      prevFavorite: photo.isFavorite,
    ));
    _processedCount++;
    _nextPhoto();
  }

  /// 撤销上一次操作（删除/精选/保留/归类）
  void _undoLast() {
    if (_history.isEmpty) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final entry = _history.removeLast();
    widget.repository.recordOrganized(-1);
    setState(() {
      // 所有动作类型都要同步回退进度并刷新界面
      _processedCount = max(0, _processedCount - 1);
      switch (entry.action) {
        case _UndoAction.delete:
          _deleteQueue.remove(entry.photo);
          final idx = _currentIndex.clamp(0, _photos.length);
          _photos.insert(idx, entry.photo);
          _resetGesture();
        case _UndoAction.favorite || _UndoAction.keep:
          widget.repository.savePhoto(entry.photo.copyWith(
            userMark: entry.prevMark,
            isFavorite: entry.prevFavorite,
          ));
        case _UndoAction.album:
          if (entry.albumId != null) {
            widget.repository.removePendingMoves(entry.albumId!, [entry.photo.id]);
          }
          widget.repository.savePhoto(entry.photo.copyWith(userMark: entry.prevMark));
      }
    });
  }

  void _resetGesture() {
    setState(() {
      _dragOffset = Offset.zero;
      _horizontalShift = 0;
      _swipeAction = _SwipeAction.none;
      _opacity = 1.0;
      _isAnimating = false;
    });
  }

  Future<void> _performDelete() async {
    if (_deleteQueue.isEmpty) return;
    setState(() => _isDeleting = true);
    try {
      await widget.repository.deletePhotos(_deleteQueue.map((p) => p.id).toList());
      _deleteQueue.clear();
      widget.onDataChanged();
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _addToAlbum(Album album) {
    if (_currentPhoto == null) return;
    final photo = _currentPhoto!;
    widget.repository.addPendingMove(album.id, photo.id);
    widget.repository.savePhoto(photo.copyWith(userMark: 'keep'));
    widget.repository.recordOrganized(1);
    _history.add(_UndoEntry(
      action: _UndoAction.album,
      photo: photo,
      index: _currentIndex,
      prevMark: photo.userMark,
      prevFavorite: photo.isFavorite,
      albumId: album.id,
    ));
    _processedCount++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加到「${album.name}」', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    _nextPhoto();
  }

  /// 滑卡过程中直接新建相簿
  Future<void> _createAlbumInline() async {
    final name = await AppDialog.input(
      context,
      title: '新建相簿',
      hint: '相簿名称',
      icon: Icons.create_new_folder_outlined,
      confirmLabel: '创建',
    );
    if (name == null || name.isEmpty || !mounted) return;
    final album = Album(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      order: _albums.length,
    );
    widget.repository.saveAlbum(album);
    setState(() => _albums = widget.repository.getAllAlbums());
  }

  void _showExitConfirmDialog() {
    AppDialog.show(
      context,
      title: '确认退出？',
      subtitle: '有 ${_deleteQueue.length} 张照片标记了删除',
      icon: Icons.exit_to_app,
      iconGradient: const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)]),
      children: const [SizedBox.shrink()],
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton.danger(
              icon: Icons.delete_outline,
              label: '删除并退出',
              onPressed: () {
                Navigator.of(context).pop();
                _performDelete();
                widget.onDataChanged();
                widget.onBack();
              },
            ),
            AppSpacings.md.hGap,
            AppButton.secondary(
              label: '不删除直接退出',
              onPressed: () {
                Navigator.of(context).pop();
                _deleteQueue.clear();
                widget.onDataChanged();
                widget.onBack();
              },
            ),
            AppSpacings.md.hGap,
            AppButton(
              variant: AppButtonVariant.ghost,
              shape: AppButtonShape.pill,
              size: AppButtonSize.lg,
              expand: true,
              label: '继续整理',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _horizontalShift += details.delta.dx;
      _dragOffset = Offset(0, _dragOffset.dy + details.delta.dy);
      _swipeAction = _getSwipeAction();
      _opacity = max(0.3, 1.0 - (max(_dragOffset.dy.abs(), _horizontalShift.abs()) / 300));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final dx = _horizontalShift.abs();
    final dy = _dragOffset.dy.abs();

    if (dx > dy) {
      if (_horizontalShift < -_favoriteThreshold) {
        // 左滑精选
        HapticFeedback.selectionClick();
        _animateHorizontal(-300, _favoriteCurrent);
      } else if (_horizontalShift > _horizontalThreshold) {
        // 右滑回看上一张
        _animateHorizontal(300, _prevPhoto);
      } else {
        _resetGesture();
      }
    } else if (_dragOffset.dy < _deleteThreshold) {
      HapticFeedback.heavyImpact();
      _animateVertical(_SwipeAction.delete);
    } else if (_dragOffset.dy > _keepThreshold) {
      HapticFeedback.mediumImpact();
      _animateVertical(_SwipeAction.keep);
    } else {
      _resetGesture();
    }
  }

  void _animateHorizontal(double targetDx, VoidCallback onComplete) {
    _isAnimating = true;
    _horizontalShift = targetDx;
    _dragOffset = Offset.zero;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      onComplete();
      _isAnimating = false;
    });
  }

  void _animateVertical(_SwipeAction action) {
    _isAnimating = true;
    final targetDy = action == _SwipeAction.delete ? -300.0 : 300.0;
    _dragOffset = Offset(0, targetDy);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      switch (action) {
        case _SwipeAction.delete:
          _deleteCurrent();
        case _SwipeAction.favorite:
          _favoriteCurrent();
        case _SwipeAction.keep:
          _keepCurrent();
        default:
          _resetGesture();
      }
      _isAnimating = false;
    });
  }

  _SwipeAction _getSwipeAction() {
    final dx = _horizontalShift.abs();
    final dy = _dragOffset.dy.abs();
    if (dx > dy) {
      // 左滑精选；右滑仅用于回看，不触发动作
      if (_horizontalShift < -_favoriteThreshold) return _SwipeAction.favorite;
      return _SwipeAction.none;
    }
    if (_dragOffset.dy < _deleteThreshold) return _SwipeAction.delete;
    if (_dragOffset.dy > _keepThreshold) return _SwipeAction.keep;
    return _SwipeAction.none;
  }

  String _getActionIndicator() {
    switch (_getSwipeAction()) {
      case _SwipeAction.delete:
        return '🗑️  删除';
      case _SwipeAction.favorite:
        return '❤️  精选';
      case _SwipeAction.keep:
        return '✓  保留';
      default:
        return '';
    }
  }

  Color _getActionColor() {
    switch (_swipeAction) {
      case _SwipeAction.delete:
        return AppColors.error;
      case _SwipeAction.favorite:
        return context.success;
      case _SwipeAction.keep:
        return context.info;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _currentPhoto;

    return GlassScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildPhotoArea(photo)),
                _buildActionButtons(),
                if (_albums.isNotEmpty) _buildAlbumBar(),
              ],
            ),
            if (_isDeleting) const LoadingOverlay(message: '正在删除...'),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final total = widget.photos.length;
    final progress = total == 0 ? 1.0 : min(_processedCount, total) / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.sm),
      child: Row(
        children: [
          AppButton.circle(
            icon: Icons.close,
            onPressed: () {
              if (_deleteQueue.isNotEmpty) {
                _showExitConfirmDialog();
              } else {
                widget.onDataChanged();
                widget.onBack();
              }
            },
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.md,
          ),
          12.wGap,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: context.textPrimary),
                ),
                4.hGap,
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: context.divider,
                          valueColor: AlwaysStoppedAnimation(context.accent),
                        ),
                      ),
                    ),
                    8.wGap,
                    Text(
                      '${min(_processedCount, total)} / $total',
                      style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
                    ),
                  ],
                ),
                2.hGap,
                Text(
                  '今日已整理 ${widget.repository.getOrganizedTodayCount()} 张',
                  style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
                ),
              ],
            ),
          ),
          12.wGap,
          if (_history.isNotEmpty)
            AppButton.circle(
              icon: Icons.undo,
              onPressed: _undoLast,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.md,
            ),
          if (_deleteQueue.isNotEmpty) ...[
            8.wGap,
            GestureDetector(
              onTap: _performDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.xs),
                decoration: BoxDecoration(
                  color: context.error.withOpacity(AppOpacities.accentBg),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 14, color: context.error),
                    4.wGap,
                    Text('${_deleteQueue.length}',
                      style: TextStyle(
                        fontSize: AppFontSizes.xs,
                        color: context.error,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoArea(Photo? photo) {
    if (photo == null) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        iconSize: 64,
        tone: EmptyStateTone.success,
        title: '全部整理完成！',
        subtitle: '共处理 ${widget.photos.length} 张照片',
      );
    }

    final action = _getSwipeAction();
    final showIndicator = action != _SwipeAction.none;
    final dragMagnitude = max(_dragOffset.dy.abs(), _horizontalShift.abs()).toDouble();

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        children: [
          // 背景色：拖拽时即时，动画时过渡
          if (_isAnimating)
            AnimatedContainer(
              duration: AppTransitions.fast,
              color: _swipeAction == _SwipeAction.none
                  ? Colors.transparent
                  : _getActionColor().withOpacity(min(0.15, dragMagnitude / 800)),
            )
          else
            ColoredBox(
              color: _swipeAction == _SwipeAction.none
                  ? Colors.transparent
                  : _getActionColor().withOpacity(min(0.15, dragMagnitude / 800)),
            ),
          Center(
            child: RepaintBoundary(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 下一张卡片从背后露出，暗示还有内容
                  if (_currentIndex + 1 < _photos.length)
                    Transform.translate(
                      offset: const Offset(0, -14),
                      child: Transform.rotate(
                        angle: 0.04,
                        child: Transform.scale(
                          scale: 0.94,
                          child: _photoCard(_photos[_currentIndex + 1]),
                        ),
                      ),
                    ),
                  _isAnimating
                      ? AnimatedContainer(
                          duration: AppTransitions.fast,
                          transform: Matrix4.translationValues(_horizontalShift, _dragOffset.dy, 0),
                          child: Opacity(
                            opacity: _opacity,
                            child: _photoCard(photo),
                          ),
                        )
                      : Transform.translate(
                          offset: Offset(_horizontalShift, _dragOffset.dy),
                          child: Opacity(
                            opacity: _opacity,
                            child: _photoCard(photo),
                          ),
                        ),
                ],
              ),
            ),
          ),
          if (showIndicator)
            Positioned.fill(
              child: Align(
                // 指示器位置跟随滑动方向：上滑删除→顶部，下滑保留→底部，左滑精选→左侧
                alignment: switch (_swipeAction) {
                  _SwipeAction.delete => Alignment.topCenter,
                  _SwipeAction.keep => Alignment.bottomCenter,
                  _SwipeAction.favorite => Alignment.centerLeft,
                  _ => Alignment.center,
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    top: _swipeAction == _SwipeAction.delete ? 40 : 0,
                    bottom: _swipeAction == _SwipeAction.keep ? 40 : 0,
                    left: _swipeAction == _SwipeAction.favorite ? 32 : 0,
                  ),
                  child: _isAnimating
                      ? AnimatedOpacity(
                          opacity: min(1.0, dragMagnitude / 100),
                          duration: AppTransitions.fast,
                          child: _indicatorChip(),
                        )
                      : Opacity(
                          opacity: min(1.0, dragMagnitude / 100),
                          child: _indicatorChip(),
                        ),
                ),
              ),
            ),
          if (_currentPhoto != null)
            Positioned(
              bottom: 12, left: 24, right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(AppOpacities.whiteOverlay)),
                  4.wGap,
                  Text(
                    '${photo.dateTime.year}年${photo.dateTime.month}月${photo.dateTime.day}日',
                    style: TextStyle(fontSize: AppFontSizes.xs, color: Colors.white.withOpacity(AppOpacities.whiteOverlay)),
                  ),
                  if (SceneClassifier.instance.placeLabelFor(photo) != null) ...[
                    8.wGap,
                    Icon(Icons.location_on, size: 12, color: Colors.white.withOpacity(AppOpacities.whiteOverlay)),
                    4.wGap,
                    Text(SceneClassifier.instance.placeLabelFor(photo)!, style: TextStyle(fontSize: AppFontSizes.xs, color: Colors.white.withOpacity(AppOpacities.whiteOverlay))),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 照片卡片（图片+阴影+圆角），拖拽与动画共用
  Widget _photoCard(Photo? photo) {
    if (photo == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [AppShadows.lgShadow(context)],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 0.75,
        // 用原图按屏幕尺寸解码（缩略图仅 256/512px，铺满卡片会糊掉文字）
        child: LocalImage(
          path: photo.path,
          fit: BoxFit.cover,
          cacheWidth: resolveCacheSize(
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).devicePixelRatio,
          ),
          errorBuilder: (_, __, ___) => Container(
            color: context.surface,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, size: 48, color: context.textTertiary),
                  8.hGap,
                  Text('图片加载失败', style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 滑动指示器胶囊
  Widget _indicatorChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _getActionColor().withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        _getActionIndicator(),
        style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.semibold, color: Colors.white),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xxl, vertical: AppSpacings.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionBtn(context, '精选', Icons.favorite, context.success, _favoriteCurrent),
          _actionBtn(context, '保留', Icons.check_circle_outline, context.info, _keepCurrent),
          _actionBtn(context, '删除', Icons.delete_outline, context.error, _deleteCurrent),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.sm),
        decoration: BoxDecoration(
          color: GlassColors.bg(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: GlassColors.borderSubtle(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            4.hGap,
            Text(label, style: TextStyle(fontSize: AppFontSizes.xs, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacings.lg,
        right: AppSpacings.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacings.sm,
        top: AppSpacings.sm,
      ),
      decoration: BoxDecoration(
        color: GlassColors.bg(context),
        border: Border(top: BorderSide(color: GlassColors.border(context), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('分类到相簿', style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
          8.hGap,
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _albums.length + 1,
              itemBuilder: (context, index) {
                if (index == _albums.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: _createAlbumInline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.accent.withOpacity(AppOpacities.accentBorder)),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: context.accent),
                              4.wGap,
                              Text('新建相簿', style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent, fontWeight: AppFontWeights.medium)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final album = _albums[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _addToAlbum(album),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Center(
                        child: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFontSizes.xs, color: Colors.white, fontWeight: AppFontWeights.medium)),
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
}
