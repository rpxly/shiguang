import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang/pages/watermark_page.dart';
import 'package:shiguang/services/exif_service.dart';

/// 生成一张 40x60 的纯色测试图片文件
Future<File> _createTestImage(Directory dir, String name) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 60), ui.Paint()..color = const Color(0xFF336699));
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 60);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${dir.path}/$name')..writeAsBytesSync(byteData!.buffer.asUint8List());
  image.dispose();
  return file;
}

/// 生成预览用的解码图（供相机水印预览走 CustomPaint 绘制路径）
Future<ui.Image> _createPreviewImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 60), ui.Paint()..color = const Color(0xFF336699));
  return recorder.endRecording().toImage(40, 60);
}

/// 模拟一张有完整 EXIF 的小米徕卡照片
const _sampleExif = PhotoExif(
  make: 'Xiaomi',
  model: 'Xiaomi 14 Ultra',
  lens: 'Leica Summilux 23mm f/1.63',
  focal: '24mm',
  aperture: 'f/1.63',
  shutter: '1/120s',
  iso: '200',
);

void main() {
  late Directory tempDir;
  late File testImage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wm_test');
    testImage = await _createTestImage(tempDir, 'test_photo.png');
  });

  tearDownAll(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 上仍被 Flutter 图片缓存占用，忽略即可
    }
  });

  /// 先滚动到可见再点击，避免控件在 800x600 视口外导致 tap 落空
  Future<void> tapLabel(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pumpFramePage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: WatermarkPage(debugPhotos: [testImage])));
    await tester.pumpAndSettle();
  }

  /// 相机模式：预置解码图与 EXIF，确保绘制路径真实执行
  Future<void> pumpCameraPage(WidgetTester tester) async {
    final preview = await _createPreviewImage();
    await tester.pumpWidget(MaterialApp(
      home: WatermarkPage(
        debugPhotos: [testImage],
        debugPreviewImage: preview,
        debugExif: _sampleExif,
      ),
    ));
    await tester.pumpAndSettle();
    await tapLabel(tester, find.text('相机水印'));
    expect(find.byType(Image), findsNothing, reason: '相机模式预览应走 Canvas 而非 Image');
  }

  // ────────────────────────── 边框模式 ──────────────────────────

  testWidgets('默认进入边框模式，预览与文案入口正常', (tester) async {
    await pumpFramePage(tester);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('版面文字'), findsOneWidget);
    expect(find.text('选文案'), findsOneWidget);
    expect(find.text('相机水印'), findsOneWidget);
    expect(find.text('文字水印'), findsNothing);
  });

  testWidgets('4 个边框模板均正常渲染', (tester) async {
    await pumpFramePage(tester);
    for (final tpl in ['杂志', '极简', '暗房', '摄影展']) {
      await tapLabel(tester, find.text(tpl));
      expect(find.byType(Image), findsOneWidget, reason: '模板 $tpl 渲染失败');
      expect(tester.takeException(), isNull, reason: '模板 $tpl 抛异常');
    }
  });

  testWidgets('5 种字体均正常渲染', (tester) async {
    await pumpFramePage(tester);
    for (final font in ['默认', '细体', '粗黑', '等宽', '衬线']) {
      await tapLabel(tester, find.text(font));
      expect(find.byType(Image), findsOneWidget, reason: '字体 $font 渲染失败');
    }
  });

  testWidgets('关闭/开启版面文字各显示行不崩溃', (tester) async {
    await pumpFramePage(tester);
    for (final label in ['标题', '地点', '说明', '签名']) {
      await tapLabel(tester, find.text(label).last);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  // ────────────────────────── 相机水印：结构与模板 ──────────────────────────

  testWidgets('相机模式：EXIF 自动识别 + 三段分段控件', (tester) async {
    await pumpCameraPage(tester);
    expect(find.textContaining('已识别 EXIF'), findsOneWidget);
    expect(find.textContaining('Xiaomi 14 Ultra'), findsWidgets);
    expect(find.textContaining('f/1.63'), findsWidgets);
    expect(find.text('元素'), findsOneWidget);
    expect(find.text('文字'), findsOneWidget);
  });

  testWidgets('6 个模板缩略图均可切换并绘制', (tester) async {
    await pumpCameraPage(tester);
    for (final tpl in ['暗夜黑条', 'EXIF 卡片', '竖排', '极简一行', '胶片边', '经典白条']) {
      await tapLabel(tester, find.text(tpl));
      expect(tester.takeException(), isNull, reason: '模板 $tpl 绘制抛异常');
      expect(find.byKey(const Key('wmPreview')), findsOneWidget);
    }
  });

  // ────────────────────────── 相机水印：元素页 ──────────────────────────

  testWidgets('元素页：快捷预设与 9 项开关均可用', (tester) async {
    await pumpCameraPage(tester);
    await tapLabel(tester, find.text('元素'));
    expect(find.text('快捷预设'), findsOneWidget);

    for (final preset in ['极简', '时间地点', '全关', '全参数']) {
      await tapLabel(tester, find.text(preset));
      expect(tester.takeException(), isNull, reason: '预设 $preset 抛异常');
    }

    for (final label in ['品牌标', '机型', '镜头', '焦距', '光圈', '快门', 'ISO', '日期', '地点']) {
      await tapLabel(tester, find.text(label));
      expect(tester.takeException(), isNull, reason: '开关 $label 抛异常');
    }
  });

  testWidgets('全部元素关闭后不绘制水印也不崩溃', (tester) async {
    await pumpCameraPage(tester);
    await tapLabel(tester, find.text('元素'));
    await tapLabel(tester, find.text('全关'));
    expect(tester.takeException(), isNull);
  });

  // ────────────────────────── 相机水印：文字页 ──────────────────────────

  testWidgets('文字页：字号/字体可用，底条模板给出固定配色说明', (tester) async {
    await pumpCameraPage(tester);
    await tapLabel(tester, find.text('文字'));
    expect(find.text('文字内容'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    // 默认经典白条 → 不提供位置与颜色，给出说明
    expect(find.text('位置'), findsNothing);
    expect(find.textContaining('底条模板'), findsOneWidget);
    for (final font in ['等宽', '粗黑', '衬线']) {
      await tapLabel(tester, find.text(font));
      expect(tester.takeException(), isNull, reason: '字体 $font 抛异常');
    }
  });

  testWidgets('浮层模板提供位置/颜色/透明度，并可拖动预览', (tester) async {
    await pumpCameraPage(tester);
    await tapLabel(tester, find.text('EXIF 卡片'));
    await tapLabel(tester, find.text('文字'));
    expect(find.text('位置'), findsOneWidget);
    expect(find.text('颜色'), findsOneWidget);
    expect(find.text('透明度'), findsOneWidget);

    for (final pos in ['右下', '左上', '右上', '左下']) {
      await tapLabel(tester, find.text(pos));
      expect(tester.takeException(), isNull, reason: '落点 $pos 抛异常');
    }

    await tester.drag(find.byKey(const Key('wmPreview')), const Offset(24, -18));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '拖动预览抛异常');
  });

  testWidgets('手动填写机型可覆盖 EXIF，并可一键恢复自动', (tester) async {
    await pumpCameraPage(tester);
    await tapLabel(tester, find.text('文字'));
    final field = find.widgetWithText(TextField, '机型（留空=自动读取）');
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Leica Q3');
    await tester.pumpAndSettle();
    await tapLabel(tester, find.text('自动'));
    expect(tester.takeException(), isNull);
  });

  // ────────────────────────── 页面级交互 ──────────────────────────

  testWidgets('吸底操作栏常驻，导出按钮随张数变化', (tester) async {
    await pumpCameraPage(tester);
    expect(find.textContaining('导出 1 张'), findsOneWidget);
  });

  testWidgets('清空需要二次确认', (tester) async {
    await pumpCameraPage(tester);
    await tapLabel(tester, find.text('清空'));
    expect(find.text('清空照片'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wmPreview')), findsOneWidget);
  });

  // ────────────────────────── EXIF 解析 ──────────────────────────

  group('EXIF 品牌识别', () {
    test('小米 / 徕卡 / 索尼 / 苹果 均能识别', () {
      expect(ExifService.brandOf('Xiaomi', 'Xiaomi 14 Ultra').label, 'XIAOMI');
      expect(ExifService.brandOf('LEICA CAMERA AG', 'LEICA Q3').label, 'LEICA');
      expect(ExifService.brandOf('SONY', 'ILCE-7M4').label, 'SONY');
      expect(ExifService.brandOf('Apple', 'iPhone 15 Pro').label, 'Apple');
      expect(ExifService.brandOf('Hasselblad', 'L2D-20c').label, 'HASSELBLAD');
      expect(ExifService.brandOf(null, null).isEmpty, isTrue);
    });

    test('机型名去掉重复厂商前缀', () {
      expect(_sampleExif.cameraName, '14 Ultra');
      const apple = PhotoExif(make: 'Apple', model: 'iPhone 15 Pro');
      expect(apple.cameraName, 'iPhone 15 Pro');
    });

    test('参数行格式符合摄影习惯', () {
      expect(_sampleExif.specLine, '24mm   f/1.63   1/120s   ISO 200');
      expect(_sampleExif.hasSpec, isTrue);
    });
  });
}
