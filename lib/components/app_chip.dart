import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'app_button.dart' show HapticFeedbackType;

/// 统一 chip 组件，替换散落的 _buildOptionChip / 关键词 chip / category chip / preset chip / AI badge / album chip。
///
/// - [AppChipStyle.selectable]  选中/未选中（心情/天气/分类/preset）
/// - [AppChipStyle.tag]         标签（关键词、AI badge）
/// - [AppChipStyle.action]      可点击带 icon（fetch/fission）
class AppChip extends StatefulWidget {
  final AppChipStyle style;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool busy; // loading 状态（action 用）
  final LinearGradient? selectedGradient;
  final HapticFeedbackType? haptic;

  const AppChip({
    super.key,
    required this.style,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.busy = false,
    this.selectedGradient,
    this.haptic,
  });

  /// 可选中 chip（心情/天气/分类/preset）
  const AppChip.selectable({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.selectedGradient,
    this.haptic = HapticFeedbackType.selection,
  })  : style = AppChipStyle.selectable,
        icon = null,
        busy = false;

  /// 标签 chip（关键词、AI badge）
  const AppChip.tag({
    super.key,
    required this.label,
    this.icon,
    this.selectedGradient,
  })  : style = AppChipStyle.tag,
        selected = false,
        onTap = null,
        busy = false,
        haptic = null;

  /// 可点击带 icon chip（fetch/fission）
  const AppChip.action({
    super.key,
    required this.label,
    required this.icon,
    this.busy = false,
    this.onTap,
    this.haptic = HapticFeedbackType.light,
  })  : style = AppChipStyle.action,
        selected = false,
        selectedGradient = null;

  @override
  State<AppChip> createState() => _AppChipState();
}

class _AppChipState extends State<AppChip> {
  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case AppChipStyle.selectable:
        return _buildSelectable(context);
      case AppChipStyle.tag:
        return _buildTag(context);
      case AppChipStyle.action:
        return _buildAction(context);
    }
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;
    switch (widget.haptic) {
      case HapticFeedbackType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.selection:
        await HapticFeedback.selectionClick();
        break;
      default:
        break;
    }
    widget.onTap!();
  }

  Widget _buildSelectable(BuildContext context) {
    final gradient = widget.selectedGradient ?? AppGradients.accent;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppTransitions.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.md),
        decoration: BoxDecoration(
          gradient: widget.selected ? gradient : null,
          color: widget.selected ? null : GlassColors.bg(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: widget.selected
              ? null
              : Border.all(color: GlassColors.border(context), width: 1),
          boxShadow: widget.selected
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(AppOpacities.accentShadow),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: AppFontSizes.sm,
            fontWeight: AppFontWeights.medium,
            color: widget.selected ? AppColors.onAccent : context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.xs),
      decoration: BoxDecoration(
        color: context.accent.withOpacity(AppOpacities.accentBg),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: context.accent.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 12, color: context.accent),
            const SizedBox(width: AppSpacings.xs),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: AppFontSizes.xs,
              color: context.accent,
              fontWeight: AppFontWeights.medium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    final isBusy = widget.busy;
    return GestureDetector(
      onTap: isBusy ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.md, vertical: AppSpacings.xs),
        decoration: BoxDecoration(
          color: isBusy ? context.surface : context.accent.withOpacity(AppOpacities.accentBg),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: context.textSecondary,
                ),
              )
            else
              Icon(widget.icon, size: 12, color: context.accent),
            const SizedBox(width: AppSpacings.xs),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                color: isBusy ? context.textSecondary : context.accent,
                fontWeight: AppFontWeights.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppChipStyle { selectable, tag, action }
