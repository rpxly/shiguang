import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../models/photo.dart';
import '../repository/local_repository.dart';
import '../components/app_background.dart';

class FilmIndexPage extends StatefulWidget {
  final LocalRepository repository;
  const FilmIndexPage({super.key, required this.repository});

  @override
  State<FilmIndexPage> createState() => _FilmIndexPageState();
}

class _FilmIndexPageState extends State<FilmIndexPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _webReady = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final tempDir = await getTemporaryDirectory();
    final webDir = Directory('${tempDir.path}/film-index');

    if (await webDir.exists()) {
      await webDir.delete(recursive: true);
    }
    await webDir.create(recursive: true);
    for (final file in [
      'index.html',
      'app.js',
      'styles.css',
      'film-frame.js',
      'film-frame-135.js',
      'flutter-bridge.js',
    ]) {
      final data = await rootBundle.load('assets/film-index/$file');
      await File('${webDir.path}/$file').writeAsBytes(data.buffer.asUint8List());
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterSaveFile',
        onMessageReceived: (message) => _saveFile(message.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() {
            _isLoading = false;
            _webReady = true;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            _controller.runJavaScript(
              "var z=document.getElementById('zoomFit');if(z)z.click();",
            );
          });
        },
      ))
      ..loadFile('${webDir.path}/index.html');

    // Android：让页面内「选择或拖入扫描件」的文件框可用（弹系统相册选择器）
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((params) async {
        try {
          final List<XFile> images = await _picker.pickMultiImage(imageQuality: 95);
          return images.map((x) => x.path).toList();
        } catch (_) {
          return <String>[];
        }
      });
    }
  }

  Future<void> _saveFile(String jsonMessage) async {
    try {
      final data = jsonDecode(jsonMessage) as Map<String, dynamic>;
      final dataUrl = data['data'] as String;
      final filename = data['filename'] as String;

      final bytes = base64Decode(dataUrl.split(',').last);
      await PhotoManager.editor.saveImage(bytes, filename: filename);

      // 回流拾光：写入应用导出目录并登记为照片记录，让索引图出现在首页时间线
      String? savedPath;
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final exportDir = Directory('${docsDir.path}/exports');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        final now = DateTime.now();
        final stamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        final stem = filename.contains('.')
            ? filename.substring(0, filename.lastIndexOf('.'))
            : (filename.isEmpty ? 'film-index' : filename);
        final ext = filename.contains('.')
            ? filename.substring(filename.lastIndexOf('.'))
            : '.png';
        var file = File('${exportDir.path}/${stem}_$stamp$ext');
        var n = 1;
        while (await file.exists()) {
          file = File('${exportDir.path}/${stem}_$stamp-$n$ext');
          n++;
        }
        await file.writeAsBytes(bytes);
        widget.repository.savePhoto(Photo(
          id: 'film-index-${now.millisecondsSinceEpoch}',
          path: file.path,
          thumbnailPath: file.path,
          date: now,
          category: '索引图',
          fileSize: bytes.length,
        ));
        savedPath = file.path;
      } catch (e) {
        debugPrint('filmIndex: 回流拾光失败: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null ? '已保存到相册，并加入拾光时间线' : '已保存到相册',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Future<void> _pickPhotos() async {
    if (!_webReady) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 95,
      );
      if (images.isEmpty) return;

      final List<String> jsEntries = [];
      for (final image in images) {
        try {
          final bytes = await image.readAsBytes();
          final b64 = base64Encode(bytes);
          final name = image.name;
          final ext = name.split('.').last.toLowerCase();
          final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
          jsEntries.add("{data: 'data:$mime;base64,$b64', name: '$name'}");
        } catch (e) {
          debugPrint('filmIndex: failed to read image: $e');
        }
      }

      if (jsEntries.isEmpty) return;
      await _controller.runJavaScript('window.addImagesFromFlutter([${jsEntries.join(",")}])');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              WebViewWidget(controller: _controller),
          ],
        ),
      ),
      floatingActionButton: _webReady
          ? FloatingActionButton.extended(
              onPressed: _pickPhotos,
              backgroundColor: const Color(0xFF164f3c),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('从相册选择'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
