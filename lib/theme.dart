import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color bgElevatedLight = Color(0xFFFFFFFF);
  static const Color bgSubtleLight = Color(0xFFF3F4F6);
  static const Color bgMutedLight = Color(0xFFE5E7EB);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textInverseLight = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFF8C6D1F);
  static const Color primaryHoverLight = Color(0xFF6E5618);
  static const Color borderLight = Color(0x0F000000);
  static const Color borderSubtleLight = Color(0x0A000000);
  static const Color dividerLight = Color(0x0D000000);
  static const Color overlayLight = Color(0x66000000);
  static const Color scrimLight = Color(0x99000000);

  static const Color bgDark = Color(0xFF0B0B10);
  static const Color bgElevatedDark = Color(0xFF12121A);
  static const Color bgSubtleDark = Color(0xFF181820);
  static const Color bgMutedDark = Color(0xFF23232D);
  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textTertiaryDark = Color(0xFF7C7C86);
  static const Color textInverseDark = Color(0xFF0B0B10);
  static const Color primaryDark = Color(0xFFE8B86D);
  static const Color primaryHoverDark = Color(0xFFF0CD96);
  static const Color borderDark = Color(0x1AFFFFFF);
  static const Color borderSubtleDark = Color(0x0DFFFFFF);
  static const Color dividerDark = Color(0x0FFFFFFF);
  static const Color overlayDark = Color(0x99000000);
  static const Color scrimDark = Color(0xD9000000);

  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // 琥珀金 / 香槟金：单一奢华强调色
  static const Color accentLight = Color(0xFF8C6D1F);
  static const Color accentLightSoft = Color(0xFFB08A3E);
  static const Color accentDark = Color(0xFFE8B86D);
  static const Color accentDarkSoft = Color(0xFFF0CD96);
  // 渐变金面上的可读前景（深色文字）
  static const Color onAccent = Color(0xFF241A0C);

  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgLight : bgDark;
  static Color bgElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgElevatedLight : bgElevatedDark;
  static Color bgSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgSubtleLight : bgSubtleDark;
  static Color bgMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgMutedLight : bgMutedDark;
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? textPrimaryLight : textPrimaryDark;
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? textSecondaryLight : textSecondaryDark;
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? textTertiaryLight : textTertiaryDark;
  static Color textInverse(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? textInverseLight : textInverseDark;
  static Color primary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? primaryLight : primaryDark;
  static Color primaryHover(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? primaryHoverLight : primaryHoverDark;
  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? borderLight : borderDark;
  static Color borderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? borderSubtleLight : borderSubtleDark;
  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? dividerLight : dividerDark;
  static Color overlay(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? overlayLight : overlayDark;
  static Color scrim(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? scrimLight : scrimDark;
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? accentLight : accentDark;
  static Color accentSoft(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? accentLightSoft : accentDarkSoft;
}

extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => AppColors.bg(this);
  Color get bgElevated => AppColors.bgElevated(this);
  Color get bgSubtle => AppColors.bgSubtle(this);
  Color get bgMuted => AppColors.bgMuted(this);
  Color get textPrimary => AppColors.textPrimary(this);
  Color get textSecondary => AppColors.textSecondary(this);
  Color get textTertiary => AppColors.textTertiary(this);
  Color get textInverse => AppColors.textInverse(this);
  Color get border => AppColors.border(this);
  Color get borderSubtle => AppColors.borderSubtle(this);
  Color get divider => AppColors.divider(this);
  Color get overlay => AppColors.overlay(this);
  Color get scrim => AppColors.scrim(this);
  Color get accent => AppColors.accent(this);
  Color get accentSoft => AppColors.accentSoft(this);
  Color get onAccent => AppColors.onAccent;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.info;
  Color get primary => AppColors.primary(this);

  /// 玻璃卡内部的次级面
  Color get surface => GlassColors.surface(this);

  /// 弹窗遮罩（比 [scrim] 轻，配合毛玻璃面板）
  Color get glassBarrier => GlassColors.barrier(this);
}

/// 玻璃材质色板。
///
/// 亮色依赖「环境光斑背景」才能成立：光斑 → 半透明面板 → 白色内高光，
/// 三者缺一就退化成白卡叠白底。所有卡片请通过 [GlassSpec] 取材质，
/// 不要直接引用这里的常量，否则明暗两套参数会各写一遍。
abstract class GlassColors {
  // ── Light：58% / 72% / 86% / 40% 四档 ──
  /// `GlassCard`（thin 档）专用：内容卡片，背后是柔光渐变
  static const Color bgThinLight = Color(0x94FFFFFF); // 58%
  /// 通用半透明面：药丸、徽标、图标按钮、sliver appbar。
  /// 这些常常直接浮在照片上，保持 72% 以免透出底色影响可读性。
  static const Color bgLight = Color(0xB8FFFFFF); // 72%
  static const Color bgMediumLight = Color(0xB8FFFFFF); // regular 导航（72%，厚实稳定）
  static const Color bgHeavyLight = Color(0xDBFFFFFF); // thick 面板
  static const Color bgClearLight = Color(0x8CFFFFFF); // clear 悬浮岛（55%）
  static const Color bgFaintLight = Color(0x66FFFFFF); // faint 次级分组
  static const Color borderLight = Color(0xF2FFFFFF); // 95%
  static const Color borderSubtleLight = Color(0x99FFFFFF); // 60%
  static const Color shadowLight = Color(0x120F172A); // 7% 冷灰
  static const Color insetLight = Color(0xFFFFFFFF);
  static const Color hairlineLight = Color(0x0A000000); // 底部 4%

  /// 内嵌面（输入框、分段控件、图标底座、骨架块）。
  /// 玻璃卡内部需要再分一层时用它，而不是 bgSubtle —— 不透明灰会把
  /// 卡片"打穿"成实心块，在环境光背景上尤其显脏。
  static const Color surfaceLight = Color(0x8AFFFFFF); // 54%
  /// 弹窗遮罩：iOS 的 Alert 是 30% 黑 + 背景虚化，60% 会显得厚重发闷
  static const Color barrierLight = Color(0x4D000000);

  // ── Dark：8% / 6% / 88% 深面 ──
  static const Color bgThinDark = Color(0x14FFFFFF); // thin 内容卡
  static const Color bgDark = Color(0x0FFFFFFF); // 通用半透明面
  static const Color bgMediumDark = Color(0x14FFFFFF); // regular 导航（8%）
  static const Color bgHeavyDark = Color(0xD916161E); // thick 面板
  static const Color bgClearDark = Color(0x24FFFFFF); // clear 悬浮岛（14%）
  static const Color bgFaintDark = Color(0x0AFFFFFF);
  static const Color borderDark = Color(0x24FFFFFF); // 14%
  static const Color borderSubtleDark = Color(0x17FFFFFF); // 9%
  static const Color shadowDark = Color(0x40000000);
  static const Color insetDark = Color(0x38FFFFFF); // 22% 内高光
  static const Color hairlineDark = Color(0x1AFFFFFF);

  static const Color surfaceDark = Color(0x0FFFFFFF);
  static const Color barrierDark = Color(0x73000000);

  static Color bgThin(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgThinLight : bgThinDark;
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgLight : bgDark;
  static Color bgMedium(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgMediumLight : bgMediumDark;
  static Color bgHeavy(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgHeavyLight : bgHeavyDark;
  static Color bgClear(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgClearLight : bgClearDark;
  static Color bgFaint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? bgFaintLight : bgFaintDark;
  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? borderLight : borderDark;
  static Color borderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? borderSubtleLight : borderSubtleDark;
  static Color shadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? shadowLight : shadowDark;
  static Color inset(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? insetLight : insetDark;
  static Color hairline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? hairlineLight : hairlineDark;

  /// 玻璃卡内部的次级面（输入框 / 分段控件 / 图标底）
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? surfaceLight : surfaceDark;

  /// 弹窗遮罩
  static Color barrier(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? barrierLight : barrierDark;
}

/// 玻璃层级。数值越大越"厚"：越不透明、模糊半径越大。
enum GlassTier {
  /// 卡内次级分组、图片衬底 —— 无模糊、无阴影
  faint,

  /// 内容卡片（默认）—— 仿玻璃：不跑 BackdropFilter，靠柔光背景 + 白描边造玻璃感
  thin,

  /// 导航栏、TabBar、悬浮工具条 —— 真模糊 40（液态玻璃低填充）
  regular,

  /// 底部 Sheet、居中对话框 —— 真模糊 40
  thick,

  /// iOS 26 液态玻璃悬浮岛：最高透 + 最强模糊 + 镜面高光 + 浮起阴影。
  /// 只给悬浮在内容之上的固定岛用（底部 TabBar 岛等）。
  clear,
}

/// 解析后的一组玻璃绘制参数。
class GlassSpec {
  final Color fill;
  final double blur;
  final Color border;
  final double borderWidth;
  final Color topHighlight;
  final Color bottomHairline;
  final List<BoxShadow> shadows;

  const GlassSpec({
    required this.fill,
    required this.blur,
    required this.border,
    required this.borderWidth,
    required this.topHighlight,
    required this.bottomHairline,
    required this.shadows,
  });

  /// 性能开关：`thin` / `faint` 一律不跑 BackdropFilter。
  /// 长列表里每张卡一次离屏 saveLayer 会直接吃掉中端机帧率，
  /// 而背后是低频柔光斑，肉眼分不出模糊与否。
  bool get needsBlur => blur > 0;

  static GlassSpec resolve(BuildContext context, GlassTier tier) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (tier) {
      case GlassTier.faint:
        return GlassSpec(
          fill: GlassColors.bgFaint(context),
          blur: 0,
          border: GlassColors.borderSubtle(context),
          borderWidth: 0.5,
          topHighlight: dark ? const Color(0x1FFFFFFF) : const Color(0x8CFFFFFF),
          bottomHairline: GlassColors.hairline(context),
          shadows: const [],
        );
      case GlassTier.thin:
        return GlassSpec(
          fill: GlassColors.bgThin(context),
          blur: 0,
          border: GlassColors.border(context),
          borderWidth: 1,
          topHighlight: GlassColors.inset(context),
          bottomHairline: GlassColors.hairline(context),
          shadows: [
            BoxShadow(
              color: GlassColors.shadow(context),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        );
      case GlassTier.regular:
        return GlassSpec(
          fill: GlassColors.bgMedium(context),
          blur: 40,
          border: GlassColors.border(context),
          borderWidth: 0.5,
          topHighlight: GlassColors.inset(context),
          bottomHairline: GlassColors.hairline(context),
          shadows: [
            BoxShadow(
              color: GlassColors.shadow(context),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        );
      case GlassTier.thick:
        return GlassSpec(
          fill: GlassColors.bgHeavy(context),
          blur: 40,
          border: GlassColors.border(context),
          borderWidth: 0.5,
          topHighlight: GlassColors.inset(context),
          bottomHairline: GlassColors.hairline(context),
          shadows: [
            BoxShadow(
              color: dark ? const Color(0x73000000) : const Color(0x140F172A),
              offset: const Offset(0, 8),
              blurRadius: 32,
            ),
          ],
        );
      case GlassTier.clear:
        return GlassSpec(
          fill: GlassColors.bgClear(context),
          blur: 44,
          border: GlassColors.border(context),
          borderWidth: 0.5,
          // 镜面高光：顶部一道不透明白，是液态玻璃"厚度"的核心
          topHighlight: Colors.white,
          bottomHairline: GlassColors.hairline(context),
          shadows: [
            BoxShadow(
              color: dark ? const Color(0x73000000) : const Color(0x1A0F172A),
              offset: const Offset(0, 10),
              blurRadius: 30,
            ),
            BoxShadow(
              color: dark ? const Color(0x26000000) : const Color(0x0D0F172A),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        );
    }
  }
}

abstract class AppGradients {
  static const LinearGradient accent = LinearGradient(
    colors: [Color(0xFFE8B86D), Color(0xFFD19A4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accentSoft = LinearGradient(
    colors: [Color(0xFFF0CD96), Color(0xFFE3B76B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient sunset = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient ocean = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient withOpacity(LinearGradient gradient, double opacity) {
    return LinearGradient(
      colors: gradient.colors.map((c) => c.withOpacity(opacity)).toList(),
      begin: gradient.begin,
      end: gradient.end,
      stops: gradient.stops,
      transform: gradient.transform,
    );
  }
}

abstract class AppSpacings {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double x4l = 40.0;
  static const double x5l = 48.0;
  static const double x6l = 64.0;
  static const double x7l = 80.0;
  static const double x8l = 96.0;
}

abstract class AppRadii {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 18.0;
  static const double xxl = 24.0;
  static const double full = 9999.0;
}

/// 图标盒统一尺寸（替换散落的 28/32/36/40/44/48/64/72）
abstract class AppIconSizes {
  static const double xs = 24;   // chip icon
  static const double sm = 32;   // nav 返回、_navBtn
  static const double md = 36;   // _iconBtn
  static const double lg = 44;   // sheet header icon、album 封面
  static const double xl = 48;   // month header、section header
  static const double xxl = 64;  // delete icon、loading icon
}

/// 透明度档位（统一散落的 0.06/0.08/0.1/0.3 等）
abstract class AppOpacities {
  static const double accentBg = 0.08;      // accent 背景填充
  static const double accentBorder = 0.3;   // accent 边框
  static const double accentShadow = 0.3;   // accent 阴影
  static const double blackOverlay = 0.4;   // 黑色叠层
  static const double whiteOverlay = 0.7;   // 白色叠层
}

abstract class AppFontSizes {
  static const double xs = 12.0;
  static const double sm = 13.0;
  static const double base = 15.0;
  static const double lg = 18.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;
  static const double xxxl = 36.0;
  static const double x4l = 48.0;
}

abstract class AppFontWeights {
  static const FontWeight light = FontWeight.w300;
  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

abstract class AppLineHeights {
  static const double tight = 1.25;
  static const double snug = 1.35;
  static const double normal = 1.5;
  static const double relaxed = 1.65;
}

abstract class AppShadows {
  static const BoxShadow sm = BoxShadow(
    color: Color(0x08000000),
    offset: Offset(0, 1),
    blurRadius: 4,
  );
  static const BoxShadow md = BoxShadow(
    color: Color(0x0A000000),
    offset: Offset(0, 4),
    blurRadius: 16,
  );
  static const BoxShadow lg = BoxShadow(
    color: Color(0x12000000),
    offset: Offset(0, 12),
    blurRadius: 32,
  );

  static BoxShadow smDark = const BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 1),
    blurRadius: 4,
  );
  static BoxShadow mdDark = const BoxShadow(
    color: Color(0x59000000),
    offset: Offset(0, 6),
    blurRadius: 20,
  );
  static BoxShadow lgDark = const BoxShadow(
    color: Color(0x73000000),
    offset: Offset(0, 16),
    blurRadius: 40,
  );

  static BoxShadow smShadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? sm : smDark;
  static BoxShadow mdShadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? md : mdDark;
  static BoxShadow lgShadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? lg : lgDark;

  /// accent 渐变按钮阴影
  static BoxShadow accentShadow(BuildContext context, {double opacity = 0.35}) => BoxShadow(
        color: AppColors.accent(context).withOpacity(opacity),
        offset: const Offset(0, 6),
        blurRadius: 16,
      );

  /// danger 按钮阴影
  static BoxShadow dangerShadow(BuildContext context, {double opacity = 0.3}) => BoxShadow(
        color: AppColors.error.withOpacity(opacity),
        offset: const Offset(0, 4),
        blurRadius: 12,
      );

  /// 底部 sheet 顶部阴影（替换散落的 Color(0x29000000)）
  static const BoxShadow sheetShadow = BoxShadow(
    color: Color(0x29000000),
    offset: Offset(0, -2),
    blurRadius: 16,
  );
}

abstract class AppTransitions {
  static const Duration instant = Duration(milliseconds: 80);   // 按压
  static const Duration fast = Duration(milliseconds: 150);     // chip/tab
  static const Duration normal = Duration(milliseconds: 250);   // 入场/sheet
  static const Duration slow = Duration(milliseconds: 400);     // 页面
  static const Duration shimmer = Duration(milliseconds: 800);  // 骨架流光
  static const Curve spring = Curves.easeOutCubic;
  static const Curve springBouncy = Curves.elasticOut;
  static const Curve ease = Curves.ease;
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryLight,
    scaffoldBackgroundColor: AppColors.bgLight,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: AppFontSizes.x4l,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.tight,
        color: AppColors.textPrimaryLight,
        letterSpacing: -0.02,
      ),
      displayMedium: TextStyle(
        fontSize: AppFontSizes.xxxl,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.tight,
        color: AppColors.textPrimaryLight,
        letterSpacing: -0.02,
      ),
      displaySmall: TextStyle(
        fontSize: AppFontSizes.xxl,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.snug,
        color: AppColors.textPrimaryLight,
        letterSpacing: -0.02,
      ),
      headlineMedium: TextStyle(
        fontSize: AppFontSizes.xl,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.snug,
        color: AppColors.textPrimaryLight,
      ),
      headlineSmall: TextStyle(
        fontSize: AppFontSizes.lg,
        fontWeight: AppFontWeights.medium,
        height: AppLineHeights.snug,
        color: AppColors.textPrimaryLight,
      ),
      bodyLarge: TextStyle(
        fontSize: AppFontSizes.base,
        fontWeight: AppFontWeights.normal,
        height: AppLineHeights.normal,
        color: AppColors.textPrimaryLight,
      ),
      bodyMedium: TextStyle(
        fontSize: AppFontSizes.sm,
        fontWeight: AppFontWeights.normal,
        height: AppLineHeights.normal,
        color: AppColors.textSecondaryLight,
      ),
      bodySmall: TextStyle(
        fontSize: AppFontSizes.xs,
        fontWeight: AppFontWeights.normal,
        height: AppLineHeights.normal,
        color: AppColors.textTertiaryLight,
      ),
      labelLarge: TextStyle(
        fontSize: AppFontSizes.sm,
        fontWeight: AppFontWeights.medium,
        height: AppLineHeights.tight,
        color: AppColors.textPrimaryLight,
      ),
      labelMedium: TextStyle(
        fontSize: AppFontSizes.xs,
        fontWeight: AppFontWeights.semibold,
        height: AppLineHeights.tight,
        color: AppColors.textTertiaryLight,
        letterSpacing: 0.02,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryDark,
    scaffoldBackgroundColor: AppColors.bgDark,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: AppFontSizes.x4l,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.tight,
        color: AppColors.textPrimaryDark,
        letterSpacing: -0.02,
      ),
      displayMedium: TextStyle(
        fontSize: AppFontSizes.xxxl,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.tight,
        color: AppColors.textPrimaryDark,
        letterSpacing: -0.02,
      ),
      displaySmall: TextStyle(
        fontSize: AppFontSizes.xxl,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.snug,
        color: AppColors.textPrimaryDark,
        letterSpacing: -0.02,
      ),
      headlineMedium: TextStyle(
        fontSize: AppFontSizes.xl,
        fontWeight: AppFontWeights.light,
        height: AppLineHeights.snug,
        color: AppColors.textPrimaryDark,
      ),
      headlineSmall: TextStyle(
        fontSize: AppFontSizes.lg,
        fontWeight: AppFontWeights.medium,
        height: AppLineHeights.snug,
        color: AppColors.textPrimaryDark,
      ),
      bodyLarge: TextStyle(
        fontSize: AppFontSizes.base,
        fontWeight: AppFontWeights.normal,
        height: AppLineHeights.normal,
        color: AppColors.textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        fontSize: AppFontSizes.sm,
        fontWeight: AppFontWeights.normal,
        height: AppLineHeights.normal,
        color: AppColors.textSecondaryDark,
      ),
      bodySmall: TextStyle(
        fontSize: AppFontSizes.xs,
        fontWeight: AppFontWeights.normal,
        height: AppLineHeights.normal,
        color: AppColors.textTertiaryDark,
      ),
      labelLarge: TextStyle(
        fontSize: AppFontSizes.sm,
        fontWeight: AppFontWeights.medium,
        height: AppLineHeights.tight,
        color: AppColors.textPrimaryDark,
      ),
      labelMedium: TextStyle(
        fontSize: AppFontSizes.xs,
        fontWeight: AppFontWeights.semibold,
        height: AppLineHeights.tight,
        color: AppColors.textTertiaryDark,
        letterSpacing: 0.02,
      ),
    ),
  );
}

extension WidgetPad on Widget {
  Padding padAll(double value) => Padding(padding: EdgeInsets.all(value), child: this);
  Padding padSym({double h = 0, double v = 0}) => Padding(padding: EdgeInsets.symmetric(horizontal: h, vertical: v), child: this);
  Padding padOnly({double l = 0, double t = 0, double r = 0, double b = 0}) =>
      Padding(padding: EdgeInsets.only(left: l, top: t, right: r, bottom: b), child: this);
  Expanded expand({int flex = 1}) => Expanded(flex: flex, child: this);
}

extension GapExtension on num {
  SizedBox get gap => SizedBox(width: toDouble(), height: toDouble());
  SizedBox get hGap => SizedBox(height: toDouble());
  SizedBox get wGap => SizedBox(width: toDouble());
}
