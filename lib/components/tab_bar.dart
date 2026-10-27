import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

enum TabType { home, organize, magazine }

class TabBarWidget extends StatelessWidget {
  final TabType currentTab;
  final ValueChanged<TabType> onTabChanged;

  const TabBarWidget({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spec = GlassSpec.resolve(context, GlassTier.regular);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + AppSpacings.lg,
            top: AppSpacings.sm,
          ),
          decoration: BoxDecoration(
            color: spec.fill,
            border: Border(
              top: BorderSide(
                color: spec.border,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(
                type: TabType.home,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: '首页',
                isActive: currentTab == TabType.home,
                onTap: () => onTabChanged(TabType.home),
              ),
              _TabItem(
                type: TabType.organize,
                icon: Icons.filter_alt_outlined,
                activeIcon: Icons.filter_alt,
                label: '整理',
                isActive: currentTab == TabType.organize,
                onTap: () => onTabChanged(TabType.organize),
              ),
              _TabItem(
                type: TabType.magazine,
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome,
                label: '月刊',
                isActive: currentTab == TabType.magazine,
                onTap: () => onTabChanged(TabType.magazine),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final TabType type;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.type,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacings.x5l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppTransitions.fast,
                  curve: AppTransitions.spring,
                  width: 48,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: isActive ? AppGradients.accent : null,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    boxShadow: isActive
                        ? [AppShadows.accentShadow(context)]
                        : null,
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 20,
                    color: isActive ? AppColors.onAccent : AppColors.textTertiary(context),
                  ),
                ),
                4.gap,
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    fontWeight: isActive ? AppFontWeights.medium : AppFontWeights.normal,
                    color: isActive ? accent : AppColors.textTertiary(context),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
