import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'components/app_background.dart';
import 'components/glass_top_scrim.dart';
import 'components/tab_bar.dart';
import 'pages/home_page.dart';
import 'pages/organize_page.dart';
import 'pages/photo_detail_page.dart';
import 'pages/settings_page.dart';
import 'pages/monthly_magazine_page.dart';
import 'pages/cleanup_suggestion_page.dart';
import 'pages/curated_photos_page.dart';
import 'app_state.dart';
import 'models/photo.dart';
import 'services/database_service.dart';
import 'services/photo_scanner_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const LoadingApp(),
    ),
  );
}

class LoadingApp extends StatefulWidget {
  const LoadingApp({super.key});

  @override
  State<LoadingApp> createState() => _LoadingAppState();
}

class _LoadingAppState extends State<LoadingApp> with SingleTickerProviderStateMixin {
  DatabaseService? _databaseService;
  bool _isLoaded = false;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      final databaseService = DatabaseService();
      await databaseService.initialize();
      if (!databaseService.hasPermission) {
        if (mounted) {
          setState(() {
            _databaseService = databaseService;
            _permissionDenied = true;
            _isLoaded = true;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _databaseService = databaseService;
          _isLoaded = true;
        });
      }
      final autoScan = databaseService.repository.getAutoScan();
      if (autoScan) {
        // 扫描延迟到首帧渲染完成后，缩短冷启动白屏时间
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) databaseService.startScanning();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _retryPermission() async {
    final db = _databaseService ?? DatabaseService();
    final status = await db.requestPhotoPermission();
    if (status == PhotoPermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _permissionDenied = false;
          _databaseService = db;
        });
      }
      db.startScanning();
    }
  }

  String _getLoadingMessage() {
    if (_databaseService == null) return '正在准备你的记忆空间...';
    if (!_databaseService!.scanningComplete) return '正在扫描照片...';
    return '正在准备你的记忆空间...';
  }

  /// 启动屏在 MaterialApp 主题生效前渲染，需根据系统暗色模式自选 token。
  bool get _isDark => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final textInverse = isDark ? AppColors.textInverseDark : AppColors.textInverseLight;
    // 状态栏图标色：浅色背景用 dark，暗色背景用 light
    final overlayStyle = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    if (_error != null) {
      return MaterialApp(
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Scaffold(
            backgroundColor: bg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ErrorIcon(isDark: isDark),
                  20.gap,
                  Text('初始化失败', style: TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.medium, color: textPrimary)),
                  8.gap,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text('$_error', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppFontSizes.sm, color: textSecondary)),
                  ),
                  24.gap,
                  ElevatedButton.icon(
                    onPressed: () { setState(() { _error = null; }); _initDatabase(); },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重试'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: textInverse,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isLoaded && _permissionDenied && _databaseService != null) {
      return MaterialApp(
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Scaffold(
            backgroundColor: bg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(AppOpacities.accentBg),
                        borderRadius: BorderRadius.circular(AppRadii.xxl),
                      ),
                      child: Icon(Icons.photo_library_outlined, size: 36, color: accent),
                    ),
                    24.gap,
                    Text('需要相册权限', style: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: AppFontWeights.medium, color: textPrimary)),
                    12.gap,
                    Text('拾光需要访问你的相册才能扫描和整理照片\n请允许访问相册',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppFontSizes.sm, color: textSecondary, height: 1.6)),
                    32.gap,
                    ElevatedButton.icon(
                      onPressed: _retryPermission,
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('授予权限'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: textInverse,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                    ),
                    16.gap,
                    Text('若已拒绝，请前往「设置 → 应用 → 拾光 → 权限」手动开启',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppFontSizes.xs, color: textTertiary, height: 1.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_isLoaded || _databaseService == null) {
      return MaterialApp(
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Scaffold(
            backgroundColor: bg,
            body: Center(
              child: _LoadingContent(message: _getLoadingMessage(), isDark: isDark),
            ),
          ),
        ),
      );
    }

    return AiAlbumApp(databaseService: _databaseService!);
  }
}

class _ErrorIcon extends StatelessWidget {
  final bool isDark;
  const _ErrorIcon({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: const Icon(Icons.error_outline, size: 32, color: AppColors.error),
    );
  }
}

class _LoadingContent extends StatefulWidget {
  final String message;
  final bool isDark;
  const _LoadingContent({required this.message, required this.isDark});
  @override
  State<_LoadingContent> createState() => _LoadingContentState();
}

