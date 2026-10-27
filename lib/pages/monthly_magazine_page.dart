import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../components/glass_card.dart';
import '../models/photo.dart';
import '../models/quote.dart';
import '../repository/local_repository.dart';
import '../services/analytics_service.dart';
import '../services/monthly_recap_service.dart';
import '../services/quote_service.dart';
import '../services/scene_classifier_service.dart';
import '../services/steps_service.dart';
import '../theme.dart';
import 'monthly/magazine_a4.dart';
import 'monthly/magazine_editor.dart';
import 'monthly/magazine_models.dart';
import 'monthly/magazine_sheets.dart';
import 'monthly/magazine_timeline.dart';
import 'monthly/quote_picker_sheet.dart';

// 兼容旧的引用路径：数据模型仍可从本文件导入
export 'monthly/magazine_models.dart';

class MonthlyMagazinePage extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final LocalRepository repository;
  final VoidCallback onBack;

  const MonthlyMagazinePage({
    super.key,
    required this.initialYear,
    required this.initialMonth,
    required this.repository,
    required this.onBack,
  });

  @override
  State<MonthlyMagazinePage> createState() => _MonthlyMagazinePageState();
}

class _MonthlyMagazinePageState extends State<MonthlyMagazinePage> {
  late int _year;
  late int _month;
  List<MagPage> _pages = [];
  List<Photo> _monthPhotos = [];
  bool _loading = true;
  final Map<String, GlobalKey> _timelineExportKeys = {};
  final GlobalKey _a4Key = GlobalKey();
  bool _preparingA4 = false;
  // 图片尺寸缓存：photoId -> (width, height)
  final Map<String, ImgSize> _imgSizeCache = {};
  // ─── 可编辑的杂志元数据 ───
  String _userMood = '普通';
  String _userWeather = '晴';
  int _healthSteps = 0;
  final TextEditingController _summaryController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // ─── 文案来源：从文案库（QuoteService）随机取一条 ───
  // 含作者/出处时格式「文案 — 作者」，否则仅文案
  // 已导入的照片 id 记录在此，避免短时间内重复抽到同一条
  final Set<String> _usedQuoteIds = {};
  List<Quote>? _cachedQuotePool;

  /// 从文案库随机生成一条导入文案
  String _randomCaption(DateTime date) {
    _cachedQuotePool ??= QuoteService().allQuotes;
    final pool = _cachedQuotePool!;
    if (pool.isEmpty) return '${date.month}月${date.day}日，时光留痕';
    // 优先选未用过的
    final available = pool.where((q) => !_usedQuoteIds.contains(q.id)).toList();
    final candidates = available.isEmpty ? pool : available;
    final quote = candidates[DateTime.now().microsecond % candidates.length];
    _usedQuoteIds.add(quote.id);
    // 限制缓存大小，避免无限增长
    if (_usedQuoteIds.length > pool.length) _usedQuoteIds.clear();
    final author = quote.author ?? quote.source;
    return author != null && author.isNotEmpty ? '${quote.text} — $author' : quote.text;
  }

  int get _photoCount => _monthPhotos.length;
  int get _travelDays => _monthPhotos.map((p) => p.dateTime.day).toSet().length;
  int get _eventsCount => _monthPhotos.length > 10 ? 3 : (_monthPhotos.length > 5 ? 2 : 1);
  /// 步数：优先自动读取系统健康数据，用户手动填写后以手动值为准
  int get _totalSteps => _healthSteps;

  /// 规则版月度摘要：只把本月照片里已有的事实排成三句话。
  /// 端侧 AI 叙事接入后复用同一份 MonthlyFacts 与同一处 UI 落点，便于直接对比。
  static const MonthlyRecapService _recapService = MonthlyRecapService();

  MonthlyFacts get _monthFacts => _recapService.collectFacts(
        _monthPhotos,
        year: _year,
        month: _month,
        sceneOf: SceneClassifier.instance.labelFor,
        placeOf: SceneClassifier.readablePlace,
      );

  List<String> get _keywords => _recapService.keywordsFor(_monthFacts);

  /// 漏斗第 3 段：本页确实产出了内容（摘要/文案/手输/加页面）。
  /// 同一次进入只记一条，`source` 记最先发生的那个来源，方便回查是哪条路走通了。
  bool _generatedLogged = false;
  void _logGenerated(String source) {
    if (_generatedLogged) return;
    _generatedLogged = true;
    AnalyticsService.instance.log(
      AnalyticsEvent.magazineGenerated,
      props: {'source': source, 'photos': _monthPhotos.length},
    );
  }

