import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

/// 状态栏区域的液态玻璃 Scrim。
///
/// 固定层：高度 = 系统状态栏高度（可加 [extraHeight] 向下延伸）。
/// 结构是真模糊 + 「上浓下淡」渐变填充——顶部给状态栏图标一个稳定的
/// 玻璃衬底，向下渐隐进页面内容，消除内容与状态栏之间的"硬切"。
///
/// 使用方式：放在页面 Stack 顶部（`Positioned(top:0,left:0,right:0)`），
/// 内容从它底下滚过时自动获得毛玻璃过渡。组件本身 [IgnorePointer]，
/// 不拦截任何触摸。
class GlassTopScrim extends StatelessWidget {
  /// 状态栏以下的额外高度（玻璃向下延伸的距离）。
  final double extraHeight;

  const GlassTopScrim({super.key, this.extraHeight = 0});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final height = topPad + extraHeight;
    if (height <= 0) return const SizedBox.shrink();

    final fill = GlassColors.bgThin(context);

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: ClipRect(
          child: BackdropFilter(
            // sigma 偏低是有意的：低模糊让裁切下边缘不那么锐利，
            // 配合渐变填充读作"雾面过渡"而不是一条玻璃断层
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55, 1],
                  colors: [
                    fill,
                    fill.withOpacity(0.5),
                    fill.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
