import 'package:flutter/material.dart';
import '../theme.dart';

/// 统一空状态视觉：图标 + 主标题 + 副标题 + 可选 CTA 按钮。
///
/// 通过 [tone] 切换语义色调：
/// - [EmptyStateTone.neutral]：默认，图标用 textTertiary（无数据/未操作）
/// - [EmptyStateTone.success]：图标用 success 色（任务完成态）
/// - [EmptyStateTone.accent]：图标包裹渐变圆角盒（强引导态）
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? subtitle;
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final EmptyStateTone tone;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    this.title,
    this.subtitle,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.tone = EmptyStateTone.neutral,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = _buildIcon(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            if (title != null) ...[
              AppSpacings.lg.hGap,
              Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSizes.lg,
                  fontWeight: AppFontWeights.medium,
                  color: context.textPrimary,
                ),
              ),
            ],
            if (subtitle != null) ...[
              AppSpacings.sm.hGap,
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  color: context.textTertiary,
                ),
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              AppSpacings.xl.hGap,
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    boxShadow: [AppShadows.accentShadow(context)],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onCta,
                    icon: Icon(ctaIcon ?? icon, size: 18, color: AppColors.onAccent),
                    label: Text(
                      ctaLabel!,
                      style: const TextStyle(
                        color: AppColors.onAccent,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    switch (tone) {
      case EmptyStateTone.success:
        return Icon(icon, size: iconSize, color: context.success);
      case EmptyStateTone.accent:
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppGradients.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
            boxShadow: [AppShadows.accentShadow(context)],
          ),
          child: Icon(icon, size: 32, color: AppColors.onAccent),
        );
      case EmptyStateTone.neutral:
        return Icon(icon, size: iconSize, color: context.textTertiary);
    }
  }
}

enum EmptyStateTone { neutral, success, accent }
