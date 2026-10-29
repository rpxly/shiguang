import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../components/nav_header.dart';
import '../components/app_background.dart';

class WebsitePage extends StatefulWidget {
  final VoidCallback onBack;

  const WebsitePage({super.key, required this.onBack});

  @override
  State<WebsitePage> createState() => _WebsitePageState();
}

class _WebsitePageState extends State<WebsitePage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  static const String _url = 'https://rpxly.github.io/shiguang/';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            NavHeader(title: '官方网站', onBack: widget.onBack),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (_hasError)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_outlined, size: 40),
                          const SizedBox(height: 12),
                          const Text('加载失败，请检查网络连接'),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _hasError = false;
                              });
                              _controller.loadRequest(Uri.parse(_url));
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
