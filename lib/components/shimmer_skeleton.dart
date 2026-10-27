import 'package:flutter/material.dart';
import '../theme.dart';

/// Shimmer 骨架屏组件，替换散落的静态灰块骨架。
///
/// 用法：
/// ```dart
/// ShimmerSkeleton.box(width: 100, height: 100);
/// ShimmerSkeleton.list(itemCount: 3, itemHeight: 180);
/// ShimmerSkeleton.timeline(itemCount: 3); // 月刊专用
/// ```
///
/// 流光从左到右循环，800ms 周期（`AppTransitions.shimmer`）。
class ShimmerSkeleton extends StatefulWidget {
  final int itemCount;
  final double itemHeight;
  final double? itemWidth;
  final double radius;
  final EdgeInsets padding;
  final Axis scrollDirection;
  final double spacing;
  final bool isTimeline; // 月刊时光线模式（带圆点+竖线）

  const ShimmerSkeleton.list({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 80,
    this.itemWidth,
    this.radius = AppRadii.md,
    this.padding = const EdgeInsets.all(AppSpacings.lg),
    this.scrollDirection = Axis.vertical,
    this.spacing = AppSpacings.md,
  }) : isTimeline = false;

  const ShimmerSkeleton.timeline({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 180,
    this.itemWidth,
    this.radius = AppRadii.lg,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
    this.scrollDirection = Axis.vertical,
    this.spacing = AppSpacings.lg,
  }) : isTimeline = true;

  /// 单个骨架块
  const ShimmerSkeleton.box({
    super.key,
    double width = double.infinity,
    double height = 80,
    this.radius = AppRadii.md,
  })  : itemCount = 1,
        itemHeight = height,
        itemWidth = width == double.infinity ? null : width,
        padding = EdgeInsets.zero,
        scrollDirection = Axis.vertical,
        spacing = 0,
        isTimeline = false;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppTransitions.shimmer,
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Padding(
          padding: widget.padding,
          child: widget.scrollDirection == Axis.vertical
              ? Column(
                  children: [
                    for (var i = 0; i < widget.itemCount; i++) ...[
                      if (i > 0) SizedBox(height: widget.spacing),
                      _buildItem(context),
                    ],
                  ],
                )
              : Row(
                  children: [
                    for (var i = 0; i < widget.itemCount; i++) ...[
                      if (i > 0) SizedBox(width: widget.spacing),
                      _buildItem(context),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context) {
    // 骨架块用半透明面：不透明的浅灰在环境光背景上会显出一块"死白/死灰"
    final baseColor = context.surface;
    final highlightColor = context.isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.85);

    // shimmer 流光位置 0.0 → 1.0
    final t = _anim.value;
    final begin = t - 0.3;
    final end = t + 0.3;

    final box = Container(
      width: widget.itemWidth,
      height: widget.itemHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(begin, 0),
          end: Alignment(end, 0),
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );

    if (!widget.isTimeline) return box;

    // 时光线模式：左侧圆点+竖线 + 右侧骨架块
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: context.surface,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 1,
                height: widget.itemHeight - 20,
                color: context.surface,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacings.md),
        Expanded(child: box),
      ],
    );
  }
}
