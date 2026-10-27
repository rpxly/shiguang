import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// 统一按钮组件，替换散落的 _timelineOpBtn / _iconBtn / _navBtn 等。
///
/// 变体：
/// - [AppButtonVariant.primary]   渐变填充 + 白字 + 阴影（主操作：保存、导入）
/// - [AppButtonVariant.secondary] bgSubtle 填充 + textPrimary（次操作：取消）
/// - [AppButtonVariant.ghost]     透明 + textSecondary（幽灵：文案/模板/导出小按钮）
/// - [AppButtonVariant.danger]    error 填充 + 白字（删除确认）
/// - [AppButtonVariant.outline]   divider 边框 + textPrimary（圆形导航）
///
/// 尺寸：[AppButtonSize.sm/md/lg] 对应高度 28/36/44
/// 形状：[AppButtonShape.pill/rect/circle]
class AppButton extends StatefulWidget {
  final AppButtonVariant variant;
  final AppButtonSize size;
  final AppButtonShape shape;
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool expand; // 是否占满父宽度
  final HapticFeedbackType? haptic;

  const AppButton({
    super.key,
    required this.variant,
    this.size = AppButtonSize.md,
    this.shape = AppButtonShape.rect,
    this.icon,
    this.label,
    this.onPressed,
    this.expand = false,
    this.haptic,
  });

  /// 图标+文字的幽灵小按钮（时光线操作栏用）
  const AppButton.ghost({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.sm,
    this.haptic = HapticFeedbackType.selection,
  })  : variant = AppButtonVariant.ghost,
        shape = AppButtonShape.rect,
        expand = false;

  /// 圆形图标按钮（顶栏/月份导航用）
  const AppButton.circle({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.outline,
    this.size = AppButtonSize.sm,
    this.haptic = HapticFeedbackType.light,
  })  : shape = AppButtonShape.circle,
        label = null,
        expand = false;

  /// 主按钮（渐变填充，导入/保存用）
  const AppButton.primary({
    super.key,
    this.icon,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.lg,
    this.expand = true,
  })  : variant = AppButtonVariant.primary,
        shape = AppButtonShape.pill,
        haptic = HapticFeedbackType.medium;

  /// 危险按钮（删除用）
  const AppButton.danger({
    super.key,
    this.icon,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.lg,
    this.expand = true,
  })  : variant = AppButtonVariant.danger,
        shape = AppButtonShape.pill,
        haptic = HapticFeedbackType.heavy;

  /// 次按钮（取消用）
  const AppButton.secondary({
    super.key,
    this.icon,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.lg,
    this.expand = true,
  })  : variant = AppButtonVariant.secondary,
        shape = AppButtonShape.pill,
        haptic = null;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onPressed == null) return;
    // 触感反馈
    switch (widget.haptic) {
      case HapticFeedbackType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        await HapticFeedback.selectionClick();
        break;
      case null:
        break;
    }
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dimension();
    final inner = _buildInner(context, dim);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          _handleTap();
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: inner)
              : inner,
        ),
      ),
    );
  }

  double _dimension() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return 28;
      case AppButtonSize.md:
        return 36;
      case AppButtonSize.lg:
        return 44;
    }
  }

  double _radius() {
    switch (widget.shape) {
      case AppButtonShape.pill:
        return AppRadii.full;
      case AppButtonShape.rect:
        return widget.size == AppButtonSize.sm ? AppRadii.md : AppRadii.lg;
      case AppButtonShape.circle:
        return AppRadii.full;
    }
  }

  Widget _buildInner(BuildContext context, double dim) {
    final isCircle = widget.shape == AppButtonShape.circle;
    // 只保留水平 padding，垂直方向用 alignment 居中：
    // 固定高度 - 上下 padding 会把内容区压到小于文字行高，导致文字被裁切。
    final padding = isCircle
        ? EdgeInsets.zero
        : EdgeInsets.symmetric(
            horizontal: widget.size == AppButtonSize.sm ? AppSpacings.md : AppSpacings.lg,
          );

    final decoration = _buildDecoration(context);

    final iconSize = widget.size == AppButtonSize.sm ? 14.0 : 18.0;
    final fontSize = widget.size == AppButtonSize.sm ? AppFontSizes.xs : AppFontSizes.base;

    final List<Widget> children = [];
    if (widget.icon != null) {
      children.add(Icon(widget.icon, size: iconSize, color: _iconColor(context)));
      if (widget.label != null) {
        children.add(const SizedBox(width: AppSpacings.sm));
      }
    }
    if (widget.label != null) {
      children.add(
        Text(
          widget.label!,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: AppFontWeights.medium,
            color: _textColor(context),
          ),
        ),
      );
    }

    return Container(
      width: isCircle ? dim : null,
      height: dim,
      padding: padding,
      alignment: Alignment.center,
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  BoxDecoration _buildDecoration(BuildContext context) {
    final radius = BorderRadius.circular(_radius());
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return BoxDecoration(
          gradient: AppGradients.accent,
          borderRadius: radius,
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent(context).withOpacity(0.35),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        );
      case AppButtonVariant.danger:
        return BoxDecoration(
          color: AppColors.error,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        );
      case AppButtonVariant.secondary:
        return BoxDecoration(
          color: GlassColors.bg(context),
          borderRadius: radius,
          border: Border.all(color: GlassColors.borderSubtle(context), width: 1),
        );
      case AppButtonVariant.ghost:
        return const BoxDecoration();
      case AppButtonVariant.outline:
        return BoxDecoration(
          color: GlassColors.bg(context),
          border: Border.all(color: GlassColors.border(context), width: 1),
          borderRadius: radius,
        );
    }
  }

  Color _textColor(BuildContext context) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return AppColors.onAccent;
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.secondary:
        return context.textPrimary;
      case AppButtonVariant.ghost:
        return context.textSecondary;
      case AppButtonVariant.outline:
        return context.textPrimary;
    }
  }

  Color _iconColor(BuildContext context) => _textColor(context);
}

enum AppButtonVariant { primary, secondary, ghost, danger, outline }
enum AppButtonSize { sm, md, lg }
enum AppButtonShape { pill, rect, circle }
enum HapticFeedbackType { light, medium, heavy, selection }
