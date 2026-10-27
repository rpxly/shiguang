import 'package:flutter/material.dart';
import '../theme.dart';

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
    return Container(
      padding: EdgeInsets.only(top: topPad),
      height: topPad + (subtitle != null ? 56 : 48),
      decoration: BoxDecoration(
        // 导航条本身贴在内容顶部、背后没有内容可模糊，因此只用 regular 档的
        // 半透明填充 + 细描边。真正的模糊留给会盖住内容的浮层。
        color: transparent ? Colors.transparent : GlassColors.bgMedium(context),
        border: transparent
            ? null
            : Border(bottom: BorderSide(color: GlassColors.border(context), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: leading ??
                GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    label: '返回',
                    child: Center(
                      child: Container(
                        width: AppIconSizes.sm,
                        height: AppIconSizes.sm,
                        decoration: BoxDecoration(
                          color: GlassColors.bg(context),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: GlassColors.borderSubtle(context), width: 1),
                        ),
                        child: Icon(Icons.chevron_left, size: 20, color: context.textPrimary),
                      ),
                    ),
                  ),
                ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFontSizes.base,
                    fontWeight: AppFontWeights.medium,
                    color: context.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
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
          SizedBox(width: 72, child: Center(child: action ?? const SizedBox.shrink())),
        ],
      ),
    );
  }
}
