import 'dart:io';
import 'package:flutter/material.dart';

/// 按「逻辑尺寸 × devicePixelRatio」计算解码尺寸（物理像素），
/// 结果限制在 `[1, maxPhysical]`；无法推导时返回 null（按原图解码）。
int? resolveCacheSize(
  double? logicalSize,
  double devicePixelRatio, {
  double maxPhysical = 2048,
}) {
  if (logicalSize == null || !logicalSize.isFinite || logicalSize <= 0) {
    return null;
  }
  final dpr = (devicePixelRatio.isFinite && devicePixelRatio > 0)
      ? devicePixelRatio
      : 1.0;
  final physical = (logicalSize * dpr).round();
  final maxValue = (maxPhysical.isFinite && maxPhysical > 0)
      ? maxPhysical.round()
      : 2048;
  final cap = maxValue < 1 ? 1 : maxValue;
  if (physical < 1) return 1;
  return physical > cap ? cap : physical;
}

class LocalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// 显式指定解码后的缓存尺寸（物理像素），用于限制大图解码内存。
  /// 不传则按 width/height 或父约束推导；均无则使用原图（高清单图场景如大图查看器）。
  final int? cacheWidth;
  final int? cacheHeight;

  const LocalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;

    // 显式 cacheWidth/cacheHeight 优先
    int? cw = cacheWidth;
    int? ch = cacheHeight;

    // 未显式指定时，只用一边推导，避免非方图被拉伸
    if (cw == null && ch == null) {
      if (_hasSize(width)) {
        cw = resolveCacheSize(width, dpr);
      } else if (_hasSize(height)) {
        ch = resolveCacheSize(height, dpr);
      }
    }

    if (cw != null || ch != null) {
      return _image(cw, ch);
    }

    // 兜底：用父约束 × DPR 推导，优先宽度
    return LayoutBuilder(
      builder: (context, constraints) {
        int? fallbackW;
        int? fallbackH;
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (_hasSize(maxWidth)) {
          fallbackW = resolveCacheSize(maxWidth, dpr);
        } else if (_hasSize(maxHeight)) {
          fallbackH = resolveCacheSize(maxHeight, dpr);
        }
        return _image(fallbackW, fallbackH);
      },
    );
  }

  Widget _image(int? cw, int? ch) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cw,
        cacheHeight: ch,
        errorBuilder: errorBuilder,
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cw,
      cacheHeight: ch,
      errorBuilder: errorBuilder,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
    );
  }

  static bool _hasSize(double? value) {
    return value != null && value.isFinite && value > 0;
  }
}
