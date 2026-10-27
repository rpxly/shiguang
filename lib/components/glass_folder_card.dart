import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/image_helper.dart';

/// 磨砂玻璃文件夹卡片（参考 21st.dev glass-folder-cards 深色变体）。
///
/// 结构（对应参考图标注）：
/// - 顶部照片带：相簿前 1~3 张照片并排铺满文件夹顶部（绿框区域）
/// - 前板：macOS 文件夹剪影玻璃（标签耳在右），毛玻璃压住照片带下缘
/// - 标签：名称/张数在标签耳下方右侧；⋯ 操作在玻璃左上
///
/// 交互：按压倾斜；[highlighted] 拖拽悬停高亮；[emphasized] 新建占位卡。
class GlassFolderCard extends StatefulWidget {
  final String label;
  final String meta;
  final List<String?> covers;
  final bool isLocalSync;
  final bool emphasized;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final VoidCallback? onLongPress;

  const GlassFolderCard({
    super.key,
    required this.label,
    required this.meta,
    this.covers = const [],
    this.isLocalSync = false,
    this.emphasized = false,
    this.highlighted = false,
    this.onTap,
    this.onMore,
    this.onLongPress,
  });

  @override
  State<GlassFolderCard> createState() => _GlassFolderCardState();
}

class _GlassFolderCardState extends State<GlassFolderCard> {
  bool _pressed = false;
  /// 长按抬升（iOS 上下文菜单手感）
  bool _lifted = false;

  /// 单张照片高度
  static const double _photoH = 54;
  /// 玻璃前板主体上沿（压住照片堆底部约 12px，照片从口部探出）
  static const double _frontTop = 58;
  /// 标签耳上沿
  static const double _tabTop = 18;
  /// 标签耳宽度
  static const double _tabW = 84;
  /// S 过渡宽
  static const double _sweep = 30;

  static const _shape = _FolderShape(
    frontTop: _frontTop,
    tabTop: _tabTop,
    tabWidth: _tabW,
    sweep: _sweep,
    radius: AppRadii.lg,
  );

