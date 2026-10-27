import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../components/app_button.dart';
import '../components/app_dialog.dart';
import '../components/glass_card.dart';
import '../components/loading_overlay.dart';
import '../repository/local_repository.dart';
import '../services/exif_service.dart';
import '../theme.dart';
import 'monthly/quote_picker_sheet.dart';
import 'watermark/camera_templates.dart';
import '../components/app_background.dart';

/// 水印模式：边框（杂志·摄影展风）/ 相机水印（EXIF 拍摄参数）
enum WmMode { frame, camera }

/// 边框模板：摄影展 / 杂志 / 极简 / 暗房
enum FrameTpl { exhibition, magazine, minimal, darkroom }

const _frameTplLabels = {
  FrameTpl.exhibition: '摄影展',
  FrameTpl.magazine: '杂志',
  FrameTpl.minimal: '极简',
  FrameTpl.darkroom: '暗房',
};

const _wmColors = <String, Color>{
  '白色': Colors.white,
  '黑色': Colors.black,
  '金色': Color(0xFFD4A853),
  '红色': Color(0xFFE5484D),
  '蓝色': Color(0xFF3B82F6),
};

/// 系统内置字体族，避免额外打包字体
const _wmFontOptions = <String, String?>{
  '默认': null,
  '衬线': 'serif',
  '细体': 'sans-serif-light',
  '粗黑': 'sans-serif-black',
  '等宽': 'monospace',
};

const _defaultElements = <CamElement>{
  CamElement.brand,
  CamElement.model,
  CamElement.focal,
  CamElement.aperture,
  CamElement.shutter,
  CamElement.iso,
  CamElement.date,
  CamElement.place,
};

/// 元素快捷预设
const _presetAll = <CamElement>{
  CamElement.brand,
  CamElement.model,
  CamElement.lens,
  CamElement.focal,
  CamElement.aperture,
  CamElement.shutter,
  CamElement.iso,
  CamElement.date,
  CamElement.place,
};

const _presetMinimal = <CamElement>{
  CamElement.model,
  CamElement.focal,
  CamElement.aperture,
  CamElement.shutter,
  CamElement.iso,
};

const _presetTime = <CamElement>{CamElement.date, CamElement.place};

/// 水印工具：
/// - 边框水印：摄影展 / 杂志 / 极简 / 暗房
/// - 相机水印：自动读取 EXIF（机型 / 镜头 / 焦距 / 光圈 / 快门 / ISO / 日期 / 地点），
///   6 种专业模板 + 模板缩略图 + 逐项开关 + 拖动定位
class WatermarkPage extends StatefulWidget {
  /// 测试钩子：预置照片，绕过系统相册选择器
  final List<File>? debugPhotos;

  /// 测试钩子：预置相机模式预览解码图
  final ui.Image? debugPreviewImage;

  /// 测试钩子：预置 EXIF，跳过真实文件解析
  final PhotoExif? debugExif;

  /// 文案库依赖（用于「选文案」）
  final LocalRepository? repository;

  const WatermarkPage({
    super.key,
    this.debugPhotos,
    this.debugPreviewImage,
    this.debugExif,
    this.repository,
  });

  @override
  State<WatermarkPage> createState() => _WatermarkPageState();
}

class _WatermarkPageState extends State<WatermarkPage> {
  final ImagePicker _picker = ImagePicker();

  // ——— 边框模式输入 ———
  final TextEditingController _titleController = TextEditingController(text: '未命名的日常');
  final TextEditingController _noteController = TextEditingController(text: '生活不在别处，就在此刻。');
  final TextEditingController _placeController = TextEditingController(text: 'CHANGSHA');
  final TextEditingController _signController = TextEditingController(text: '© SHIGUANG 2026');

  // ——— 相机模式输入（留空 = 用 EXIF 自动值）———
  final TextEditingController _modelOverride = TextEditingController();
  final TextEditingController _camPlaceOverride = TextEditingController();

  List<File> _photos = [];
  int _previewIndex = 0;
  WmMode _mode = WmMode.frame;

  // 边框参数
  FrameTpl _frameTpl = FrameTpl.exhibition;
  double _matteWidth = 9;
  bool _showTitle = true;
  bool _showPlace = true;
  bool _showNote = true;
  bool _showSign = false;

  // 相机参数
  CamTpl _camTpl = CamTpl.whiteBar;
  CamPos _camPos = CamPos.bottomRight;
  Set<CamElement> _elements = Set<CamElement>.from(_defaultElements);
  double _camFontSize = 12; // 以 360 宽为基准的相对字号
  double _camOpacity = 0.95;
  int _ctrlTab = 0; // 0 模板 / 1 元素 / 2 文字

  /// 拖动微调（相对画面宽高的归一化偏移，预览与导出共用）
  Offset _dragFrac = Offset.zero;

  // 通用
  String _colorName = '白色';
  String _fontKey = '衬线';

  // EXIF
  final Map<String, PhotoExif?> _exif = {};
  final Map<String, DateTime> _fallbackDate = {};
  bool _exifLoading = false;

