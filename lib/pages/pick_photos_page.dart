import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_button.dart';
import '../components/nav_header.dart';
import '../models/photo.dart';
import '../services/image_helper.dart';
import '../theme.dart';
import '../components/app_background.dart';

/// 多选照片加入相簿。
///
/// 选中只是入「待应用队列」，真正的目录移动在相簿 Tab 顶部
/// 的「写入系统相册」里一次性完成 —— 这样整理过程不会被授权弹窗打断。
class PickPhotosPage extends StatefulWidget {
  final List<Photo> photos;
  final String albumName;
  final VoidCallback onBack;

  const PickPhotosPage({
    super.key,
    required this.photos,
    required this.albumName,
    required this.onBack,
  });

  @override
  State<PickPhotosPage> createState() => _PickPhotosPageState();
}

class _PickPhotosPageState extends State<PickPhotosPage> {
  final Set<String> _selected = <String>{};

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return GlassScaffold(
      body: Column(
        children: [
          NavHeader(
            title: '添加到「${widget.albumName}」',
            subtitle: _selected.isEmpty ? '选择要移入的照片' : '已选 ${_selected.length} 张',
            onBack: widget.onBack,
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSpacings.xl,
                AppSpacings.md,
                AppSpacings.xl,
                _selected.isEmpty ? 80 : 140,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final isSelected = _selected.contains(photo.id);
                return GestureDetector(
                  onTap: () => _toggle(photo.id),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        child: LocalImage(
                          path: photo.thumbnailPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: context.surface,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 18,
                              color: context.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(color: context.accent, width: 2),
                            color: context.accent.withOpacity(0.18),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? context.accent : Colors.black26,
                            border: Border.all(color: Colors.white70, width: 1.2),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacings.xl,
                  8,
                  AppSpacings.xl,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: '清空',
                        onPressed: () => setState(_selected.clear),
                      ),
                    ),
                    12.wGap,
                    Expanded(
                      flex: 2,
                      child: AppButton.primary(
                        label: '加入 ${_selected.length} 张',
                        onPressed: () =>
                            Navigator.of(context).pop(_selected.toList()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
