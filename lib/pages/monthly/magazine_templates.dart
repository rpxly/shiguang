import 'package:flutter/material.dart';

import '../../models/photo.dart';
import '../../services/image_helper.dart';
import '../../services/scene_classifier_service.dart';
import '../../theme.dart';
import 'magazine_models.dart';

// ─── 模板渲染 ──────────────────────────────────────────────────

/// 根据图片真实宽高比和可用宽度，计算显示高度。
/// 核心原则：**严格按原图比例显示，不强制裁切/压缩**。
/// - [overrideHeight] > 0：用户自定义容器高度，图片用 contain 完整显示（上下/左右留白）
/// - [size] 为 null：返回默认高度（此时图片仍用 contain，不会变形）
/// - 正常情况：h = width / ratio，严格按比例，不受 min/max 限制
double resolveImageHeight(ImgSize? size, double width,
    {double minHeight = 200, double maxHeight = 800, double overrideHeight = 0}) {
  if (overrideHeight > 0) return overrideHeight.clamp(80, 1000);
  if (size == null || size.width <= 0 || size.height <= 0) return minHeight;
  final ratio = size.width / size.height;
  final h = width / ratio;
  return h;
}

Widget renderSingleTemplate(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  switch (page.template) {
    case MagTemplate.bottomWhite:
      return _tmplBottomWhite(context, page, photo, size, cardWidth);
    case MagTemplate.fullBleed:
      return _tmplFullBleed(context, page, photo, size, cardWidth);
    case MagTemplate.polaroid:
      return _tmplPolaroid(context, page, photo, size, cardWidth);
    case MagTemplate.centerLine:
      return _tmplCenterLine(context, page, photo, size, cardWidth);
    case MagTemplate.stereoFrame:
      return _tmplStereoFrame(context, page, photo, size, cardWidth);
    case MagTemplate.filmGrain:
      return _tmplFilmGrain(context, page, photo, size, cardWidth);
  }
}

// ─── 艺术字样式 ────────────────────────────────────────────────
/// 文案样式：根据 [fontStyle] 动态切换字体族/字重/字距
TextStyle _artCaptionStyle(BuildContext context, MagFontStyle fontStyle, {double size = 18}) {
  return TextStyle(
    fontFamily: fontStyle.fontFamily,
    fontSize: size,
    fontWeight: fontStyle.fontWeight,
    height: 1.8,
    letterSpacing: fontStyle.letterSpacing,
    color: AppColors.textPrimary(context),
  );
}

/// 日期/地点：小字 + 超大字距，水印感
TextStyle _artMetaStyle(BuildContext context, MagFontStyle fontStyle) {
  return TextStyle(
    fontFamily: fontStyle.fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w300,
    letterSpacing: 4,
    color: AppColors.textTertiary(context),
  );
}

/// 全幅模板白色文案
TextStyle _artCaptionLightStyle(MagFontStyle fontStyle, {double size = 18}) {
  return TextStyle(
    fontFamily: fontStyle.fontFamily,
    fontSize: size,
    fontWeight: fontStyle.fontWeight,
    height: 1.8,
    letterSpacing: fontStyle.letterSpacing,
    color: Colors.white,
  );
}

TextStyle _artMetaLightStyle(MagFontStyle fontStyle) {
  return TextStyle(
    fontFamily: fontStyle.fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w300,
    letterSpacing: 4,
    color: Colors.white70,
  );
}

/// 图片显示区域。
/// - **必须用原图路径**：缩略图可能被裁成正方形，横图会丢失左右内容，
///   所以使用 [p.path] 而不是 [p.thumbnailPath]。
/// - 默认 [BoxFit.contain]：完整显示不裁切（横图上下留白、竖图左右留白）。
/// - 全幅模板等需要满铺的场景传 [BoxFit.cover]。
/// - cacheWidth/cacheHeight 限制解码尺寸，避免大图卡顿。
Widget _imageArea(Photo p, {double? width, double? height, BorderRadius? radius, BoxFit fit = BoxFit.contain, int rotation = 0}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final effectiveWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : width;
      final effectiveHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : height;
      final cw = effectiveWidth != null ? (effectiveWidth * dpr).round() : null;
      final ch = effectiveHeight != null ? (effectiveHeight * dpr).round() : null;
      Widget image = RepaintBoundary(
        child: LocalImage(
          path: p.path,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: fit,
          cacheWidth: cw,
          cacheHeight: ch,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: AppGradients.accentSoft),
            child: Center(child: Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.3), size: 32)),
          ),
        ),
      );
      if (rotation != 0) {
        image = Transform.rotate(
          angle: rotation * 3.1415927 / 180,
          child: image,
        );
      }
      return RepaintBoundary(child: image);
    },
  );
}

