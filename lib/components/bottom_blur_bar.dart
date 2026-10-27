import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

/// 模态底部统一面板：圆角 + 顶部把手 + 可选标题栏 + 底部安全区适配。
///
/// `blur=true`（默认）使用毛玻璃效果，适合短内容弹窗（菜单、确认）；
/// `blur=false` 使用纯色 elevated 背景，适合长内容弹窗（编辑表单、列表），
/// 避免 BackdropFilter 在大区域内的高斯模糊性能开销。
///
/// 标题栏（[title] / [subtitle] / [icon]）会自动渲染为：
/// ```
///   ─── 把手 ───
///   [渐变icon盒]  主标题
///                副标题            [headerExtra]
///   ─────────────
///   children...
/// ```
class BottomBlurBar extends StatelessWidget {
  final List<Widget> children;
  final bool blur;

  /// 标题栏（可选）。传入 [title] 后会自动渲染 icon 盒 + 标题 + 副标题。
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final LinearGradient? iconGradient;
  final Widget? headerExtra;

  const BottomBlurBar({
    super.key,
    required this.children,
    this.blur = true,
    this.title,
    this.subtitle,
    this.icon,
    this.iconGradient,
    this.headerExtra,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final spec = GlassSpec.resolve(context, GlassTier.thick);
    final decoration = BoxDecoration(
      color: blur ? spec.fill : context.bgElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
      border: blur
          ? Border(top: BorderSide(color: spec.border, width: 0.5))
          : null,
      boxShadow: const [AppShadows.sheetShadow],
    );
    return _buildContent(context, decoration, bottomInset);
  }

  Widget _buildContent(BuildContext context, BoxDecoration decoration, double bottomInset) {
    final header = _buildHeader(context);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 把手
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0x4DFFFFFF) : const Color(0x4D3C3C43),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
          ),
          if (header != null) ...[
            header,
            const SizedBox(height: AppSpacings.lg),
            // 标题与内容之间的分隔
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: AppSpacings.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.divider.withOpacity(0),
                    context.divider,
                    context.divider.withOpacity(0),
                  ],
                ),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );

    final inner = Container(
      margin: EdgeInsets.only(bottom: bottomInset + 12),
      decoration: decoration,
      child: body,
    );

    if (!blur) return inner;

    final sigma = GlassSpec.resolve(context, GlassTier.thick).blur;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + 12),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            decoration: decoration,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget? _buildHeader(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasIcon = icon != null;
    if (!hasTitle && !hasIcon) return null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasIcon) ...[
          Container(
            width: AppIconSizes.lg,
            height: AppIconSizes.lg,
            decoration: BoxDecoration(
              gradient: iconGradient ?? AppGradients.accent,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: (iconGradient?.colors.first ?? AppColors.accent(context)).withOpacity(AppOpacities.accentShadow),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: AppColors.onAccent),
          ),
          const SizedBox(width: AppSpacings.lg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTitle)
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: AppFontWeights.semibold,
                    color: context.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    color: context.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (headerExtra != null) headerExtra!,
      ],
    );
  }
}
