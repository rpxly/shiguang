import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'glass_card.dart';

/// 全局统一的圆形玻璃图标按钮。
///
/// iOS 26 液态玻璃语言：faint 玻璃底座 + 白描边 + 顶部镜面高光，
/// 按下有轻微缩放反馈 + 触感震动。顶部栏、菜单触发器等小图标
/// 一律用它，不再各自手写 Container。
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// 图标尺寸，默认 20。
  final double iconSize;

  /// 底座直径，默认 36。
  final double size;

  /// 图标颜色，默认 textSecondary。
  final Color? color;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconSize = 20,
    this.size = 36,
    this.color,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final spec = GlassSpec.resolve(context, GlassTier.faint);
    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: AppTransitions.instant,
          curve: Curves.easeOut,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: spec.fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: GlassColors.borderSubtle(context),
                width: 1,
              ),
            ),
            child: CustomPaint(
              foregroundPainter: GlassHairlinePainter(
                radius: widget.size / 2,
                topColor: spec.topHighlight,
                bottomColor: spec.bottomHairline,
              ),
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.color ?? context.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