Widget _metaLine(BuildContext context, MagPage page, Photo photo, {bool light = false}) {
  final parts = <String>[];
  if (page.showDate) {
    final d = photo.dateTime;
    parts.add('${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}');
  }
  if (page.showLocation) {
    // 场景词优先，其次才是能读的地名；原始经纬度不往成稿上印
    final loc = SceneClassifier.instance.placeLabelFor(photo);
    if (loc != null && loc.isNotEmpty) parts.add(loc);
  }
  if (parts.isEmpty) return const SizedBox.shrink();
  return Text(parts.join('   '), style: light ? _artMetaLightStyle(page.fontStyle) : _artMetaStyle(context, page.fontStyle));
}

Widget _captionText(BuildContext context, MagPage page, {bool light = false, double size = 18}) {
  if (page.caption.isEmpty) {
    return Text('点击下方“文案”添加', style: light ? _artMetaLightStyle(page.fontStyle) : _artMetaStyle(context, page.fontStyle));
  }
  return Text(page.caption, style: light ? _artCaptionLightStyle(page.fontStyle, size: size) : _artCaptionStyle(context, page.fontStyle, size: size));
}

// ─── 模板实现 ──────────────────────────────────────────────────

// 下留白：图上文下，图高度按真实比例自适应
// 关键：图片宽度只受外边距影响，内边距不改变图片尺寸，仅在内容周围加空白
Widget _tmplBottomWhite(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  final radius = page.cornerRadius;
  // 图片宽度 = 卡片宽度 - 外边距（内边距不影响图片尺寸）
  final contentWidth = cardWidth - page.marginLeft - page.marginRight;
  final imgHeight = resolveImageHeight(size, contentWidth, overrideHeight: page.imageHeight);
  return Padding(
    padding: page.margin,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius), bottom: Radius.zero),
          child: SizedBox(width: double.infinity, height: imgHeight, child: _imageArea(photo, height: imgHeight, rotation: page.rotation)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(page.paddingLeft, page.textMargin, page.paddingRight, page.paddingBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metaLine(context, page, photo),
              const SizedBox(height: 16),
              _captionText(context, page),
            ],
          ),
        ),
      ],
    ),
  );
}

