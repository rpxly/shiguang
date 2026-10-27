import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../components/empty_state.dart';
import '../components/glass_card.dart';
import '../components/nav_header.dart';
import '../components/staggered_fade_in.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../services/image_helper.dart';
import '../app_state.dart';
import '../components/app_background.dart';

class CuratedPhotosPage extends StatefulWidget {
  final LocalRepository repository;
  final VoidCallback onBack;

  const CuratedPhotosPage({
    super.key,
    required this.repository,
    required this.onBack,
  });

  @override
  State<CuratedPhotosPage> createState() => _CuratedPhotosPageState();
}

class _CuratedPhotosPageState extends State<CuratedPhotosPage> {
  List<Photo> _allPhotos = [];
  List<Photo> _favorites = [];
  bool _isLoading = true;
  int _lastDataVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      context.read<AppState>().addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    context.read<AppState>().removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    final appState = context.read<AppState>();
    if (_lastDataVersion != appState.dataVersion) {
      _lastDataVersion = appState.dataVersion;
      if (mounted) _loadData();
    }
  }

  void _loadData() {
    _allPhotos = widget.repository.getAllPhotos();
    _favorites = _allPhotos.where((p) => p.isFavorite).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _isLoading = false);
  }

  void _toggleFavorite(Photo photo) {
    HapticFeedback.selectionClick();
    final updated = photo.copyWith(isFavorite: !photo.isFavorite);
    widget.repository.savePhoto(updated);
    setState(() {
      final idx = _allPhotos.indexWhere((p) => p.id == photo.id);
      if (idx >= 0) _allPhotos[idx] = updated;
      _favorites = _allPhotos.where((p) => p.isFavorite).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Column(
        children: [
          NavHeader(
            title: '我的收藏',
            onBack: widget.onBack,
          ),
          _buildHeader(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, size: 20, color: context.error),
          8.wGap,
          Text('已收藏 ${_favorites.length} 张照片',
            style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favorites.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        iconSize: 64,
        title: '还没有收藏',
        subtitle: '点击照片心形图标即可收藏',
      );
    }

    final screenW = MediaQuery.of(context).size.width;
    final cacheW = ((screenW - 40 - 12) / 2 * MediaQuery.of(context).devicePixelRatio).round();

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _favorites.length,
      itemBuilder: (context, index) => StaggeredFadeIn(
        index: index,
        child: _buildPhotoCard(_favorites[index], cacheW),
      ),
    );
  }

  Widget _buildPhotoCard(Photo photo, int cacheW) {
    return GlassCard(
      borderRadius: AppRadii.lg,
      padding: EdgeInsets.zero,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: LocalImage(
                path: photo.thumbnailPath, fit: BoxFit.cover,
                cacheWidth: cacheW,
                errorBuilder: (_, __, ___) => Container(
                  color: context.surface,
                  child: Icon(Icons.broken_image_outlined, color: context.textTertiary, size: 32),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [context.scrim.withOpacity(0.6), Colors.transparent],
                stops: const [0, 0.55],
              ),
            ),
          ),
          Positioned(
            bottom: 8, left: 10, right: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${photo.dateTime.month}月${photo.dateTime.day}日',
                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ),
          Positioned(
            bottom: 8, right: 8,
            child: GestureDetector(
              onTap: () => _toggleFavorite(photo),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(AppOpacities.blackOverlay),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  photo.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: photo.isFavorite ? context.error : Colors.white,
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