  bool _exporting = false;
  String? _lastExportedPath;

  ui.Image? _previewImage;
  String? _previewImagePath;
  bool _previewImageOwned = true;

  Timer? _debounce;

  String? get _wmFontFamily => _wmFontOptions[_fontKey];

  File? get _previewFile =>
      _photos.isEmpty ? null : _photos[_previewIndex.clamp(0, _photos.length - 1)];

  @override
  void initState() {
    super.initState();
    _photos = List<File>.from(widget.debugPhotos ?? const []);
    final preset = widget.debugPreviewImage;
    if (preset != null) {
      _previewImage = preset;
      _previewImageOwned = false;
      _previewImagePath = _photos.isEmpty ? null : _photos.first.path;
    } else if (_photos.isNotEmpty) {
      _ensurePreviewImage();
    }
    if (_photos.isNotEmpty) _loadExif();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _noteController.dispose();
    _placeController.dispose();
    _signController.dispose();
    _modelOverride.dispose();
    _camPlaceOverride.dispose();
    if (_previewImageOwned) _previewImage?.dispose();
    super.dispose();
  }

  // ────────────────────────── 选图 / 选文案 / EXIF ──────────────────────────

  Future<void> _pickPhotos() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 95);
      if (files.isEmpty) return;
      setState(() {
        _photos = files.map((f) => File(f.path)).toList();
        _previewIndex = 0;
        _dragFrac = Offset.zero;
      });
      _ensurePreviewImage();
      _loadExif();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  /// 接入月刊同款文案库：选中后填入「说明 / 文案」并自动开启显示
  Future<void> _pickNoteFromLibrary() async {
    final quote = await showQuotePicker(context, repository: widget.repository);
    if (quote == null || !mounted) return;
    setState(() {
      _noteController.text = formatQuoteAsCaption(quote);
      _showNote = true;
    });
  }

  /// 并行读取前 30 张的 EXIF（更多在导出时按需读取）
  Future<void> _loadExif() async {
    final files = _photos.take(30).toList();
    if (files.isEmpty) return;
    if (widget.debugExif != null) {
      for (final f in files) {
        _exif[f.path] = widget.debugExif;
      }
      if (mounted) setState(() {});
      return;
    }
    setState(() => _exifLoading = true);
    await Future.wait(files.map((f) async {
      final e = await ExifService.read(f);
      _exif[f.path] = e;
      if (e?.takenAt == null) {
        try {
          _fallbackDate[f.path] = await f.lastModified();
        } catch (_) {}
      }
    }));
    if (mounted) setState(() => _exifLoading = false);
  }

  Future<void> _ensurePreviewImage() async {
    final file = _previewFile;
    if (file == null) return;
    final path = file.path;
    if (_previewImagePath == path && _previewImage != null) return;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 900);
      final img = (await codec.getNextFrame()).image;
      if (!mounted) {
        img.dispose();
        return;
      }
      final old = _previewImage;
      final ownsOld = _previewImageOwned;
      setState(() {
        _previewImage = img;
        _previewImageOwned = true;
        _previewImagePath = path;
      });
      if (old != null && ownsOld) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } catch (e) {
      debugPrint('[Watermark] 预览解码失败: $e');
    }
  }

  void _selectPreview(int index) {
    if (index == _previewIndex) return;
    setState(() {
      _previewIndex = index;
      _dragFrac = Offset.zero;
    });
    _ensurePreviewImage();
  }

  PhotoExif? _exifOf(File f) => _exif[f.path];

  DateTime _dateOf(File f) => _exifOf(f)?.takenAt ?? _fallbackDate[f.path] ?? DateTime.now();

  /// 组装该张照片的水印数据（手动覆盖优先于 EXIF）
  CameraMarkData _dataFor(File f) {
    final e = _exifOf(f);
    final modelOverride = _modelOverride.text.trim();
    final placeText = _camPlaceOverride.text.trim();
    final brand = ExifService.brandOf(e?.make, e?.model);
    // 显示品牌标时机型去掉重复前缀（● XIAOMI + 14 Ultra）；关闭品牌标时用完整名避免丢品牌
    final showBrand = _elements.contains(CamElement.brand) && !brand.isEmpty;
    final model = modelOverride.isNotEmpty
        ? modelOverride
        : (showBrand ? (e?.cameraName ?? e?.model) : (e?.model ?? e?.cameraName));
    return CameraMarkData(
      brand: brand,
      model: model,
      lens: e?.lens,
      focal: e?.focal,
      aperture: e?.aperture,
      shutter: e?.shutter,
      iso: e?.iso,
      takenAt: _dateOf(f),
      place: placeText.isEmpty ? null : placeText,
      elements: _elements,
    );
  }

  // ────────────────────────── 数据 ──────────────────────────

  String get _dateText {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  String get _placeText => _showPlace ? _placeController.text.trim().toUpperCase() : '';
  String get _titleText => _showTitle ? _titleController.text.trim() : '';
  String get _noteText => _showNote ? _noteController.text.trim() : '';
  String get _signText => _showSign ? _signController.text.trim() : '';

  bool get _isBarTpl => camBarTemplates.contains(_camTpl);

  /// 底条模板额外占用高度（未缩放基准），系数与 camera_templates 一致
  double _extraForTpl(CamTpl t, double iw, double ih) {
    final fs1 = _camFontSize * iw / 360;
    if (t == CamTpl.film) return math.max(fs1 * 1.5, ih * 0.075) * 2;
    if (camBarTemplates.contains(t)) return math.max(fs1 * 2.75, iw * 0.095);
    return 0;
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() {});
    });
  }

  void _resetAll() {
    setState(() {
      _frameTpl = FrameTpl.exhibition;
      _matteWidth = 9;
      _showTitle = true;
      _showPlace = true;
      _showNote = true;
      _showSign = false;
      _titleController.text = '未命名的日常';
      _noteController.text = '生活不在别处，就在此刻。';
      _placeController.text = 'CHANGSHA';
      _signController.text = '© SHIGUANG 2026';
      _camTpl = CamTpl.whiteBar;
      _camPos = CamPos.bottomRight;
      _elements = Set<CamElement>.from(_defaultElements);
      _camFontSize = 12;
      _camOpacity = 0.95;
      _colorName = '白色';
      _fontKey = '衬线';
      _dragFrac = Offset.zero;
      _ctrlTab = 0;
      _modelOverride.clear();
      _camPlaceOverride.clear();
    });
  }

  Future<void> _confirmClear() async {
    final ok = await AppDialog.confirm(
      context,
      title: '清空照片',
      message: '将移除已选的 ${_photos.length} 张照片（不会删除原图）。',
      danger: true,
      confirmLabel: '清空',
    );
    if (ok == true && mounted) {
      setState(() {
        _photos = [];
        _previewIndex = 0;
        _dragFrac = Offset.zero;
        if (_previewImageOwned) _previewImage?.dispose();
        _previewImage = null;
        _previewImagePath = null;
      });
    }
  }

  // ────────────────────────── 边框绘制 ──────────────────────────

  TextPainter _line(String text,
      double fontSize,
      {bool bold = false,
      required Color color,
      double letterSpacing = 1,
      double? maxWidth,
      String? family}) {
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: family ?? _wmFontFamily,
            fontWeight: bold ? AppFontWeights.semibold : AppFontWeights.normal,
            color: color,
            letterSpacing: letterSpacing,
            height: 1.25,
          )),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
  }

  Size _paintFrame(Canvas canvas, ui.Image image) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    switch (_frameTpl) {
      case FrameTpl.exhibition:
        return _paintExhibition(canvas, image, w, h);
      case FrameTpl.magazine:
        return _paintMagazine(canvas, image, w, h);
      case FrameTpl.minimal:
        return _paintMinimal(canvas, image, w, h);
      case FrameTpl.darkroom:
        return _paintDarkroom(canvas, image, w, h);
    }
  }

  Size _paintExhibition(Canvas canvas, ui.Image image, double w, double h) {
    const paper = Color(0xFFF7F4EE);
    const ink = Color(0xFF232323);
    final t = w * _matteWidth / 100;
    final band = w * 0.22;
    final outW = w + t * 2;
    final outH = h + t + band;
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), Paint()..color = paper);
    canvas.drawImage(image, Offset(t, t), Paint());

    final padX = t + w * 0.035;
    final maxW = outW - padX * 2;
    double y = h + t + band * 0.16;

    if (_titleText.isNotEmpty) {
      final tp = _line(_titleText, w * 0.046,
          bold: true, color: ink, letterSpacing: 2, maxWidth: maxW, family: 'serif');
      tp.paint(canvas, Offset(padX, y));
      y += tp.height + band * 0.10;
      tp.dispose();
    }
    canvas.drawRect(Rect.fromLTWH(padX, y, w * 0.14, math.max(1.0, w * 0.0022)),
        Paint()..color = ink.withOpacity(0.55));
    y += band * 0.12;
    final meta = [if (_placeText.isNotEmpty) _placeText, _dateText].join('   /   ');
    final metaTp = _line(meta, w * 0.021, color: ink.withOpacity(0.6), letterSpacing: 3, maxWidth: maxW);
    metaTp.paint(canvas, Offset(padX, y));
    y += metaTp.height + band * 0.08;
    metaTp.dispose();
    if (_noteText.isNotEmpty) {
      final tp = _line(_noteText, w * 0.023,
          color: ink.withOpacity(0.45), letterSpacing: 1.5, maxWidth: maxW);
      tp.paint(canvas, Offset(padX, y));
      tp.dispose();
    }
    if (_signText.isNotEmpty) {
      final tp =
          _line(_signText, w * 0.019, color: ink.withOpacity(0.4), letterSpacing: 2, maxWidth: maxW);
      tp.paint(canvas,
          Offset(outW - t - w * 0.035 - tp.width, h + t + band - tp.height - band * 0.16));
      tp.dispose();
    }
    return Size(outW, outH);
  }

  Size _paintMagazine(Canvas canvas, ui.Image image, double w, double h) {
    const ink = Color(0xFF1A1A1A);
    final t = w * math.max(3.0, _matteWidth * 0.6) / 100;
    final band = w * 0.26;
    final outW = w + t * 2;
    final outH = h + t + band;
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), Paint()..color = Colors.white);
    canvas.drawImage(image, Offset(t, t), Paint());

    final padX = t + w * 0.04;
    final maxW = outW - padX * 2;
    double y = h + t + band * 0.14;
    if (_titleText.isNotEmpty) {
      final tp = _line(_titleText, w * 0.062,
          bold: true, color: ink, letterSpacing: 0, maxWidth: maxW, family: 'serif');
      tp.paint(canvas, Offset(padX, y));
      y += tp.height + band * 0.09;
      tp.dispose();
    }
    canvas.drawRect(Rect.fromLTWH(padX, y, outW - padX * 2, math.max(1.0, w * 0.0018)),
        Paint()..color = ink.withOpacity(0.85));
    y += band * 0.11;
    if (_noteText.isNotEmpty) {
      final tp = _line(_noteText, w * 0.025,
          color: ink.withOpacity(0.55), letterSpacing: 0.5, maxWidth: maxW * 0.62);
      tp.paint(canvas, Offset(padX, y));
      tp.dispose();
    }
    final meta = [if (_placeText.isNotEmpty) _placeText, _dateText].join('\n');
    final metaTp =
        _line(meta, w * 0.019, color: ink.withOpacity(0.45), letterSpacing: 2, maxWidth: maxW * 0.33);
    metaTp.paint(canvas, Offset(outW - padX - metaTp.width, y));
    metaTp.dispose();
    return Size(outW, outH);
  }

  Size _paintMinimal(Canvas canvas, ui.Image image, double w, double h) {
    final t = w * math.min(_matteWidth, 4) / 100;
    final band = w * 0.075;
    final outW = w + t * 2;
    final outH = h + t + band;
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), Paint()..color = const Color(0xFFFAFAFA));
    canvas.drawImage(image, Offset(t, t), Paint());

    final parts = [if (_placeText.isNotEmpty) _placeText, _dateText];
    final tp = _line(parts.join('  ·  '), w * 0.021,
        color: const Color(0xFF3C3C3C).withOpacity(0.6), letterSpacing: 3, maxWidth: outW - t * 2);
    tp.paint(canvas, Offset(outW - t - w * 0.02 - tp.width, h + t + (band - tp.height) / 2));
    tp.dispose();
    return Size(outW, outH);
  }

  Size _paintDarkroom(Canvas canvas, ui.Image image, double w, double h) {
    const paper = Color(0xFF0C0C0D);
    const ink = Color(0xFFB9B3A8);
    final t = w * (_matteWidth * 1.1) / 100;
    final band = w * 0.18;
    final outW = w + t * 2;
    final outH = h + t + band;
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), Paint()..color = paper);
    canvas.drawImage(image, Offset(t, t), Paint());

    double y = h + t + band * 0.24;
    final parts = [if (_placeText.isNotEmpty) _placeText, _dateText];
    final tp =
        _line(parts.join('   ·   '), w * 0.023, color: ink, letterSpacing: 4, maxWidth: outW - t * 2);
    tp.paint(canvas, Offset((outW - tp.width) / 2, y));
    y += tp.height + band * 0.10;
    tp.dispose();
    final sub = _noteText.isNotEmpty ? _noteText : _signText;
    if (sub.isNotEmpty) {
      final stp =
          _line(sub, w * 0.019, color: ink.withOpacity(0.6), letterSpacing: 2, maxWidth: outW - t * 2);
      stp.paint(canvas, Offset((outW - stp.width) / 2, y));
      stp.dispose();
    }
    return Size(outW, outH);
  }

  // ────────────────────────── 导出 ──────────────────────────

  Future<File?> _render(File input) async {
    try {
      final bytes = await input.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      Size outSize;

      if (_mode == WmMode.frame) {
        outSize = _paintFrame(canvas, image);
      } else {
        // 逐张读取自身 EXIF：批量导出时每张参数各自正确
        if (!_exif.containsKey(input.path) && widget.debugExif == null) {
          _exif[input.path] = await ExifService.read(input);
          _fallbackDate[input.path] = await input.lastModified();
        }
        final w = image.width.toDouble();
        final h = image.height.toDouble();
        outSize = paintCameraTemplate(
          canvas,
          image,
          _dataFor(input),
          tpl: _camTpl,
          fs: _camFontSize * w / 360,
          color: _wmColors[_colorName] ?? Colors.white,
          opacity: _camOpacity,
          fontFamily: _wmFontFamily,
          pos: _camPos,
          forPreview: false,
          drag: Offset(_dragFrac.dx * w, _dragFrac.dy * h),
        );
      }

      final picture = recorder.endRecording();
      final out = await picture.toImage(outSize.width.round(), outSize.height.round());
      image.dispose();
      return _write(out, input);
    } catch (e) {
      debugPrint('[Watermark] 渲染失败: $e');
      return null;
    }
  }

  Future<File?> _write(ui.Image image, File input) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}/watermark');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(
          '${dir.path}/wm_${DateTime.now().millisecondsSinceEpoch}_${input.uri.pathSegments.last}');
      await file.writeAsBytes(data.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('[Watermark] 写文件失败: $e');
      return null;
    }
  }

  Future<void> _exportAll() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择照片'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _exporting = true);
    var saved = 0;
    File? first;
    try {
      for (final photo in _photos) {
        final out = await _render(photo);
        if (out == null) continue;
        first ??= out;
        try {
          await PhotoManager.editor.saveImageWithPath(out.path,
              title: 'watermark_${DateTime.now().millisecondsSinceEpoch}.png');
          saved++;
        } catch (e) {
          debugPrint('[Watermark] 保存到相册失败: $e');
        }
      }
      _lastExportedPath = first?.path;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saved > 0 ? '已导出 $saved 张，保存在系统相册' : '导出失败，请重试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareLast() async {
    final path = _lastExportedPath;
    if (path == null || !await File(path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先导出一次'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    await Share.shareXFiles([XFile(path)], text: '拾光 · 水印');
  }

  // ────────────────────────── 预览 ──────────────────────────

  Widget _emptyPicker() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: GlassColors.bg(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: GlassColors.borderSubtle(context), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: context.textTertiary),
            12.hGap,
            Text('点击选择照片',
                style: TextStyle(fontSize: AppFontSizes.base, color: context.textSecondary)),
            6.hGap,
            Text('支持多选 · 自动读取 EXIF 拍摄参数',
                style: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary)),
          ],
        ),
      ),
    );
  }

  /// 输出成图尺寸（图片像素单位），与各绘制函数严格一致
  Size _outSizeFor(double iw, double ih) {
    if (_mode == WmMode.frame) {
      switch (_frameTpl) {
        case FrameTpl.exhibition:
          final t = iw * _matteWidth / 100;
          return Size(iw + t * 2, ih + t + iw * 0.22);
        case FrameTpl.magazine:
          final t = iw * math.max(3.0, _matteWidth * 0.6) / 100;
          return Size(iw + t * 2, ih + t + iw * 0.26);
        case FrameTpl.minimal:
          final t = iw * math.min(_matteWidth, 4) / 100;
          return Size(iw + t * 2, ih + t + iw * 0.075);
        case FrameTpl.darkroom:
          final t = iw * (_matteWidth * 1.1) / 100;
          return Size(iw + t * 2, ih + t + iw * 0.18);
      }
    }
    return Size(iw, ih + _extraForTpl(_camTpl, iw, ih));
  }

  Widget _previewArea() {
    final file = _previewFile;
    if (file == null) return _emptyPicker();
    final img = _previewImage;
    if (img == null) {
      // 解码中：先显示原图
      return Center(child: Image.file(file, fit: BoxFit.contain));
    }
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final out = _outSizeFor(iw, ih);

    return LayoutBuilder(builder: (context, cons) {
      final s = math.min(cons.maxWidth / out.width, cons.maxHeight / out.height);

      Widget paint = CustomPaint(
        key: const Key('wmPreview'),
        painter: _Painter((canvas, size) {
          // 直接按成图坐标绘制并整体缩放：预览与导出像素级一致，永不裁切
          canvas.scale(s);
          if (_mode == WmMode.frame) {
            _paintFrame(canvas, img);
          } else {
            paintCameraTemplate(
              canvas,
              img,
              _dataFor(file),
              tpl: _camTpl,
              fs: _camFontSize * iw / 360,
              color: _wmColors[_colorName] ?? Colors.white,
              opacity: _camOpacity,
              fontFamily: _wmFontFamily,
              pos: _camPos,
              forPreview: true,
              drag: Offset(_dragFrac.dx * iw, _dragFrac.dy * ih),
            );
          }
        }),
        size: Size.infinite,
      );

      // 浮层模板：拖动微调位置，双击复位
      if (_mode == WmMode.camera && !_isBarTpl) {
        final unit = iw * s;
        paint = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() {
            final next = _dragFrac + Offset(d.delta.dx / unit, d.delta.dy / unit);
            _dragFrac = Offset(next.dx.clamp(-0.45, 0.45), next.dy.clamp(-0.45, 0.45));
          }),
          onDoubleTap: () => setState(() => _dragFrac = Offset.zero),
          child: paint,
        );
      }

      return Center(
        child: SizedBox(
          width: out.width * s,
          height: out.height * s,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Stack(children: [
              Positioned.fill(child: paint),
              if (_photos.length > 1) _countBadge(),
            ]),
          ),
        ),
      );
    });
  }

  /// 多图时右上角显示当前序号
  Widget _countBadge() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Text(
          '${_previewIndex.clamp(0, _photos.length - 1) + 1} / ${_photos.length}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.medium,
            color: Colors.white,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  /// 多图时在预览下方切换
  Widget _photoStrip() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacings.xl, vertical: 8),
        itemCount: _photos.length,
        separatorBuilder: (_, __) => 8.wGap,
        itemBuilder: (context, i) {
          final selected = i == _previewIndex;
          return GestureDetector(
            onTap: () => _selectPreview(i),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: selected ? context.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(_photos[i], fit: BoxFit.cover, cacheWidth: 120),
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────── 基础控件 ──────────────────────────

  Widget _sectionTitle(String label) => Text(label,
      style: TextStyle(
          fontSize: AppFontSizes.sm,
          fontWeight: AppFontWeights.semibold,
          color: context.textPrimary));

  Widget _hint(String text) => Text(text,
      style: TextStyle(fontSize: AppFontSizes.xs, height: 1.45, color: context.textTertiary));

  Widget _chip(String label, bool selected, VoidCallback onTap, {String? fontFamily}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? context.accent : context.surface,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: selected ? context.accent : GlassColors.borderSubtle(context),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: AppFontSizes.xs,
              fontFamily: fontFamily,
              color: selected ? Colors.white : context.textSecondary,
            )),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, {Widget? trailing}) {
    final input = TextField(
      controller: c,
      onChanged: (_) => _onTextChanged(),
      style: TextStyle(fontSize: AppFontSizes.sm, color: context.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
        hintText: hint,
        hintStyle: TextStyle(fontSize: AppFontSizes.xs, color: context.textTertiary),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
    );
    if (trailing == null) return input;
    return Row(children: [Expanded(child: input), 8.wGap, trailing]);
  }

  Widget _slider(
      String label, String value, double v, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: AppFontSizes.sm, color: context.textSecondary)),
            Text(value, style: TextStyle(fontSize: AppFontSizes.xs, color: context.accent)),
          ],
        ),
        Slider(
          value: v.clamp(min, max),
          min: min,
          max: max,
          activeColor: context.accent,
          inactiveColor: context.divider,
          onChanged: (nv) => setState(() => onChanged(nv)),
        ),
      ],
    );
  }

  Widget _fontSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('字体'),
        8.hGap,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _wmFontOptions.keys
              .map((k) => _chip(k, _fontKey == k, () => setState(() => _fontKey = k),
                  fontFamily: _wmFontOptions[k]))
              .toList(),
        ),
      ],
    );
  }

  Widget _colorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('颜色'),
        8.hGap,
        Row(
          children: _wmColors.entries.map((e) {
            final selected = _colorName == e.key;
            return GestureDetector(
              onTap: () => setState(() => _colorName = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: selected ? context.accent : Colors.transparent, width: 2),
                ),
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: e.value)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => setState(() => onChanged(!value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value ? context.accent.withOpacity(AppOpacities.accentBg) : context.surface,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: value ? context.accent : GlassColors.borderSubtle(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 12, color: value ? context.accent : context.textTertiary),
            4.wGap,
            Text(label,
                style: TextStyle(
                    fontSize: AppFontSizes.xs,
                    color: value ? context.accent : context.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, WmMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.accent : context.surface,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  fontWeight: AppFontWeights.medium,
                  color: selected ? Colors.white : context.textSecondary)),
        ),
      ),
    );
  }

  /// 三段分段控件
  Widget _segmented() {
    const labels = ['模板', '元素', '文字'];
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        // 半透明内嵌面：玻璃卡内再分层，不能用不透明灰把卡片打穿
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: context.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _ctrlTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _ctrlTab = i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? context.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontSize: AppFontSizes.sm,
                        fontWeight:
                            selected ? AppFontWeights.medium : AppFontWeights.normal,
                        color: selected ? Colors.white : context.textSecondary)),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ────────────────────────── 控制面板 ──────────────────────────

  Widget _buildControls() {
    return GlassCard(
      borderRadius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacings.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _modeChip('边框 · 杂志风', WmMode.frame)),
            8.wGap,
            Expanded(child: _modeChip('相机水印', WmMode.camera)),
          ]),
          16.hGap,
          if (_mode == WmMode.frame)
            ..._frameControls()
          else ...[
            _segmented(),
            16.hGap,
            ..._cameraPanel(),
          ],
        ],
      ),
    );
  }

  List<Widget> _frameControls() {
    return [
      _sectionTitle('模板'),
      8.hGap,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: FrameTpl.values
            .map((tpl) =>
                _chip(_frameTplLabels[tpl]!, _frameTpl == tpl, () => setState(() => _frameTpl = tpl)))
            .toList(),
      ),
      16.hGap,
      _slider('衬纸留白', '${_matteWidth.round()}%', _matteWidth, 3, 16, (v) => _matteWidth = v),
      4.hGap,
      _fontSelector(),
      16.hGap,
      _sectionTitle('版面文字'),
      8.hGap,
      _field(_titleController, '标题', '未命名的日常'),
      8.hGap,
      _field(_placeController, '地点（英文更出片）', 'CHANGSHA'),
      8.hGap,
      _field(_noteController, '说明 / 文案', '生活不在别处，就在此刻。',
          trailing: AppButton.secondary(
            label: '选文案',
            icon: Icons.format_quote,
            size: AppButtonSize.md,
            expand: false,
            onPressed: _pickNoteFromLibrary,
          )),
      8.hGap,
      _field(_signController, '签名', '© SHIGUANG 2026'),
      12.hGap,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _toggle('标题', _showTitle, (v) => _showTitle = v),
          _toggle('地点', _showPlace, (v) => _showPlace = v),
          _toggle('说明', _showNote, (v) => _showNote = v),
          _toggle('签名', _showSign, (v) => _showSign = v),
        ],
      ),
    ];
  }

  List<Widget> _cameraPanel() {
    switch (_ctrlTab) {
      case 1:
        return _elementPanel();
      case 2:
        return _textPanel();
      default:
        return _templatePanel();
    }
  }

  /// ① 模板页：EXIF 状态 + 缩略图
  List<Widget> _templatePanel() {
    return [
      _exifStatus(),
      16.hGap,
      _sectionTitle('模板'),
      8.hGap,
      _tplThumbs(),
      10.hGap,
      _hint(_isBarTpl
          ? '底条模板会自动扩展画面高度，文字配色固定（白条黑字 / 黑条白字），位置贴边不可调。'
          : '浮层模板可在预览上拖动微调位置，双击预览复位。'),
    ];
  }

  /// ② 元素页：快捷预设 + 逐项开关
  List<Widget> _elementPanel() {
    return [
      _sectionTitle('快捷预设'),
      8.hGap,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _chip('全参数', _sameSet(_elements, _presetAll),
              () => setState(() => _elements = Set<CamElement>.from(_presetAll))),
          _chip('极简', _sameSet(_elements, _presetMinimal),
              () => setState(() => _elements = Set<CamElement>.from(_presetMinimal))),
          _chip('时间地点', _sameSet(_elements, _presetTime),
              () => setState(() => _elements = Set<CamElement>.from(_presetTime))),
          _chip('全关', _elements.isEmpty, () => setState(() => _elements = <CamElement>{})),
        ],
      ),
      16.hGap,
      _sectionTitle('显示项'),
      6.hGap,
      _hint('逐项开关，水印会按选中的内容重新排版。'),
      8.hGap,
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: CamElement.values.map((el) {
          final on = _elements.contains(el);
          return _toggle(camElementLabels[el]!, on, (v) {
            if (v) {
              _elements.add(el);
            } else {
              _elements.remove(el);
            }
          });
        }).toList(),
      ),
    ];
  }

  /// ③ 文字页：机型/地点（可恢复自动）+ 字号 + 字体 + 颜色 + 透明度 + 位置
  List<Widget> _textPanel() {
    final file = _previewFile;
    final autoModel = file == null ? null : _exifOf(file)?.cameraName;
    final hasOverride = _modelOverride.text.trim().isNotEmpty;
    return [
      _sectionTitle('文字内容'),
      8.hGap,
      _field(_modelOverride, '机型（留空=自动读取）', autoModel ?? '例如 Xiaomi 14 Ultra',
          trailing: hasOverride
              ? AppButton.secondary(
                  label: '自动',
                  icon: Icons.restart_alt,
                  size: AppButtonSize.md,
                  expand: false,
                  onPressed: () => setState(_modelOverride.clear),
                )
              : null),
      8.hGap,
      _field(_camPlaceOverride, '地点（留空=不显示）', 'CHANGSHA'),
      16.hGap,
      _slider('字号', '占画面宽 ${(_camFontSize / 3.6).toStringAsFixed(1)}%', _camFontSize, 8, 30,
          (v) => _camFontSize = v),
      4.hGap,
      _fontSelector(),
      if (_isBarTpl) ...[
        16.hGap,
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 14, color: context.textTertiary),
            6.wGap,
            Expanded(
                child: _hint('当前是底条模板：颜色 / 透明度 / 位置由模板固定。切到「EXIF 卡片 / 竖排 / 极简一行」可自由调整。')),
          ]),
        ),
      ] else ...[
        16.hGap,
        _slider('透明度', '${(_camOpacity * 100).round()}%', _camOpacity, 0.2, 1.0,
            (v) => _camOpacity = v),
        4.hGap,
        _sectionTitle('位置'),
        8.hGap,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: CamPos.values
              .map((p) =>
                  _chip(camPosLabels[p]!, _camPos == p, () => setState(() => _camPos = p)))
              .toList(),
        ),
        6.hGap,
        _hint('也可直接在预览上拖动微调，双击预览复位。'),
        16.hGap,
        _colorSelector(),
      ],
    ];
  }

  /// 模板缩略图（用当前照片实时渲染）
  Widget _tplThumbs() {
    final img = _previewImage;
    final file = _previewFile;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CamTpl.values.length,
        separatorBuilder: (_, __) => 8.wGap,
        itemBuilder: (context, i) {
          final t = CamTpl.values[i];
          final selected = _camTpl == t;
          return GestureDetector(
            onTap: () => setState(() {
              _camTpl = t;
              _dragFrac = Offset.zero;
              if (t == CamTpl.whiteBar) _colorName = '黑色';
              if (t == CamTpl.blackBar || t == CamTpl.film) _colorName = '白色';
            }),
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: selected ? context.accent : GlassColors.borderSubtle(context),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: (img == null || file == null)
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          painter: _Painter((canvas, size) {
                            final iw = img.width.toDouble();
                            final ih = img.height.toDouble();
                            final extra = _extraForTpl(t, iw, ih);
                            final s = math.min(size.width / iw, size.height / (ih + extra));
                            final dw = iw * s;
                            final dh = ih * s;
                            canvas.translate(
                                (size.width - dw) / 2, (size.height - dh - extra * s) / 2);
                            paintCameraTemplate(
                              canvas,
                              img,
                              _dataFor(file),
                              tpl: t,
                              fs: _camFontSize * dw / 360,
                              color: _wmColors[_colorName] ?? Colors.white,
                              opacity: _camOpacity,
                              fontFamily: _wmFontFamily,
                              pos: _camPos,
                              forPreview: true,
                              dest: Rect.fromLTWH(0, 0, dw, dh),
                            );
                          }),
                          size: Size.infinite,
                        ),
                ),
                5.hGap,
                Text(camTplLabels[t]!,
                    style: TextStyle(
                        fontSize: AppFontSizes.xs,
                        color: selected ? context.accent : context.textSecondary,
                        fontWeight: selected ? AppFontWeights.medium : AppFontWeights.normal)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// EXIF 识别状态条
  Widget _exifStatus() {
    final file = _previewFile;
    final e = file == null ? null : _exifOf(file);
    final ok = !_exifLoading && e != null;
    final main = _exifLoading
        ? '正在读取照片 EXIF…'
        : e == null
            ? '这张照片没有 EXIF，机型与参数可在「文字」页手动填写'
            : '已识别 EXIF · ${e.summary}';
    final sub = _photos.length > 1 ? '其余 ${_photos.length - 1} 张将按各自 EXIF 生成，无需重复设置' : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? context.accent.withOpacity(AppOpacities.accentBg) : context.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.verified_outlined : Icons.info_outline,
              size: 15, color: ok ? context.accent : context.textTertiary),
          8.wGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(main,
                    style: TextStyle(
                        fontSize: AppFontSizes.xs,
                        height: 1.4,
                        color: ok ? context.accent : context.textSecondary)),
                if (sub != null) ...[
                  3.hGap,
                  Text(sub,
                      style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          height: 1.4,
                          color:
                              ok ? context.accent.withOpacity(0.75) : context.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameSet(Set<CamElement> a, Set<CamElement> b) => a.length == b.length && a.containsAll(b);

  // ────────────────────────── 吸底操作栏 ──────────────────────────

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: GlassColors.bg(context),
        border: Border(top: BorderSide(color: context.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacings.xl, 10, AppSpacings.xl, 10),
          child: Row(children: [
            Expanded(
              child: AppButton.primary(
                label: _photos.isEmpty ? '选择照片' : '导出 ${_photos.length} 张（存相册）',
                icon:
                    _photos.isEmpty ? Icons.add_photo_alternate_outlined : Icons.download_outlined,
                onPressed: _photos.isEmpty ? _pickPhotos : _exportAll,
              ),
            ),
            10.wGap,
            AppButton.circle(
              icon: Icons.ios_share,
              size: AppButtonSize.md,
              onPressed: _shareLast,
            ),
          ]),
        ),
      ),
    );
  }

  // ────────────────────────── 页面 ──────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: context.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text('水印',
                style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: AppFontWeights.medium,
                    color: context.textPrimary)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.restart_alt, size: 20, color: context.textSecondary),
                onPressed: _resetAll,
                tooltip: '重置参数',
              ),
              IconButton(
                icon: Icon(Icons.ios_share, size: 20, color: context.textSecondary),
                onPressed: _shareLast,
                tooltip: '分享已导出',
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacings.xl, AppSpacings.sm, AppSpacings.xl, 0),
                    child: _previewArea(),
                  ),
                ),
                if (_photos.length > 1) _photoStrip(),
                if (_photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacings.xl, 8, AppSpacings.xl, 0),
                    child: Row(children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: '重新选择',
                          size: AppButtonSize.md,
                          onPressed: _pickPhotos,
                        ),
                      ),
                      10.wGap,
                      Expanded(
                        child: AppButton.secondary(
                          label: '清空',
                          size: AppButtonSize.md,
                          onPressed: _confirmClear,
                        ),
                      ),
                    ]),
                  ),
                Expanded(
                  flex: 11,
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(AppSpacings.xl, 12, AppSpacings.xl, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_photos.isNotEmpty) _buildControls(),
                        if (_photos.isNotEmpty) 12.hGap,
                        if (_photos.isNotEmpty) _hint('导出为 PNG 存到系统相册，原图不受影响。'),
                      ],
                    ),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
          if (_exporting) const LoadingOverlay(message: '正在生成水印图…'),
        ],
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final void Function(Canvas canvas, Size size) paintFn;
  _Painter(this.paintFn);

  @override
  void paint(Canvas canvas, Size size) => paintFn(canvas, size);

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) => true;
}
