import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../components/empty_state.dart';
import '../components/nav_header.dart';
import '../components/app_dialog.dart';
import '../components/app_button.dart';
import '../components/loading_overlay.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../services/image_helper.dart';
import '../app_state.dart';
import '../components/app_background.dart';

class CleanupSuggestionPage extends StatefulWidget {
  final LocalRepository repository;
  final VoidCallback onBack;

  const CleanupSuggestionPage({
    super.key,
    required this.repository,
    required this.onBack,
  });

  @override
  State<CleanupSuggestionPage> createState() => _CleanupSuggestionPageState();
}

class _CleanupSuggestionPageState extends State<CleanupSuggestionPage> {
  List<Photo> _allPhotos = [];
  List<Photo> _screenshots = [];
  Set<String> _selectedIds = {};
  bool _isDeleting = false;
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
    _screenshots = _allPhotos.where((p) => p.category == '截图').toList();
    if (mounted) setState(() => _isLoading = false);
  }

  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedIds.contains(photo.id)) {
        _selectedIds.remove(photo.id);
      } else {
        _selectedIds.add(photo.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _screenshots.map((p) => p.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await AppDialog.confirm(
      context,
      title: '确认清理 ${_selectedIds.length} 张截图？',
      message: '删除后无法恢复，请确认选择无误。',
      danger: true,
      confirmLabel: '清理',
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await widget.repository.deletePhotos(_selectedIds.toList());
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _selectedIds.clear();
        });
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Stack(
        children: [
          Column(
            children: [
              NavHeader(
                title: '清理截图',
                onBack: widget.onBack,
                action: _screenshots.isNotEmpty
                    ? GestureDetector(
                        onTap: _selectedIds.isEmpty ? _selectAll : _deselectAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.sm),
                          child: Text(
                            _selectedIds.isEmpty ? '全选' : '取消',
                            style: TextStyle(fontSize: AppFontSizes.sm, color: context.accent),
                          ),
                        ),
                      )
                    : null,
              ),
              _buildHeader(),
              Expanded(child: _buildGrid()),
              if (_selectedIds.isNotEmpty) _buildBottomBar(),
            ],
          ),
          if (_isDeleting) const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.cleaning_services_outlined, size: 20, color: context.warning),
          8.wGap,
          Text('共 ${_screenshots.length} 张截图',
            style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_screenshots.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        iconSize: 64,
        tone: EmptyStateTone.success,
        title: '相册很干净',
        subtitle: '没有需要清理的截图',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: _screenshots.length,
      itemBuilder: (context, index) => _buildPhotoCard(_screenshots[index], index),
    );
  }

  Widget _buildPhotoCard(Photo photo, int index) {
    final isSelected = _selectedIds.contains(photo.id);
    final cacheW = ((MediaQuery.of(context).size.width - 40 - 12) / 3 * MediaQuery.of(context).devicePixelRatio).round();

    return GestureDetector(
      onTap: () => _toggleSelection(photo),
      child: AnimatedContainer(
        duration: AppTransitions.normal,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: isSelected
              ? [BoxShadow(color: context.accent.withOpacity(AppOpacities.accentShadow), blurRadius: 8, offset: const Offset(0, 2))]
              : [AppShadows.smShadow(context)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LocalImage(
              path: photo.thumbnailPath, fit: BoxFit.cover,
              cacheWidth: cacheW,
              errorBuilder: (_, __, ___) => Container(
                color: context.surface,
                child: Icon(Icons.broken_image_outlined, color: context.textTertiary, size: 20),
              ),
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.accent.withOpacity(AppOpacities.accentShadow),
                    border: Border.all(color: context.accent, width: 2),
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              )
            else
              Positioned(
                top: 4, right: 4,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(AppOpacities.blackOverlay), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(AppOpacities.whiteOverlay), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12, left: 20, right: 20,
      ),
      decoration: BoxDecoration(
        color: context.scrim.withOpacity(0.9),
        border: Border(top: BorderSide(color: GlassColors.border(context), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('已选 ${_selectedIds.length} 张',
            style: const TextStyle(fontSize: AppFontSizes.sm, color: Colors.white, fontWeight: AppFontWeights.medium)),
          AppButton(
            variant: AppButtonVariant.danger,
            shape: AppButtonShape.pill,
            size: AppButtonSize.md,
            icon: Icons.delete_outline,
            label: '清理 ${_selectedIds.length} 张',
            onPressed: _deleteSelected,
            expand: false,
          ),
        ],
      ),
    );
  }
}
