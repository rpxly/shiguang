import 'package:flutter/material.dart';

/// 模板类型：精简为 6 个核心模板
enum MagTemplate {
  bottomWhite,    // 下留白：图上文下（经典杂志风）
  fullBleed,      // 全幅：图满铺 + 底部渐变文案
  polaroid,       // 拍立得：白边相框
  centerLine,     // 中线：上图下文细线分隔
  stereoFrame,    // 立体相框：厚边框+阴影
  filmGrain,      // 胶片质感：暗角+日期戳
}

/// 胶片品牌（模拟真实胶卷边缘印记）
enum FilmBrand {
  kodak,    // 柯达：黄红配色，KODAK GOLD 200
  fuji,     // 富士：绿色，FUJI SUPERIA 400
  ilford,   // 伊尔福：黑白，ILFORD HP5 400
  none,     // 无品牌：纯净胶片质感
}

extension FilmBrandX on FilmBrand {
  String get label => switch (this) {
        FilmBrand.kodak => 'Kodak',
        FilmBrand.fuji => 'Fuji',
        FilmBrand.ilford => 'Ilford',
        FilmBrand.none => '无品牌',
      };
  /// 品牌名（印在胶片条上）
  String get name => switch (this) {
        FilmBrand.kodak => 'KODAK',
        FilmBrand.fuji => 'FUJI',
        FilmBrand.ilford => 'ILFORD',
        FilmBrand.none => '',
      };
  /// 胶片型号
  String get model => switch (this) {
        FilmBrand.kodak => 'GOLD 200',
        FilmBrand.fuji => 'SUPERIA 400',
        FilmBrand.ilford => 'HP5 PLUS 400',
        FilmBrand.none => '',
      };
  /// 感光度
  String get iso => switch (this) {
        FilmBrand.kodak => 'ISO 200/24°',
        FilmBrand.fuji => 'ISO 400/27°',
        FilmBrand.ilford => 'ISO 400/27°',
        FilmBrand.none => '',
      };
  /// 品牌主色（用于胶片条背景和印记）
  Color get primaryColor => switch (this) {
        FilmBrand.kodak => const Color(0xFFE8B71A), // 柯达黄
        FilmBrand.fuji => const Color(0xFF1A6B3E),  // 富士绿
        FilmBrand.ilford => const Color(0xFF2A2A2A), // 伊尔福深灰
        FilmBrand.none => Colors.black87,           // 无品牌用纯黑
      };
  /// 品牌强调色（品牌名字色）
  Color get accentColor => switch (this) {
        FilmBrand.kodak => const Color(0xFFD52B1E),  // 柯达红
        FilmBrand.fuji => Colors.white,
        FilmBrand.ilford => const Color(0xFFE8E8E8),
        FilmBrand.none => Colors.white54,
      };
  /// 张数
  String get exposures => FilmBrand.none == this ? '' : '36 EXP';
}

extension MagTemplateX on MagTemplate {
  String get label => switch (this) {
        MagTemplate.bottomWhite => '下留白',
        MagTemplate.fullBleed => '全幅',
        MagTemplate.polaroid => '拍立得',
        MagTemplate.centerLine => '中线',
        MagTemplate.stereoFrame => '立体相框',
        MagTemplate.filmGrain => '胶片质感',
      };
  bool get needsTwoPhotos => false;
}

/// 艺术字体样式枚举
enum MagFontStyle {
  serifThin,   // 极细衬线（杂志风）
  serifBold,   // 粗衬线（标题感）
  sans,        // 无衬线（现代极简）
  mono,        // 等宽（打字机风）
}

extension MagFontStyleX on MagFontStyle {
  String get label => switch (this) {
        MagFontStyle.serifThin => '极细衬线',
        MagFontStyle.serifBold => '粗衬线',
        MagFontStyle.sans => '无衬线',
        MagFontStyle.mono => '等宽',
      };
  String get fontFamily => switch (this) {
        MagFontStyle.serifThin => 'serif',
        MagFontStyle.serifBold => 'serif',
        MagFontStyle.sans => 'sans-serif',
        MagFontStyle.mono => 'monospace',
      };
  FontWeight get fontWeight => switch (this) {
        MagFontStyle.serifThin => FontWeight.w200,
        MagFontStyle.serifBold => FontWeight.w700,
        MagFontStyle.sans => FontWeight.w300,
        MagFontStyle.mono => FontWeight.w400,
      };
  double get letterSpacing => switch (this) {
        MagFontStyle.serifThin => 3,
        MagFontStyle.serifBold => 1,
        MagFontStyle.sans => 2,
        MagFontStyle.mono => 0.5,
      };
}

/// 单页数据（可序列化）
///
/// 盒模型参考水印大师 app，分三层：
/// ```
/// 卡片（最外层 Container）
/// ├── 外边距 margin（卡片 → 内卡片的距离）
/// ├── 内卡片
/// │   ├── 内边距 padding（内卡片边 → 内容的距离）
/// │   ├── 图片（固定尺寸，不随边距变）
/// │   └── 文字 ← textMargin 控制图片与文字间距
/// └── 外边距
/// ```
class MagPage {
  final String id;
  final List<String> photoIds;
  MagTemplate template;
  String caption;
  bool showDate;
  bool showLocation;
  /// 外边距（卡片到内卡片的距离）
  double marginTop;
  double marginBottom;
  double marginLeft;
  double marginRight;
  /// 内边距（内卡片边到内容的距离）
  double paddingTop;
  double paddingBottom;
  double paddingLeft;
  double paddingRight;
  double cornerRadius;
  /// 图片与文字之间的间距（独立于内外边距）
  double textMargin;
  /// 图片显示高度：0=按原图比例自适应；>0=用户自定义高度（px）
  double imageHeight;
  /// 胶片品牌（仅 filmGrain 模板生效）
  FilmBrand filmBrand;
  /// 暗角强度 0~1（仅 filmGrain 模板生效，0=无暗角）
  double vignetteIntensity;
  /// 文案字体样式
  MagFontStyle fontStyle;
  /// 图片旋转角度（0/90/180/270）
  int rotation;

