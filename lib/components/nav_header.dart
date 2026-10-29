import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'glass_card.dart';

/// iOS 26 液态玻璃风格顶部导航条。
///
/// 悬浮玻璃条造型：左右内缩、胶囊圆角、clear 液态玻璃材质
/// （低填充 + 真模糊 + 顶部镜面高光 + 底部暗边 + 浮起阴影），
/// 与系统状态栏之间留一段环境光过渡，状态栏区域由页面的
/// `GlassTopScrim` 负责衬底。
///
/// 返回按钮为圆形玻璃底座 + chevron，去掉旧版"灰底方块"。
class NavHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? action;
  final Widget? leading;
  final bool transparent;

  const NavHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.action,
    this.leading,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    if (transparent) {
      // 透明模式：保持旧布局（贴边通栏、无材质），供特殊页面使用
      return Container(
        padding: EdgeInsets.only(top: topPad),
        height: topPad + (subtitle != null ? 56 : 48),
        child: _buildRow(context),
      );
    }

    // 融合版：回归全宽通栏（状态栏区域并入导航条，稳重大气），
    // 材质保留液态玻璃——真模糊 + 顶部镜面高光 + 底部暗边发丝线。
    final spec = GlassSpec.resolve(context, GlassTier.regular);
    final barHeight = subtitle != null ? 56.0 : 48.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
        child: CustomPaint(
          foregroundPainter: GlassHairlinePainter(
            radius: 0,
            topColor: spec.topHighlight,
            bottomColor: spec.bottomHairline,
          ),
          child: Container(
            padding: EdgeInsets.only(top: topPad),
            height: topPad + barHeight,
            decoration: BoxDecoration(
              color: spec.fill,
              border: Border(
                bottom: BorderSide(color: spec.border, width: 0.5),
              ),
            ),
            child: _buildRow(context),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: leading ?? _buildBackButton(context),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSizes.base,
                  fontWeight: AppFontWeights.semibold,
                  color: context.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: context.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 64, child: Center(child: action ?? const SizedBox.shrink())),
      ],
    );
  }

  /// 圆形玻璃底座返回按钮（faint 材质 + 白描边）。
  Widget _buildBackButton(BuildContext context) {
    final spec = GlassSpec.resolve(context, GlassTier.faint);
    return GestureDetector(
      onTap: onBack,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: '返回',
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: spec.fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: GlassColors.borderSubtle(context),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.chevron_left,
              size: 22,
              color: context.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
