import 'package:flutter/material.dart';
import 'glass_top_scrim.dart';

/// 环境光背景。
///
/// 玻璃拟态成立的前提是「背后必须有东西可模糊」。这里铺一层极浅的线性渐变
/// 打底，再叠三团大半径径向光斑（暖金 / 雾蓝 / 米粉），形成低频明暗流动。
/// 低频是有意为之：`GlassTier.thin` 的卡片不做 BackdropFilter，靠这层柔光
/// 就能骗过眼睛，省掉长列表里成百上千次离屏绘制。
///
/// 整层包 [RepaintBoundary]，列表滚动时零重绘。
class AppBackground extends StatelessWidget {
  final Widget? child;

  /// 光斑强度倍率。0 = 纯线性渐变，1 = 标准（中等），>1 更浓。
  final double intensity;

  const AppBackground({super.key, this.child, this.intensity = 1.0});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: _AmbientLayer(dark: dark, intensity: intensity)),
        if (child != null) child!,
      ],
    );
  }
}

class _AmbientLayer extends StatelessWidget {
  final bool dark;
  final double intensity;

  const _AmbientLayer({required this.dark, required this.intensity});

  @override
  Widget build(BuildContext context) {
    // 亮色：暖白 → 冷白，光斑落在左上 / 右侧 / 左下，模拟室内天光
    final base = dark
        ? const [Color(0xFF0B0B10), Color(0xFF0E0D14)]
        : const [Color(0xFFFCFAF6), Color(0xFFF2F5FA)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: base,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: dark
            ? [
                _glow(const Color(0xFF3A2A55), 0.55, const Alignment(-0.95, -0.9), 0.95),
                _glow(const Color(0xFF12303F), 0.50, const Alignment(1.0, 0.15), 1.0),
                _glow(const Color(0xFF3B2A1C), 0.40, const Alignment(-0.35, 1.0), 0.85),
              ]
            : [
                _glow(const Color(0xFFF0CF95), 0.55, const Alignment(-0.95, -0.9), 0.85),
                _glow(const Color(0xFFB9D2F0), 0.50, const Alignment(1.0, 0.05), 0.95),
                _glow(const Color(0xFFEFC9BC), 0.40, const Alignment(-0.4, 1.0), 0.85),
              ],
      ),
    );
  }

  Widget _glow(Color color, double alpha, Alignment center, double radius) {
    final a = (alpha * intensity).clamp(0.0, 1.0);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [color.withOpacity(a), color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}

/// 带环境光背景的 Scaffold。
///
/// 页面背景透明、由 [AppBackground] 接管，这样每张卡片的半透明才有意义。
/// 全屏渐变本身是不透明的，所以路由切换时不会透出上一页。
class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool resizeToAvoidBottomInset;

  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // 状态栏玻璃 Scrim 固定在内容之上：内容滚动时从它底下穿过，
      // 获得毛玻璃过渡，消除顶部"硬切"
      body: AppBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassTopScrim(),
            ),
          ],
        ),
      ),
    );
  }
}