  MagPage({
    required this.id,
    required this.photoIds,
    required this.template,
    required this.caption,
    this.showDate = true,
    this.showLocation = true,
    this.marginTop = 16.0,
    this.marginBottom = 16.0,
    this.marginLeft = 16.0,
    this.marginRight = 16.0,
    this.paddingTop = 16.0,
    this.paddingBottom = 16.0,
    this.paddingLeft = 16.0,
    this.paddingRight = 16.0,
    this.cornerRadius = 0.0,
    this.textMargin = 24.0,
    this.imageHeight = 0.0,
    this.filmBrand = FilmBrand.kodak,
    this.vignetteIntensity = 0.35,
    this.fontStyle = MagFontStyle.serifThin,
    this.rotation = 0,
  });

  /// 旧数据兼容：若存在 borderWidth 字段，映射为外边距
  factory MagPage.fromJson(Map<String, dynamic> j) {
    final legacyBorder = (j['borderWidth'] as num?)?.toDouble();
    final mt = (j['marginTop'] as num?)?.toDouble() ?? legacyBorder ?? 16.0;
    final mb = (j['marginBottom'] as num?)?.toDouble() ?? legacyBorder ?? 16.0;
    final ml = (j['marginLeft'] as num?)?.toDouble() ?? legacyBorder ?? 16.0;
    final mr = (j['marginRight'] as num?)?.toDouble() ?? legacyBorder ?? 16.0;
    // 旧数据无内边距字段时，外边距 >0 则内边距用小值，否则默认 16
    final hasPadding = j.containsKey('paddingTop');
    final pt = (j['paddingTop'] as num?)?.toDouble() ?? (hasPadding ? 16.0 : 0.0);
    final pb = (j['paddingBottom'] as num?)?.toDouble() ?? (hasPadding ? 16.0 : 0.0);
    final pl = (j['paddingLeft'] as num?)?.toDouble() ?? (hasPadding ? 16.0 : 0.0);
    final pr = (j['paddingRight'] as num?)?.toDouble() ?? (hasPadding ? 16.0 : 0.0);
    return MagPage(
      id: j['id'] as String? ?? '',
      photoIds: (j['photoIds'] as List?)?.cast<String>() ?? const [],
      template: MagTemplate.values.firstWhere(
        (t) => t.name == j['template'],
        orElse: () => MagTemplate.bottomWhite,
      ),
      caption: j['caption'] as String? ?? '',
      showDate: j['showDate'] as bool? ?? true,
      showLocation: j['showLocation'] as bool? ?? true,
      marginTop: mt,
      marginBottom: mb,
      marginLeft: ml,
      marginRight: mr,
      paddingTop: pt,
      paddingBottom: pb,
      paddingLeft: pl,
      paddingRight: pr,
      cornerRadius: (j['cornerRadius'] as num?)?.toDouble() ?? 0.0,
      textMargin: (j['textMargin'] as num?)?.toDouble() ?? 24.0,
      imageHeight: (j['imageHeight'] as num?)?.toDouble() ?? 0.0,
      filmBrand: FilmBrand.values.firstWhere(
        (b) => b.name == j['filmBrand'],
        orElse: () => FilmBrand.kodak,
      ),
      vignetteIntensity: (j['vignetteIntensity'] as num?)?.toDouble() ?? 0.35,
      fontStyle: MagFontStyle.values.firstWhere(
        (f) => f.name == j['fontStyle'],
        orElse: () => MagFontStyle.serifThin,
      ),
      rotation: (j['rotation'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'photoIds': photoIds,
        'template': template.name,
        'caption': caption,
        'showDate': showDate,
        'showLocation': showLocation,
        'marginTop': marginTop,
        'marginBottom': marginBottom,
        'marginLeft': marginLeft,
        'marginRight': marginRight,
        'paddingTop': paddingTop,
        'paddingBottom': paddingBottom,
        'paddingLeft': paddingLeft,
        'paddingRight': paddingRight,
        'cornerRadius': cornerRadius,
        'textMargin': textMargin,
        'imageHeight': imageHeight,
        'filmBrand': filmBrand.name,
        'vignetteIntensity': vignetteIntensity,
        'fontStyle': fontStyle.name,
        'rotation': rotation,
      };

  EdgeInsets get margin => EdgeInsets.fromLTRB(marginLeft, marginTop, marginRight, marginBottom);
  EdgeInsets get padding => EdgeInsets.fromLTRB(paddingLeft, paddingTop, paddingRight, paddingBottom);
}

/// 图片尺寸缓存
class ImgSize {
  final double width;
  final double height;
  ImgSize(this.width, this.height);
}

/// A4 布局单元格描述
class A4Cell {
  final int photoIdx;
  final int colspan; // 1 或 2
  final int rowspan; // 1 或 2
  A4Cell({required this.photoIdx, this.colspan = 1, this.rowspan = 1});
}

/// A4 整体布局描述
class A4Layout {
  final List<A4Cell> cells;
  final int rows;
  final int cols;
  A4Layout({required this.cells, required this.rows, required this.cols});
}