  /// 一键生成月度摘要并写入「本月总结」。
  void _generateRecap() {
    if (_monthPhotos.isEmpty) return;
    final recap = _recapService.build(
      _monthFacts,
      mood: _userMood,
      weather: _userWeather,
      steps: _healthSteps,
    );
    if (recap == null) return;
    HapticFeedback.lightImpact();
    setState(() => _summaryController.text = recap.text);
    _persistMeta();
    _logGenerated('rule');
  }

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    // 漏斗第 2 段：进入月刊页
    AnalyticsService.instance.log(
      AnalyticsEvent.magazineOpened,
      props: {'y': _year, 'm': _month},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAsync());
  }

  Future<void> _loadAsync() async {
    setState(() => _loading = true);
    try {
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      // 加载已有杂志页面（用户主动导入的），单条解析失败跳过
      final stored = widget.repository.getMagazinePages(_year, _month);
      final pages = <MagPage>[];
      for (final j in stored) {
        try {
          pages.add(MagPage.fromJson(j));
        } catch (e) {
          debugPrint('[MagPage] 单条解析失败，跳过: $e');
        }
      }
      // 同步构建 _monthPhotos，getPhoto 返回 null 时从 pages 移除该 MagPage（保持一致性）
      final photos = <Photo>[];
      final validPages = <MagPage>[];
      for (final p in pages) {
        if (p.photoIds.isEmpty) {
          debugPrint('[MagPage] 跳过 photoIds 为空的 MagPage: ${p.id}');
          continue;
        }
        final photo = widget.repository.getPhoto(p.photoIds.first);
        if (photo == null) {
          debugPrint('[MagPage] Photo 不存在，跳过 MagPage: ${p.id} (photoId=${p.photoIds.first})');
          continue;
        }
        validPages.add(p);
        photos.add(photo);
      }
      _pages = validPages;
      _monthPhotos = photos;
      // 若有过滤掉的无效数据，回写修正存储
      if (_pages.length != pages.length) {
        _persist();
      }
      _imgSizeCache.clear();
      // 并行加载所有图片尺寸，避免串行阻塞
      final futures = <Future<ImgSize?>>[];
      final paths = <String>[];
      for (final photo in _monthPhotos) {
        if (!_imgSizeCache.containsKey(photo.path)) {
          paths.add(photo.path);
          futures.add(_getImageSize(photo.path));
        }
      }
      final results = await Future.wait(futures);
      for (var i = 0; i < results.length; i++) {
        if (results[i] != null) _imgSizeCache[paths[i]] = results[i]!;
      }
      if (mounted) setState(() => _loading = false);
      _loadMagazineMeta();
    } catch (e) {
      debugPrint('[MagPage] _loadAsync 异常: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadMagazineMeta() {
    final meta = widget.repository.getMagazineMeta(_year, _month);
    if (meta != null) {
      setState(() {
        _userMood = meta['mood'] as String? ?? _userMood;
        _userWeather = meta['weather'] as String? ?? _userWeather;
        _healthSteps = meta['healthSteps'] as int? ?? 0;
      });
      final savedSummary = meta['summary'] as String? ?? '';
      if (savedSummary.isNotEmpty) {
        _summaryController.text = savedSummary;
      }
    }
    // 自动读取健康步数：用户未手动填写时才尝试（手动填写优先，避免覆盖用户输入）
    if (_healthSteps == 0) {
      _autoFetchSteps();
    }
  }

  /// 从系统健康数据（Health Connect）读取本月总步数。
  /// 读取失败或无权限时静默降级，保持手动填写入口可用。
  Future<void> _autoFetchSteps() async {
    // 诊断：打印 Health Connect 原始记录（排查与健康 App 数据不一致）
    final monthStart = DateTime(_year, _month, 1);
    final now0 = DateTime.now();
    await StepsService.debugDumpRawRecords(monthStart, now0);
    final steps = await StepsService.getMonthlySteps(_year, _month);
    if (steps == null || steps <= 0) return;
    if (!mounted) return;
    setState(() => _healthSteps = steps);
    _persistMeta();
  }

  void _persist() {
    widget.repository.saveMagazinePages(_year, _month, _pages.map((p) => p.toJson()).toList());
    _persistMeta();
  }

  void _persistMeta() {
    widget.repository.saveMagazineMeta(_year, _month, {
      'mood': _userMood,
      'weather': _userWeather,
      'summary': _summaryController.text,
      'healthSteps': _healthSteps,
    });
  }

  void _prev() {
    if (_month == 1) { _year--; _month = 12; } else { _month--; }
    _loadAsync();
  }

  void _next() {
    if (_month == 12) { _year++; _month = 1; } else { _month++; }
    _loadAsync();
  }

  /// 异步获取图片真实尺寸（用于横竖自适应）
  /// 优先用 Flutter 的 ImageProvider 解析（支持所有平台原生格式），
  /// 失败后回退到 image 包 decodeImage。
  Future<ImgSize?> _getImageSize(String path) async {
    if (_imgSizeCache.containsKey(path)) return _imgSizeCache[path];
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[MagPage] 图片文件不存在: $path');
        // 写入占位尺寸，避免下次重复尝试（resolveImageHeight 会走 minHeight 默认值）
        _imgSizeCache[path] = ImgSize(1, 1);
        return _imgSizeCache[path];
      }

      // 方式1：用 Flutter ImageProvider 解析（支持 HEIC/WebP 等原生格式）
      try {
        final completer = Completer<ImgSize>();
        final imageProvider = FileImage(file);
        final stream = imageProvider.resolve(const ImageConfiguration());
        late ImageStreamListener listener;
        listener = ImageStreamListener((info, _) {
          completer.complete(ImgSize(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ));
          stream.removeListener(listener);
        }, onError: (e, _) {
          completer.completeError(e);
          stream.removeListener(listener);
        });
        stream.addListener(listener);
        final size = await completer.future.timeout(const Duration(seconds: 5));
        _imgSizeCache[path] = size;
        return size;
      } catch (e) {
        debugPrint('[MagPage] ImageProvider 解析失败: $e ($path)');
        // 解析失败也写入占位，避免重复尝试
        _imgSizeCache[path] = ImgSize(1, 1);
        return _imgSizeCache[path];
      }
    } catch (e) {
      debugPrint('[MagPage] 获取图片尺寸异常: $e ($path)');
      _imgSizeCache[path] = ImgSize(1, 1);
      return _imgSizeCache[path];
    }
  }

  // ─── 底部面板 / 编辑器编排（实现见 monthly/*）──────────────────
  Future<void> _showImporter() {
    return showImporter(
      context: context,
      year: _year,
      month: _month,
      pages: _pages,
      monthPhotos: _monthPhotos,
      imgSizeCache: _imgSizeCache,
      picker: _picker,
      repository: widget.repository,
      randomCaption: _randomCaption,
      loadImageSize: _getImageSize,
      persist: _persist,
      setLoading: (v) => setState(() => _loading = v),
    );
  }

  void _showMoodPicker(BuildContext context) {
    showMoodPicker(context, current: _userMood, onSelected: (m) {
      setState(() => _userMood = m);
      _persistMeta();
    });
  }

  void _showWeatherPicker(BuildContext context) {
    showWeatherPicker(context, current: _userWeather, onSelected: (w) {
      setState(() => _userWeather = w);
      _persistMeta();
    });
  }

  void _showStepsPicker(BuildContext context) {
    showStepsPicker(context, year: _year, month: _month, currentSteps: _healthSteps, onSaved: (v) {
      setState(() => _healthSteps = v);
      _persistMeta();
    });
  }

  void _editCaption(MagPage page) {
    editCaption(context, page: page, year: _year, month: _month, repository: widget.repository, onSaved: () {
      _persist();
      setState(() {});
    });
  }

  /// 从文案库挑选一条作为本月总结
  Future<void> _pickSummaryQuote() async {
    final quote = await showQuotePicker(context, repository: widget.repository);
    if (quote == null) return;
    _summaryController.text = formatQuoteAsCaption(quote);
    _persistMeta();
    _logGenerated('quote');
  }

  void _changeTemplate(MagPage page) {
    showTemplateEditor(
      context: context,
      page: page,
      year: _year,
      month: _month,
      photo: widget.repository.getPhoto(page.photoIds.first),
      imgSizeCache: _imgSizeCache,
      loadImageSize: _getImageSize,
      persist: _persist,
      onChanged: () => setState(() {}),
    );
  }

  void _showShareOptions() {
    showShareOptions(
      context,
      onSingleExport: _showSingleExportPicker,
      onCaptureA4: _captureA4,
    );
  }

  void _showSingleExportPicker() {
    showSingleExportPicker(context, photos: _monthPhotos, onExport: _exportSinglePhoto);
  }

  Future<void> _captureA4() {
    return captureA4(
      context: context,
      a4Key: _a4Key,
      year: _year,
      month: _month,
      photos: _monthPhotos,
      onPreparing: (v) => setState(() => _preparingA4 = v),
    );
  }

  Future<void> _confirmDeletePhoto(Photo photo) {
    return confirmDeleteTimelinePhoto(context, photo, year: _year, month: _month, onConfirmed: () {
      setState(() {
        _monthPhotos.removeWhere((p) => p.id == photo.id);
        final idx = _pages.indexWhere((p) => p.photoIds.contains(photo.id));
        if (idx >= 0) {
          _pages.removeAt(idx);
          _persist();
        }
      });
    });
  }

  Future<void> _createMagPage(Photo photo) async {
    final page = MagPage(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}_${photo.id}',
      photoIds: [photo.id],
      template: MagTemplate.bottomWhite,
      caption: _randomCaption(photo.dateTime),
    );
    setState(() => _pages.add(page));
    _persist();
    _logGenerated('page_add');
  }

  Future<void> _exportSinglePhoto(Photo photo) async {
    final key = _timelineExportKeys[photo.id];
    if (key?.currentContext == null) return;
    HapticFeedback.lightImpact();
    try {
      final boundary = key!.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}${Platform.pathSeparator}photo_${photo.id}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      final result = await Share.shareXFiles([XFile(file.path)], text: '${_year}年${_month}月');
      // 漏斗第 4 段：分享面板已唤起即记「导出」。
      // status 只作诊断参考 —— Android 上 share_plus 常返回 unavailable，
      // 不能用它判「对方是否收到」，所以不拿 status 卡事件。
      AnalyticsService.instance.log(
        AnalyticsEvent.magazineExported,
        props: {'type': 'single', 'status': result.status.name},
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  Future<void> _exportSingleAsTemplate(BuildContext context, Photo photo, MagPage? existingPage) async {
    if (existingPage != null) {
      _changeTemplate(existingPage);
    } else {
      final page = MagPage(
        id: 'tmp_${photo.id}',
        photoIds: [photo.id],
        template: MagTemplate.bottomWhite,
        caption: '',
      );
      _changeTemplate(page);
    }
  }

  // ─── 月度概览头部 ──────────────────────────────────────────────
  Widget _buildMonthHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
      child: GlassCard(
        borderRadius: AppRadii.lg,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    boxShadow: [AppShadows.accentShadow(context)],
                  ),
                  child: Center(child: Text(_month.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: AppFontSizes.lg, fontWeight: AppFontWeights.semibold, color: AppColors.onAccent))),
                ),
                16.wGap,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_year}年${_month}月',
                        style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: AppColors.textPrimary(context))),
                      4.hGap,
                      Text('$_photoCount 张照片 · $_travelDays 天出行 · $_eventsCount 个重要事件',
                        style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textSecondary(context))),
                      2.hGap,
                      // 口径说明（#11-①）：页面上的张数/天数/摘要都只统计「用户导入
                      // 进来的照片」，不是「本月拍的全部照片」。用户看到数字对不上
                      // 相册总数时会以为算错了，这里明写一句。
                      Text('仅统计已导入本月的照片，非本月全部拍摄',
                        style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
                    ],
                  ),
                ),
              ],
            ),
            12.hGap,
            Container(height: 1, color: AppColors.divider(context)),
            12.hGap,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(onTap: () => _showMoodPicker(context), child: _buildStatItem(context, '心情', _userMood, magMoodIcon(_userMood))),
                GestureDetector(onTap: () => _showWeatherPicker(context), child: _buildStatItem(context, '天气', _userWeather, magWeatherIcon(_userWeather))),
                GestureDetector(onTap: () => _showStepsPicker(context), child: _buildStatItem(context, '步数', _totalSteps > 0 ? '$_totalSteps' : '点击填写', Icons.directions_walk)),
              ],
            ),
            Container(height: 1, color: AppColors.divider(context)),
            12.hGap,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 总结输入区 + 生成入口（智能摘要 / 选文案）
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_monthPhotos.isNotEmpty) ...[
                      _summaryAction(
                        context,
                        icon: Icons.auto_awesome,
                        label: '智能摘要',
                        onTap: _generateRecap,
                      ),
                      12.wGap,
                    ],
                    _summaryAction(
                      context,
                      icon: Icons.format_quote,
                      label: '选文案',
                      onTap: _pickSummaryQuote,
                    ),
                  ],
                ),
                4.hGap,
                TextField(
                  controller: _summaryController,
                  onChanged: (value) {
                    _persistMeta();
                    // 手输也算「产出」，但空串（清空动作）不算
                    if (value.trim().isNotEmpty) _logGenerated('manual');
                  },
                  maxLines: 3,
                  style: TextStyle(fontSize: AppFontSizes.sm, color: AppColors.textSecondary(context), height: 1.6),
                  decoration: InputDecoration(
                    hintText: '点击编辑本月总结…',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
            // 关键词行：没有真实关键词时**整行不显示**（2026-10-27 决策）。
            // 旧版这里会兜底硬编码「生活/记忆/时光」，那是放之四海皆准的空话；
            // 宁可留白，也不要让用户以为这些词是从他的照片里识别出来的。
            if (_keywords.isNotEmpty) ...[
              12.hGap,
              Wrap(spacing: 6, runSpacing: 6,
                children: _keywords.map((kw) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accent(context).withOpacity(AppOpacities.accentBg), borderRadius: BorderRadius.circular(999)),
                  child: Text(kw, style: TextStyle(fontSize: AppFontSizes.xs, fontWeight: AppFontWeights.medium, color: AppColors.accent(context))),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 总结区右上角的小动作按钮（智能摘要 / 选文案）。
  Widget _summaryAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.accent(context)),
            4.wGap,
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                fontWeight: AppFontWeights.medium,
                color: AppColors.accent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: GlassColors.surface(context), borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Icon(icon, size: 16, color: AppColors.accent(context)),
        ),
        4.hGap,
        Text(value, style: TextStyle(fontSize: AppFontSizes.base, fontWeight: AppFontWeights.medium, color: AppColors.textPrimary(context))),
        Text(label, style: TextStyle(fontSize: AppFontSizes.xs, color: AppColors.textTertiary(context))),
      ],
    );
  }

  // ─── 时光线视图 ────────────────────────────────────────────────
  Widget _buildTimelineView(BuildContext context) {
    return buildTimelineView(MagazineTimelineHost(
      context: context,
      year: _year,
      month: _month,
      photos: _monthPhotos,
      pages: _pages,
      imgSizeCache: _imgSizeCache,
      exportKeys: _timelineExportKeys,
      randomCaption: _randomCaption,
      onCaptureA4: _captureA4,
      onEditCaption: _editCaption,
      onCreatePage: _createMagPage,
      onEditTemplate: (photo, page) {
        _exportSingleAsTemplate(context, photo, page);
      },
      onExportPhoto: _exportSinglePhoto,
      onDeletePhoto: _confirmDeletePhoto,
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tab 子页：背景交给全局环境光层，避免与主屏之间出现渐变接缝
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: AppSpacings.lg),
                  _buildMonthNav(context),
                  const SizedBox(height: AppSpacings.lg),
                  if (_loading)
                    _buildSkeleton(context)
                  else ...[
                    _buildMonthHeader(context),
                    24.hGap,
                    if (_monthPhotos.isEmpty)
                      buildTimelineEmpty(context, onImport: _showImporter)
                    else
                      _buildTimelineView(context),
                  ],
                  const SizedBox(height: AppSpacings.x6l),
                ],
              ),
            ),
            if (_preparingA4)
              Positioned(left: -9999, top: -9999,
                child: RepaintBoundary(key: _a4Key, child: buildA4Layout(context, _year, _month, _monthPhotos)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacings.xl, AppSpacings.sm, AppSpacings.xl, 0),
      child: Row(
        children: [
          _iconBtn(context, Icons.add_photo_alternate_outlined, _showImporter, tooltip: '导入照片'),
          const Spacer(),
          Text('月刊', style: TextStyle(fontSize: AppFontSizes.xs, fontWeight: AppFontWeights.medium, color: AppColors.textTertiary(context), letterSpacing: 2)),
          const Spacer(),
          if (_monthPhotos.isNotEmpty)
            _iconBtn(context, Icons.share, _showShareOptions, tooltip: '分享'),
        ],
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap, {String? tooltip}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: GlassColors.bg(context),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: GlassColors.borderSubtle(context), width: 1),
          ),
          child: Icon(icon, size: 18, color: AppColors.textTertiary(context)),
        ),
      ),
    );
  }

  Widget _buildMonthNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navBtn(context, Icons.chevron_left, _prev),
          const SizedBox(width: AppSpacings.md),
          Text('$_year / ${_month.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: AppFontSizes.sm, fontWeight: AppFontWeights.medium, color: AppColors.textPrimary(context), letterSpacing: 1)),
          const SizedBox(width: AppSpacings.md),
          _navBtn(context, Icons.chevron_right, _next),
        ],
      ),
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: GlassColors.bg(context),
          border: Border.all(color: GlassColors.border(context)),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary(context)),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? AppSpacings.lg : 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.divider(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < 2) Expanded(child: Container(width: 1, color: AppColors.divider(context))),
                    ],
                  ),
                ),
                12.wGap,
                Expanded(
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: GlassColors.surface(context),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }
}