  @override
  Widget build(BuildContext context) {
    final covers = widget.covers.whereType<String>().take(3).toList();
    final hasArt = covers.isNotEmpty && !widget.emphasized;
    final borderColor = (widget.highlighted || _lifted)
        ? context.accent
        : (widget.emphasized
            ? context.accent.withOpacity(AppOpacities.accentBorder)
            : Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.16)
                : GlassColors.border(context));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      // 长按识别成功 → 卡片抬升放大，配合菜单弹出
      onLongPressStart: widget.onLongPress == null
          ? null
          : (_) => setState(() {
                _pressed = false;
                _lifted = true;
              }),
      onLongPressEnd: widget.onLongPress == null
          ? null
          : (_) => setState(() => _lifted = false),
      onLongPressCancel: widget.onLongPress == null
          ? null
          : () => setState(() => _lifted = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: _lifted ? 220 : 160),
        curve: _lifted ? Curves.easeOutBack : Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: _lifted
            ? (Matrix4.identity()..scale(1.05))
            : _pressed
                ? (Matrix4.identity()..rotateZ(-0.03)..scale(0.98))
                : Matrix4.identity(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 第 1 层：文件夹玻璃背板（包住照片，四周留出玻璃边）
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.emphasized
                      ? context.accent.withOpacity(AppOpacities.accentBg)
                      : GlassColors.bgHeavy(context),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: GlassColors.borderSubtle(context)),
                ),
              ),
            ),
            // 第 2 层：照片堆（铺满整卡直到底部，下段透过玻璃前板隐约可见）
            Positioned.fill(
              child: _photoBand(covers, hasArt),
            ),
            // 玻璃前板：文件夹剪影 + 投影 + 描边
            Positioned.fill(
              child: CustomPaint(
                painter: const _FolderShadowPainter(_shape),
                foregroundPainter: _FolderOutlinePainter(
                  shape: _shape,
                  color: borderColor,
                  strokeWidth: (widget.highlighted || _lifted) ? 1.5 : 0.6,
                ),
                child: ClipPath(
                  clipper: _shape,
                  child: _glassSurface(covers, hasArt),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  照片堆（绿框区域）：照片错位叠放，从文件夹口探出
  // ──────────────────────────────────────────────

  Widget _photoBand(List<String> covers, bool hasArt) {
    const inset = 12.0;
    // 每张照片的错位量（index 0 在最底，越靠上越探出）
    const gaps = [10.0, 16.0, 22.0]; // 纵向错位
    const jitters = [0.0, 4.0, -3.0]; // 横向错位
    const angles = [-0.045, 0.04, -0.02]; // 微倾斜（弧度）

    // 新建占位卡：accent 底色的空带
    if (widget.emphasized) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(inset, inset, inset, 0),
        child: Container(
          height: _photoH,
          decoration: BoxDecoration(
            color: context.accent.withOpacity(AppOpacities.accentBg),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    // 空相簿：三个幽灵纸片槽
    if (covers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(inset, inset, inset, 0),
        child: Container(
          height: _photoH,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: GlassColors.bg(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: GlassColors.bgHeavy(context),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: GlassColors.borderSubtle(context)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 有照片：1~3 张错位堆叠，铺满整卡直到底部，
    // 顶部探出文件夹口，下段被玻璃前板毛玻璃覆盖
    // （裁剪到卡片圆角内，防止旋转的照片角溢出卡片）
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Stack(
        children: [
          for (var i = 0; i < covers.length; i++)
            Positioned.fill(
              left: inset + jitters[i],
              right: inset - jitters[i],
              top: gaps[i],
              bottom: inset,
              child: Transform.rotate(
                angle: angles[i],
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LocalImage(
                    path: covers[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: GlassColors.bgHeavy(context),
                      child: Icon(Icons.image_outlined, size: 18, color: context.textTertiary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  玻璃前板（剪影内部）
  // ──────────────────────────────────────────────

  Widget _glassSurface(List<String> covers, bool hasArt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = widget.emphasized
        ? context.accent.withOpacity(AppOpacities.accentBg)
        : hasArt
            ? (isDark ? Colors.black.withOpacity(0.42) : Colors.white.withOpacity(0.45))
            : GlassColors.bgHeavy(context);
    final labelColor = widget.emphasized
        ? context.accent
        : hasArt
            ? Colors.white
            : context.textPrimary;
    final metaColor = widget.emphasized
        ? context.accent.withOpacity(0.7)
        : hasArt
            ? Colors.white.withOpacity(0.75)
            : context.textTertiary;

    return Stack(
      children: [
        // 毛玻璃滤镜 + 顶部微光泽
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: surfaceColor),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withOpacity(isDark ? 0.09 : 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 光效 1：斜向高光带（环境光在玻璃上的反射）
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: const Alignment(0.4, 1.1),
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(isDark ? 0.11 : 0.16),
                  Colors.white.withOpacity(0),
                ],
                stops: const [0.18, 0.36, 0.62],
              ),
            ),
          ),
        ),
        // 光效 2：顶缘高光线（玻璃切口的反光）
        Positioned.fill(
          child: CustomPaint(
            painter: _FolderSheenPainter(
              shape: _shape,
              color: Colors.white.withOpacity(isDark ? 0.75 : 0.85),
            ),
          ),
        ),
        // 新建占位：＋ 居中
        if (widget.emphasized)
          const Center(child: Icon(Icons.add, size: 30)),
        // 标签：玻璃前板内、右侧（⋯ 在左侧同一行）
        Positioned(
          top: _frontTop + 10,
          left: 48,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: AppFontSizes.base,
                  fontWeight: AppFontWeights.medium,
                  color: labelColor,
                ),
              ),
              2.hGap,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppFontSizes.xs, color: metaColor),
                    ),
                  ),
                  if (widget.isLocalSync) ...[
                    4.wGap,
                    Icon(Icons.sync, size: 11, color: hasArt ? Colors.white70 : context.info),
                  ],
                ],
              ),
            ],
          ),
        ),
        // ⋯ 操作：玻璃左上
        if (widget.onMore != null)
          Positioned(
            top: _frontTop + 4,
            left: 6,
            child: GestureDetector(
              onTap: widget.onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.more_horiz, size: 16, color: hasArt ? Colors.white70 : context.textTertiary),
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
//  文件夹剪影：标签耳在右，S 曲线过渡
// ──────────────────────────────────────────────

class _FolderShape extends CustomClipper<Path> {
  final double frontTop;
  final double tabTop;
  final double tabWidth;
  final double sweep;
  final double radius;

  const _FolderShape({
    required this.frontTop,
    required this.tabTop,
    required this.tabWidth,
    required this.sweep,
    required this.radius,
  });

  Path pathFor(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;
    const tr = 11.0;
    final fb = frontTop.clamp(0.0, h);
    final ft = tabTop.clamp(0.0, fb);
    final tw = tabWidth.clamp(0.0, w * 0.6);
    final s = sweep;

    final path = Path();
    // 标签耳顶边（右上区域）
    path.moveTo(w - tw, ft);
    path.lineTo(w - tr, ft);
    path.quadraticBezierTo(w, ft, w, ft + tr);
    // 右缘、底缘、左缘
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    // 左缘上行至前板主体上沿
    path.lineTo(0, fb + r);
    path.quadraticBezierTo(0, fb, r, fb);
    // 主体上沿右行，S 曲线上扫接入标签耳
    path.lineTo(w - tw - s, fb);
    path.cubicTo(
      w - tw - s * 0.45, fb,
      w - tw - s * 0.55, ft,
      w - tw, ft,
    );
    path.close();
    return path;
  }

  @override
  Path getClip(Size size) => pathFor(size);

  @override
  bool shouldReclip(covariant _FolderShape old) =>
      old.frontTop != frontTop ||
      old.tabTop != tabTop ||
      old.tabWidth != tabWidth ||
      old.sweep != sweep ||
      old.radius != radius;
}

class _FolderSheenPainter extends CustomPainter {
  final _FolderShape shape;
  final Color color;

  const _FolderSheenPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = shape.radius;
    final fb = shape.frontTop.clamp(0.0, h);
    final ft = shape.tabTop.clamp(0.0, fb);
    final tw = shape.tabWidth.clamp(0.0, w * 0.6);
    final s = shape.sweep;

    // 高光线：两端淡出，中间最亮
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        Offset(w * 0.1, ft),
        Offset(w, fb + 60),
        [color.withOpacity(0), color, color.withOpacity(0.35)],
        [0.0, 0.55, 1.0],
      );

    // 主体上沿（往内收 0.6px，避免被剪裁吃掉）
    canvas.drawLine(Offset(r, fb + 0.6), Offset(w - tw - s, fb + 0.6), paint);
    // 标签耳上沿
    canvas.drawLine(Offset(w - tw, ft + 0.6), Offset(w - 12, ft + 0.6), paint);
  }

  @override
  bool shouldRepaint(covariant _FolderSheenPainter old) =>
      old.shape != shape || old.color != color;
}

class _FolderShadowPainter extends CustomPainter {
  final _FolderShape shape;

  const _FolderShadowPainter(this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(shape.pathFor(size), Colors.black.withOpacity(0.3), 9, false);
  }

  @override
  bool shouldRepaint(covariant _FolderShadowPainter old) => old.shape != shape;
}

class _FolderOutlinePainter extends CustomPainter {
  final _FolderShape shape;
  final Color color;
  final double strokeWidth;

  const _FolderOutlinePainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      shape.pathFor(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _FolderOutlinePainter old) =>
      old.shape != shape || old.color != color || old.strokeWidth != strokeWidth;
}
