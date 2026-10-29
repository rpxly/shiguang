import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

/// 玻璃卡片。
///
/// 材质由 [GlassTier] 决定，默认 `thin`：58% 白 + 1px 白描边 + 顶部内高光 +
/// 底部 1px 暗边 + 柔和外阴影。这套组合在没有 BackdropFilter 的情况下
/// 也能在白底上撑出「有厚度的玻璃」——关键是描边和内外双高光，
/// 单纯调透明度只会越调越白。
///
/// 性能：`thin` / `faint` 不跑 [BackdropFilter]。只有 `regular` / `thick`
/// （导航、Tab、Sheet、对话框这类固定且数量少的层）才做真模糊。
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final bool hasShadow;

  /// 材质层级，默认 [GlassTier.thin]。
  final GlassTier tier;

  /// 强制开启背景模糊（会覆盖 [tier] 的默认值）。
  /// 只在「背后确实有内容且该卡片位置固定」时使用，列表项不要开。
  final bool blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacings.lg),
    this.margin = EdgeInsets.zero,
    this.borderRadius = AppRadii.xl,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.gradient,
    this.backgroundColor,
    this.hasShadow = true,
    this.tier = GlassTier.thin,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final spec = GlassSpec.resolve(context, tier);
    final isGradient = gradient != null;

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: isGradient ? null : (backgroundColor ?? spec.fill),
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: isGradient ? Colors.white.withOpacity(0.25) : spec.border,
          width: spec.borderWidth,
        ),
      ),
      child: child,
    );

    final doBlur = blur || spec.needsBlur;
    final sigma = spec.blur > 0 ? spec.blur : 20.0;

    final clipped = ClipRRect(
      borderRadius: radius,
      child: doBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: content,
            )
          : content,
    );

    // 顶/底各一道 1px 发丝线：用画笔绘制，不用 BoxDecoration 的 Border。
    // Border 只要上下颜色不同，就无法与 borderRadius 共存——Flutter 会抛
    // `A borderRadius can only be given on borders with uniform colors`，
    // 而这会让**每一张** GlassCard 在 debug 下 paint 失败（release 因 assert
    // 被剥离才没暴露）。画笔版本既能保留圆角裁切效果，又不触发断言。
    final edged = CustomPaint(
      foregroundPainter: GlassHairlinePainter(
        radius: borderRadius,
        // 顶部一道纯白内高光：玻璃"厚度"的来源
        topColor: isGradient ? Colors.white.withOpacity(0.35) : spec.topHighlight,
        // 底部一道极淡暗边：把面板从背景上"切"下来
        bottomColor: isGradient ? const Color(0x14000000) : spec.bottomHairline,
      ),
      child: clipped,
    );

    // 阴影必须画在 ClipRRect 之外，否则连同模糊一起被裁掉——
    // 之前所有卡片的阴影都是这么消失的。
    Widget surface = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: !hasShadow
            ? null
            : isGradient
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                    ),
                  ]
                : spec.shadows,
      ),
      child: edged,
    );

    if (margin != EdgeInsets.zero) {
      surface = Padding(padding: margin, child: surface);
    }

    if (onTap != null || onLongPress != null) {
      return GestureDetector(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        behavior: HitTestBehavior.opaque,
        child: surface,
      );
    }

    return surface;
  }
}

/// 玻璃卡片顶/底两道发丝线。
///
/// 为什么不用 `Border`：`Border(top: …, bottom: …)` 上下颜色不同即为非均匀
/// 边框，一旦同时给 `borderRadius`，Flutter 会在 paint 阶段断言失败
/// （`A borderRadius can only be given on borders with uniform colors`）。
/// 用画笔在圆角矩形内裁切后画两条 1px 横线，视觉与原实现一致且不触发断言。
class GlassHairlinePainter extends CustomPainter {
  final double radius;
  final Color topColor;
  final Color bottomColor;

  const GlassHairlinePainter({
    required this.radius,
    required this.topColor,
    required this.bottomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = topColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = bottomColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassHairlinePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.topColor != topColor ||
      oldDelegate.bottomColor != bottomColor;
}
