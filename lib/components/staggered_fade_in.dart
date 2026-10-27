import 'package:flutter/material.dart';
import '../theme.dart';

/// 列表项 stagger 淡入上滑动画。
///
/// 用法：
/// ```dart
/// StaggeredFadeIn(
///   index: i,
///   child: MyCard(),
/// )
/// ```
///
/// 时长 `AppTransitions.normal`（250ms），曲线 `Curves.easeOutCubic`。
/// 延迟 `index * 40ms`（前 6 个有延迟，后续立即）。
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration delayPerItem;
  final int maxStagger; // 超过此值不再延迟

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.duration = AppTransitions.normal,
    this.delayPerItem = const Duration(milliseconds: 40),
    this.maxStagger = 6,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = widget.index < widget.maxStagger
        ? widget.delayPerItem * widget.index
        : Duration.zero;
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          child: widget.child,
        ),
      ),
    );
  }
}
