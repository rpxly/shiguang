import 'package:flutter/material.dart';
import '../app_version.dart';
import '../theme.dart';
import '../components/nav_header.dart';
import '../components/glass_card.dart';
import '../components/staggered_fade_in.dart';
import '../repository/local_repository.dart';
import '../components/app_background.dart';
import 'website_page.dart';

class SettingsPage extends StatefulWidget {
  final LocalRepository repository;
  final VoidCallback onBack;
  final ValueChanged<int>? onThemeChanged;

  const SettingsPage({
    super.key,
    required this.repository,
    required this.onBack,
    this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _themeMode = 0;
  bool _autoScan = true;
  bool _autoFetchQuotes = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _themeMode = widget.repository.getThemeMode();
    _autoScan = widget.repository.getAutoScan();
    _autoFetchQuotes = widget.repository.getAutoFetchQuotes();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            NavHeader(title: '设置', onBack: widget.onBack),
            24.hGap,
            StaggeredFadeIn(index: 0, child: _buildAppearanceSection(context)),
            24.hGap,
            StaggeredFadeIn(index: 1, child: _buildAppSettingsSection(context)),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, '外观', Icons.palette_outlined),
            16.hGap,
            _themeOption(context, '跟随系统', '根据系统设置自动切换', ThemeMode.system, Icons.settings_suggest_outlined),
            8.hGap,
            _themeOption(context, '浅色模式', '始终使用浅色主题', ThemeMode.light, Icons.light_mode_outlined),
            8.hGap,
            _themeOption(context, '深色模式', '始终使用深色主题', ThemeMode.dark, Icons.dark_mode_outlined),
          ],
        ),
      ),
    );
  }

  int _themeModeFor(ThemeMode mode) => ThemeMode.values.indexOf(mode);

  Widget _themeOption(BuildContext context, String label, String subtitle, ThemeMode mode, IconData icon) {
    final modeIndex = _themeModeFor(mode);
    final isSelected = _themeMode == modeIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _themeMode = modeIndex);
        widget.repository.setThemeMode(modeIndex);
        widget.onThemeChanged?.call(modeIndex);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? context.accent.withOpacity(AppOpacities.accentBg) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isSelected ? context.accent.withOpacity(AppOpacities.accentBorder) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Icon(icon, size: 18, color: context.accent),
            ),
            16.wGap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(gradient: AppGradients.accent, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: AppColors.onAccent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, '应用', Icons.widgets_outlined),
            16.hGap,
            _toggleItem(context, '启动时自动扫描照片', '应用启动时自动检测新照片', _autoScan, (v) { setState(() => _autoScan = v); widget.repository.setAutoScan(v); }),
            12.hGap,
            _toggleItem(context, '联网自动获取文案', '进入文案库时自动抓取热门句子', _autoFetchQuotes, (v) { setState(() => _autoFetchQuotes = v); widget.repository.setAutoFetchQuotes(v); }),
            12.hGap,
            _infoRow(context, '应用版本', kAppVersion),
            12.hGap,
            _linkRow(context, '官方网站', 'rpxly.github.io/shiguang'),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(BuildContext context, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
              4.hGap,
              Text(subtitle, style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
            ],
          ),
        ),
        Switch(value: value, activeColor: context.accent, onChanged: onChanged),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
        Text(value, style: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary)),
      ],
    );
  }

  Widget _linkRow(BuildContext context, String label, String value) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WebsitePage(onBack: () => Navigator.of(context).pop()),
        ));
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary)),
                4.hGap,
                Text(value, style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(gradient: AppGradients.accentSoft, borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Icon(icon, size: 16, color: AppColors.onAccent),
        ),
        8.wGap,
        Text(title, style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: context.textPrimary)),
      ],
    );
  }
}
