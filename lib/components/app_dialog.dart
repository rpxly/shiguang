import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'app_button.dart';

/// 统一对话框组件，替换散落的 AlertDialog / Dialog+GlassCard / 自建 sheet。
///
/// - [AppDialog.show]      通用内容对话框（如编辑文案）
/// - [AppDialog.confirm]   确认对话框（如删除照片）
/// - [AppDialog.input]     单行输入对话框（如新建相簿）
///
/// 风格：居中卡片 + `AppRadii.xxl` 圆角 + 阴影 + 顶部渐变 icon 盒
class AppDialog {
  /// 通用内容对话框
  static Future<void> show(
    BuildContext context, {
    required String title,
    IconData? icon,
    LinearGradient? iconGradient,
    String? subtitle,
    required List<Widget> children,
    List<Widget>? actions,
  }) {
    return showDialog(
      context: context,
      barrierColor: context.glassBarrier,
      builder: (ctx) => _AppDialogBase(
        title: title,
        icon: icon,
        iconGradient: iconGradient,
        subtitle: subtitle,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
        actions: actions,
      ),
    );
  }

  /// 确认对话框
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon,
    bool danger = false,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  }) async {
    return showDialog<bool>(
      context: context,
      barrierColor: context.glassBarrier,
      builder: (ctx) => _AppDialogBase(
        title: title,
        icon: icon ?? (danger ? Icons.warning_amber_rounded : Icons.help_outline),
        iconGradient: danger
            ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B)])
            : AppGradients.accent,
        body: Text(
          message,
          style: TextStyle(
            fontSize: AppFontSizes.base,
            color: context.textSecondary,
            height: AppLineHeights.normal,
          ),
        ),
        actions: [
          AppButton.secondary(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            variant: danger ? AppButtonVariant.danger : AppButtonVariant.primary,
            shape: AppButtonShape.pill,
            size: AppButtonSize.lg,
            expand: true,
            label: confirmLabel,
            haptic: danger ? HapticFeedbackType.heavy : HapticFeedbackType.medium,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// 单行输入对话框
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    IconData? icon,
    String confirmLabel = '保存',
    String cancelLabel = '取消',
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      barrierColor: context.glassBarrier,
      builder: (ctx) => _AppDialogBase(
        title: title,
        icon: icon ?? Icons.edit_outlined,
        body: Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: context.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.md),
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: maxLines,
            style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: context.textTertiary),
            ),
          ),
        ),
        actions: [
          AppButton.secondary(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(null),
          ),
          AppButton.primary(
            label: confirmLabel,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
  }
}

class _AppDialogBase extends StatelessWidget {
  final String title;
  final IconData? icon;
  final LinearGradient? iconGradient;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;

  const _AppDialogBase({
    required this.title,
    this.icon,
    this.iconGradient,
    this.subtitle,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final spec = GlassSpec.resolve(context, GlassTier.thick);
    final radius = BorderRadius.circular(AppRadii.xxl);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
            decoration: BoxDecoration(borderRadius: radius, boxShadow: spec.shadows),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacings.xxl),
                  decoration: BoxDecoration(
                    color: spec.fill,
                    borderRadius: radius,
                    border: Border.all(color: spec.border, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (icon != null) ...[
                        _buildIcon(context),
                        const SizedBox(height: AppSpacings.lg),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFontSizes.lg,
                          fontWeight: AppFontWeights.semibold,
                          color: context.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacings.xs),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppFontSizes.sm,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacings.lg),
                      body,
                      if (actions != null && actions!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacings.xxl),
                        Row(
                          children: [
                            for (var i = 0; i < actions!.length; i++) ...[
                              if (i > 0) const SizedBox(width: AppSpacings.md),
                              Expanded(child: actions![i]),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Center(
      child: Container(
        width: AppIconSizes.lg,
        height: AppIconSizes.lg,
        decoration: BoxDecoration(
          gradient: iconGradient ?? AppGradients.accent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: [
            BoxShadow(
              color: (iconGradient?.colors.first ?? AppColors.accent(context))
                  .withOpacity(AppOpacities.accentShadow),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}