// 全幅：图满铺 + 底部渐变文案（设计意图就是满铺，保留 cover）
Widget _tmplFullBleed(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  final radius = page.cornerRadius;
  final contentWidth = cardWidth - page.marginLeft - page.marginRight;
  final height = resolveImageHeight(size, contentWidth,
      minHeight: 320, maxHeight: 620, overrideHeight: page.imageHeight);
  return Padding(
    padding: page.margin,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: double.infinity, height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _imageArea(photo, height: height, fit: BoxFit.cover, rotation: page.rotation),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, context.scrim],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
            Positioned(
              bottom: page.paddingBottom + 8,
              left: page.paddingLeft + 8,
              right: page.paddingRight + 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _captionText(context, page, light: true),
                  const SizedBox(height: 8),
                  _metaLine(context, page, photo, light: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// 拍立得：白边相框
Widget _tmplPolaroid(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  final radius = page.cornerRadius;
  final contentWidth = cardWidth - page.marginLeft - page.marginRight;
  final imgHeight = resolveImageHeight(size, contentWidth,
      minHeight: 240, maxHeight: 480, overrideHeight: page.imageHeight);
  return Padding(
    padding: page.margin,
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(width: double.infinity, height: imgHeight, child: _imageArea(photo, height: imgHeight, rotation: page.rotation)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(page.paddingLeft, page.textMargin, page.paddingRight, page.paddingBottom),
          child: Column(
            children: [
              _captionText(context, page, size: 16),
              const SizedBox(height: 8),
              _metaLine(context, page, photo),
            ],
          ),
        ),
      ],
    ),
  );
}

// 立体相框：白底边框，仅在照片上加轻微阴影
Widget _tmplStereoFrame(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  final radius = page.cornerRadius;
  const frameThickness = 12.0;
  // 图片宽度 = 卡片宽度 - 外边距 - 相框厚度（内边距不影响图片尺寸）
  final contentWidth = cardWidth - page.marginLeft - page.marginRight - frameThickness * 2;
  final imgHeight = resolveImageHeight(size, contentWidth,
      minHeight: 240, maxHeight: 500, overrideHeight: page.imageHeight);
  return Padding(
    padding: page.margin,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      padding: const EdgeInsets.all(frameThickness),
      child: Column(
        children: [
          // 仅照片加轻微阴影
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: context.scrim.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(width: double.infinity, height: imgHeight, child: _imageArea(photo, height: imgHeight, rotation: page.rotation)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(page.paddingLeft, page.textMargin, page.paddingRight, page.paddingBottom),
            child: Column(
              children: [
                _captionText(context, page, size: 16),
                const SizedBox(height: 6),
                _metaLine(context, page, photo),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// 胶片质感：模拟真实胶卷边缘（齿孔条 + 品牌印记）+ 暗角 + 日期戳
// 无品牌时仍保留齿孔条，仅去掉品牌名/型号/ISO 文字
Widget _tmplFilmGrain(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  final radius = page.cornerRadius;
  final brand = page.filmBrand;
  final hasBrand = brand != FilmBrand.none;
  final vignette = page.vignetteIntensity.clamp(0.0, 1.0);
  final contentWidth = cardWidth - page.marginLeft - page.marginRight;
  final imgHeight = resolveImageHeight(size, contentWidth,
      minHeight: 280, maxHeight: 500, overrideHeight: page.imageHeight);
  return Padding(
    padding: page.margin,
    child: Column(
      children: [
        // 顶部胶片条：齿孔 + 品牌名（无品牌时仅齿孔）
        _buildFilmStrip(brand, isTop: true),
        // 图片区：降饱和 + 暗角 + 四角感光涂层印记
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  0.95, 0, 0, 0, 0,
                  0, 0.92, 0, 0, 0,
                  0, 0, 0.88, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: SizedBox(width: double.infinity, height: imgHeight, child: _imageArea(photo, height: imgHeight, rotation: page.rotation)),
              ),
            ),
            // 暗角效果（强度由 vignetteIntensity 控制，0=无暗角）
            if (vignette > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: RadialGradient(
                        colors: [Colors.transparent, Colors.transparent, Colors.black.withOpacity(vignette)],
                        stops: const [0.5, 0.82, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            // 四角感光涂层印记（品牌色条，模拟胶片漏光；无品牌时不显示）
            if (hasBrand) ...[
              Positioned(top: 0, left: 0, child: _buildCornerMark(brand, Alignment.topLeft)),
              Positioned(top: 0, right: 0, child: _buildCornerMark(brand, Alignment.topRight)),
              Positioned(bottom: 0, left: 0, child: _buildCornerMark(brand, Alignment.bottomLeft)),
              Positioned(bottom: 0, right: 0, child: _buildCornerMark(brand, Alignment.bottomRight)),
            ],
          ],
        ),
        // 底部胶片条：齿孔 + 型号（无品牌时仅齿孔）
        _buildFilmStrip(brand, isTop: false),
        Padding(
          padding: EdgeInsets.fromLTRB(page.paddingLeft, page.textMargin, page.paddingRight, page.paddingBottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _captionText(context, page, size: 15)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.black54, width: 1), borderRadius: BorderRadius.circular(2)),
                child: Text(
                  '${photo.dateTime.year}/${photo.dateTime.month.toString().padLeft(2, '0')}/${photo.dateTime.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.black54, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 胶片边缘条：模拟真实胶卷的齿轮条。
/// 有品牌时左右两侧显示品牌色块+文字；无品牌时仅保留齿孔条（纯黑+白孔）。
Widget _buildFilmStrip(FilmBrand brand, {required bool isTop}) {
  final hasBrand = brand != FilmBrand.none;
  return Container(
    height: 28,
    decoration: const BoxDecoration(color: Colors.black87),
    child: Row(
      children: [
        // 左侧品牌标识区（无品牌时不显示）
        if (hasBrand)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: double.infinity,
            color: brand.primaryColor,
            child: Center(
              child: Text(
                isTop ? brand.name : brand.model,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: brand.accentColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        // 中间齿轮孔条（始终显示）
        Expanded(
          child: Row(
            children: List.generate(18, (i) => Expanded(
              child: Center(
                child: Container(
                  width: 7, height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            )),
          ),
        ),
        // 右侧信息区（无品牌时不显示）
        if (hasBrand)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: double.infinity,
            color: brand.primaryColor.withOpacity(0.85),
            child: Center(
              child: Text(
                isTop ? brand.iso : brand.exposures,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: brand.accentColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// 四角感光涂层印记：模拟胶片漏光/涂层痕迹
Widget _buildCornerMark(FilmBrand brand, Alignment alignment) {
  return IgnorePointer(
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignment,
          end: Alignment(-alignment.x, -alignment.y),
          colors: [
            brand.primaryColor.withOpacity(0.6),
            brand.primaryColor.withOpacity(0),
          ],
          stops: const [0, 1],
        ),
      ),
    ),
  );
}

// 中线分隔：上图下文，中间一条细线
Widget _tmplCenterLine(BuildContext context, MagPage page, Photo photo, ImgSize? size, double cardWidth) {
  final radius = page.cornerRadius;
  final contentWidth = cardWidth - page.marginLeft - page.marginRight;
  final imgHeight = resolveImageHeight(size, contentWidth, overrideHeight: page.imageHeight);
  return Padding(
    padding: page.margin,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius), bottom: Radius.zero),
          child: SizedBox(width: double.infinity, height: imgHeight, child: _imageArea(photo, height: imgHeight, rotation: page.rotation)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(page.paddingLeft, page.textMargin, page.paddingRight, page.paddingBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metaLine(context, page, photo),
              const SizedBox(height: 16),
              Container(width: 32, height: 1, color: AppColors.divider(context)),
              const SizedBox(height: 16),
              _captionText(context, page),
            ],
          ),
        ),
      ],
    ),
  );
}