class _LoadingContentState extends State<_LoadingContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDark ? AppColors.accentDark : AppColors.accentLight;
    final bgSubtle = widget.isDark ? AppColors.bgSubtleDark : AppColors.bgSubtleLight;
    final textPrimary = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Opacity(opacity: _pulse.value, child: child),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              boxShadow: [BoxShadow(color: accent.withOpacity(AppOpacities.accentShadow), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: const Center(child: Text('拾', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: Colors.white))),
          ),
          24.gap,
          Text('拾光', style: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: AppFontWeights.light, color: textPrimary, letterSpacing: 4)),
          12.gap,
          Text(widget.message, style: TextStyle(fontSize: AppFontSizes.sm, color: textSecondary)),
          32.gap,
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: LinearProgressIndicator(
                backgroundColor: bgSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AiAlbumApp extends StatefulWidget {
  final DatabaseService databaseService;
  const AiAlbumApp({super.key, required this.databaseService});

  @override
  State<AiAlbumApp> createState() => _AiAlbumAppState();
}

class _AiAlbumAppState extends State<AiAlbumApp> {
  int _themeModeIndex = 0;

  @override
  void initState() {
    super.initState();
    _themeModeIndex = widget.databaseService.repository.getThemeMode();
  }

  void _onThemeChanged(int index) => setState(() => _themeModeIndex = index);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DatabaseService>.value(
      value: widget.databaseService,
      child: MaterialApp(
        title: '拾光 — 拾起散落的光阴',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.values[_themeModeIndex],
        // 全局环境光层：所有页面背景透明，玻璃面板才有东西可透。
        builder: (context, child) => AppBackground(child: child ?? const SizedBox.shrink()),
        home: MainScreen(databaseService: widget.databaseService, onThemeChanged: _onThemeChanged),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final ValueChanged<int>? onThemeChanged;

  const MainScreen({super.key, required this.databaseService, this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  TabType _currentTab = TabType.home;
  final Set<TabType> _instantiatedTabs = {TabType.home};

  /// 首次访问时才创建页面，已访问的 Tab 由 Offstage 保活。
  void _goToTab(TabType tab) {
    setState(() {
      _instantiatedTabs.add(tab);
      _currentTab = tab;
    });
  }

  void _onTabChanged(TabType tab) {
    if (tab == _currentTab) return;
    _goToTab(tab);
  }

  void _onSettingsTap() => context.read<AppState>().showSettingsPage();

  void _onScreenshotFilter() => _goToTab(TabType.organize);

  void _onPhotoTap(Photo photo) => context.read<AppState>().selectPhoto(photo);

  Widget _buildTabPage(TabType tab, DatabaseService db) {
    switch (tab) {
      case TabType.home:
        return HomePage(
          key: const ValueKey('home'),
          repository: db.repository,
          onMagazineTap: () => _goToTab(TabType.magazine),
          onScreenshotFilter: _onScreenshotFilter,
          onSettingsTap: _onSettingsTap,
          onScanTap: () => db.startScanning(forceScan: true),
          onCleanupTap: () => context.read<AppState>().showCleanupPage(),
          onCuratedTap: () => context.read<AppState>().showCuratedPage(),
          isScanning: db.isScanning,
          scannedCount: db.scannedCount,
          scanningComplete: db.scanningComplete,
          scanTotal: db.scanTotal,
        );
      case TabType.organize:
        return OrganizePage(
          key: const ValueKey('organize'),
          repository: db.repository,
          onPhotoTap: _onPhotoTap,
          isScanning: db.isScanning,
          scannedCount: db.scannedCount,
          scanningComplete: db.scanningComplete,
        );
      case TabType.magazine:
        return MonthlyMagazinePage(
          key: const ValueKey('magazine'),
          initialYear: DateTime.now().year,
          initialMonth: DateTime.now().month,
          repository: db.repository,
          onBack: () => _goToTab(TabType.home),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final db = context.watch<DatabaseService>();

    if (appState.showPhotoDetail && appState.selectedPhoto != null) {
      return PageTransition(
        child: PhotoDetailPage(
          photo: appState.selectedPhoto!,
          repository: widget.databaseService.repository,
          onBack: () => appState.closePhotoDetail(),
          onDelete: () async {
            if (appState.selectedPhoto != null) {
              await widget.databaseService.repository.deletePhoto(appState.selectedPhoto!.id);
              appState.closePhotoDetail();
            }
          },
          onSimilarPhotoTap: (photo) => appState.selectPhoto(photo),
        ),
      );
    }

    if (appState.showSettings) {
      return PageTransition(
        child: SettingsPage(
          repository: widget.databaseService.repository,
          onBack: () => appState.closeSettingsPage(),
          onThemeChanged: widget.onThemeChanged,
        ),
      );
    }

    if (appState.showCleanup) {
      return PageTransition(
        child: CleanupSuggestionPage(
          repository: widget.databaseService.repository,
          onBack: () => appState.closeCleanupPage(),
        ),
      );
    }

    if (appState.showCurated) {
      return PageTransition(
        child: CuratedPhotosPage(
          repository: widget.databaseService.repository,
          onBack: () => appState.closeCuratedPage(),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final tab in TabType.values)
                    if (_instantiatedTabs.contains(tab))
                      Offstage(
                        offstage: tab != _currentTab,
                        child: TickerMode(
                          enabled: tab == _currentTab,
                          child: _TabReveal(
                            active: tab == _currentTab,
                            child: _buildTabPage(tab, db),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
            // 状态栏玻璃衬底：盖在 SafeArea 之上、内容之下滚动的层
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassTopScrim(),
            ),
          ],
        ),
        bottomNavigationBar: TabBarWidget(currentTab: _currentTab, onTabChanged: _onTabChanged),
      ),
    );
  }
}

class PageTransition extends StatefulWidget {
  final Widget child;
  const PageTransition({super.key, required this.child});

  @override
  State<PageTransition> createState() => _PageTransitionState();
}

/// Tab 切换时的内容过渡：每次变为激活 Tab 时重放一次
/// 淡入 + 轻微上移。页面本身由 Offstage 保活，状态不丢。
class _TabReveal extends StatefulWidget {
  final bool active;
  final Widget child;

  const _TabReveal({required this.active, required this.child});

  @override
  State<_TabReveal> createState() => _TabRevealState();
}

class _TabRevealState extends State<_TabReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTransitions.normal,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.active) _controller.value = 1;
  }

  @override
  void didUpdateWidget(_TabReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _PageTransitionState extends State<PageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTransitions.normal,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}
