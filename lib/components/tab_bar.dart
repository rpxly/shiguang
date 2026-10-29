import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'glass_card.dart';

enum TabType { home, organize, magazine }

class TabBarWidget extends StatelessWidget {
  final TabType currentTab;
  final ValueChanged<TabType> onTabChanged;

  const TabBarWidget({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  static const _tabs = <_TabSpec>[
    _TabSpec(type: TabType.home, icon: Icons.explore_outlined, activeIcon: Icons.explore, label: '首页'),
    _TabSpec(type: TabType.organize, icon: Icons.filter_alt_outlined, activeIcon: Icons.filter_alt, label: '整理'),
    _TabSpec(type: TabType.magazine, icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: '月刊'),
  ];

  int get _activeIndex => _tabs.indexWhere((t) => t.type == currentTab);

  @override
  Widget build(BuildContext context) {
    // 融合版：全宽贴边结构（稳重），材质为液态玻璃
    // —— 72% 厚实填充 + blur 40 + 顶部镜面高光 + 底部暗边发丝线。
    // 激活指示器为滑动式金色药丸：切换时在 Tab 间平滑滑行，
    // 图标交叉淡入 + 触感反馈，明暗双模式自适应。
    final spec = GlassSpec.resolve(context, GlassTier.regular);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
        child: CustomPaint(
          foregroundPainter: GlassHairlinePainter(
            radius: 0,
            topColor: spec.topHighlight,
            bottomColor: spec.bottomHairline,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: spec.fill,
              border: Border(
                top: BorderSide(color: spec.border, width: 0.5),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + AppSpacings.sm,
              top: AppSpacings.xs,
            ),
            child: SizedBox(
              height: AppSpacings.x5l,
              child: Stack(
                children: [
                  // 第 1 层：滑动金色药丸（不拦触摸）。
                  // 必须钉在顶部 30px 图标条带内——如果整栏垂直居中，
                  // 药丸下缘会盖住 Tab 文字。
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 30,
                    child: IgnorePointer(
                      child: AnimatedAlign(
                        // n 个 Tab 均匀分布：x = i/(n-1)*2 - 1，落在 [-1,1]
                        alignment: Alignment(
                          2.0 * _activeIndex / (_tabs.length - 1) - 1.0,
                          0,
                        ),
                        duration: AppTransitions.normal,
                        curve: Curves.easeOutCubic,
                        child: FractionallySizedBox(
                          widthFactor: 1 / _tabs.length,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: AppGradients.accent,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.full),
                                boxShadow: [
                                  AppShadows.accentShadow(context),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 第 2 层：三个可点击 Tab（图标骑在药丸上方）
                  Row(
                    children: [
                      for (final (i, tab) in _tabs.indexed)
                        _TabItem(
                          spec: tab,
                          isActive: i == _activeIndex,
                          onTap: () => onTabChanged(tab.type),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  final TabType type;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabSpec({
    required this.type,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _TabItem extends StatefulWidget {
  final _TabSpec spec;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.spec,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final accent = AppColors.accent(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: widget.spec.label,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () {
            if (!isActive) HapticFeedback.selectionClick();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            // 按压下沉反馈
            scale: _pressed ? 0.92 : 1.0,
            duration: AppTransitions.instant,
            curve: Curves.easeOut,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 30,
                  child: Center(
                    // 图标交叉淡入：描边 ↔ 实底 随激活态切换
                    child: AnimatedSwitcher(
                      duration: AppTransitions.fast,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.6, end: 1.0)
                              .animate(animation),
                          child: child,
                        ),
                      ),
                      child: Icon(
                        isActive
                            ? widget.spec.activeIcon
                            : widget.spec.icon,
                        key: ValueKey(isActive),
                        size: 20,
                        color: isActive
                            ? AppColors.onAccent
                            : AppColors.textTertiary(context),
                      ),
                    ),
                  ),
                ),
                4.gap,
                AnimatedDefaultTextStyle(
                  duration: AppTransitions.fast,
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    fontWeight: isActive
                        ? AppFontWeights.medium
                        : AppFontWeights.normal,
                    color: isActive ? accent : AppColors.textTertiary(context),
                    height: 1.2,
                  ),
                  child: Text(widget.spec.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
