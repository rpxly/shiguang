import 'package:flutter/material.dart';
import '../theme.dart';

/// 全屏 Loading 遮罩：统一深色遮罩 + 居中菊花 + 文案。
///
/// 用于在异步操作期间阻断用户交互并给出反馈（删除、AI 优化、导入等）。
/// 使用 [LoadingOverlay.fill] 包裹现有 widget，或直接放在 Stack 中。
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool fullscreen;

  const LoadingOverlay({
    super.key,
    this.message,
    this.fullscreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        if (message != null) ...[
          const SizedBox(height: AppSpacings.md),
          Text(
            message!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.sm,
            ),
          ),
        ],
      ],
    );

    if (!fullscreen) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacings.xl),
          decoration: BoxDecoration(
            color: context.scrim,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: content,
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: context.scrim,
        child: Center(child: content),
      ),
    );
  }
}
