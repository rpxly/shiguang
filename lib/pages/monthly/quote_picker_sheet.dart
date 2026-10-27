import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../components/app_chip.dart';
import '../../components/app_dialog.dart';
import '../../components/bottom_blur_bar.dart';
import '../../components/empty_state.dart';
import '../../components/glass_card.dart';
import '../../models/quote.dart';
import '../../repository/local_repository.dart';
import '../../services/quote_fetcher_service.dart';
import '../../services/quote_service.dart';
import '../../theme.dart';

/// 打开「选文案」面板：展示内置 / 自建 / 联网（hitokoto）文案，
/// 点击一条后 Navigator.pop 返回该 [Quote]；取消返回 null。
Future<Quote?> showQuotePicker(BuildContext context, {LocalRepository? repository}) {
  return showModalBottomSheet<Quote>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: context.overlay,
    isScrollControlled: true,
    builder: (_) => _QuotePickerSheet(repository: repository),
  );
}

/// 将选中的文案格式化为月刊输入框文本：含作者/出处时为「文案 — 作者」
String formatQuoteAsCaption(Quote quote) {
  final author = quote.author ?? quote.source;
  return author != null && author.isNotEmpty ? '${quote.text} — $author' : quote.text;
}

class _QuotePickerSheet extends StatefulWidget {
  final LocalRepository? repository;

  const _QuotePickerSheet({this.repository});

  @override
  State<_QuotePickerSheet> createState() => _QuotePickerSheetState();
}

class _QuotePickerSheetState extends State<_QuotePickerSheet> {
  final QuoteService _quoteService = QuoteService();
  final QuoteFetcherService _fetcher = QuoteFetcherService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = '全部';
  String _searchQuery = '';
  bool _fetchingOnline = false;

  // 缓存：避免 build 中每次 getter 都重新拼接列表
  List<Quote> _cachedAllQuotes = [];
  List<Quote> _cachedFilteredQuotes = [];

  // 分类展示顺序，数据中出现过的其他分类追加在后
  static const _preferredOrder = [
    '全部', '哲思', '生活', '孤独', '旅行', '爱情', '自然', '时间', '网易云', '小红书',
  ];

  List<String> get _categories {
    final present = _cachedAllQuotes.map((q) => q.category).toSet();
    final cats = _preferredOrder.where((c) => c == '全部' || present.contains(c)).toList();
    for (final c in present) {
      if (!cats.contains(c)) cats.add(c);
    }
    return cats;
  }

  void _refreshCache() {
    _cachedAllQuotes = _quoteService.allQuotes;
    Iterable<Quote> result = _cachedAllQuotes;
    if (_selectedCategory != '全部') {
      result = result.where((q) => q.category == _selectedCategory);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) =>
          e.text.toLowerCase().contains(q) ||
          (e.author?.toLowerCase().contains(q) ?? false) ||
          (e.source?.toLowerCase().contains(q) ?? false));
    }
    _cachedFilteredQuotes = result.toList();
  }

  @override
  void initState() {
    super.initState();
    _refreshCache();
    _autoFetchIfNeeded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 开启自动获取且本地还没有联网文案时，自动抓取一次（沿用 1 小时节流）
  void _autoFetchIfNeeded() {
    final repo = widget.repository;
    if (repo == null || !repo.getAutoFetchQuotes()) return;
    final hasOnline = _cachedAllQuotes.any((q) => q.id.startsWith('online_'));
    if (hasOnline) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - repo.getLastQuoteFetchTime() < 3600) return;
    _fetchOnline(silent: true);
  }

  Future<void> _fetchOnline({bool silent = false}) async {
    if (_fetchingOnline) return;
    setState(() => _fetchingOnline = true);
    try {
      final count = await _fetcher.fetchAndSave(_quoteService);
      final repo = widget.repository;
      if (repo != null) {
        repo.setLastQuoteFetchTime(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      }
      if (mounted) {
        _refreshCache();
        setState(() {});
      }
      // 网络失败时 fetchAndSave 返回 0，已有列表不受影响，仅提示
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0 ? '获取了 $count 条新文案' : '未获取到新文案，请检查网络后重试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('联网获取失败，请稍后重试'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingOnline = false);
    }
  }

  /// 新建自建文案（内容必填，作者/出处与分类可选）
  Future<void> _createQuote() async {
    final textController = TextEditingController();
    final authorController = TextEditingController();
    String category = '生活';
    final categories = _categories.where((c) => c != '全部').toList();

    await AppDialog.show(
      context,
      title: '新建文案',
      icon: Icons.add_comment_outlined,
      children: [
        StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dialogField(ctx, textController, '文案内容', maxLines: 3, autofocus: true),
              AppSpacings.md.hGap,
              _dialogField(ctx, authorController, '作者 / 出处（可选）'),
              AppSpacings.md.hGap,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map((c) => AppChip.selectable(
                          label: c,
                          selected: c == category,
                          onTap: () => setLocal(() => category = c),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
      actions: [
        AppButton.secondary(label: '取消', onPressed: () => Navigator.of(context).pop()),
        AppButton.primary(
          label: '保存',
          onPressed: () async {
            final text = textController.text.trim();
            if (text.isEmpty) return;
            final author = authorController.text.trim();
            await _quoteService.addQuote(Quote(
              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
              text: text,
              author: author.isEmpty ? null : author,
              category: category,
              createdAt: DateTime.now(),
            ));
            if (!mounted) return;
            _refreshCache();
            setState(() {});
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  /// 删除自建文案（builtin_ 前缀的内置文案不可删）
  Future<void> _confirmDelete(Quote quote) async {
    final ok = await AppDialog.confirm(
      context,
      title: '删除文案',
      message: '确定删除这条自建文案吗？',
      danger: true,
      confirmLabel: '删除',
    );
    if (ok == true) {
      _quoteService.deleteQuote(quote.id);
      _refreshCache();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final listHeight = MediaQuery.of(context).size.height * 0.45;
    return BottomBlurBar(
      blur: false,
      title: '选文案',
      subtitle: '内置 / 自建 / 联网文案，点击一条填入输入框',
      icon: Icons.format_quote,
      headerExtra: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppChip.action(
            label: _fetchingOnline ? '获取中' : '联网获取',
            icon: Icons.cloud_download_outlined,
            busy: _fetchingOnline,
            onTap: _fetchingOnline ? null : () => _fetchOnline(),
          ),
          8.wGap,
          AppChip.action(label: '新建', icon: Icons.add, onTap: _createQuote),
        ],
      ),
      children: [
        _buildSearchField(context),
        AppSpacings.md.hGap,
        _buildCategoryBar(context),
        AppSpacings.md.hGap,
        SizedBox(
          height: listHeight,
          child: _cachedFilteredQuotes.isEmpty
              ? const EmptyState(icon: Icons.format_quote, iconSize: 40, title: '没有匹配的文案')
              : ListView.builder(
                  itemCount: _cachedFilteredQuotes.length,
                  itemBuilder: (context, index) => _buildQuoteCard(context, _cachedFilteredQuotes[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GlassColors.bg(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: GlassColors.border(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          _searchQuery = v.trim();
          _refreshCache();
          setState(() {});
        },
        style: TextStyle(fontSize: AppFontSizes.sm, color: context.textPrimary),
        decoration: InputDecoration(
          icon: Icon(Icons.search, size: 18, color: context.textTertiary),
          border: InputBorder.none,
          hintText: '搜索文案 / 作者',
          hintStyle: TextStyle(fontSize: AppFontSizes.sm, color: context.textTertiary),
        ),
      ),
    );
  }

  Widget _buildCategoryBar(BuildContext context) {
    final categories = _categories;
    return SizedBox(
      width: double.infinity,
      // AppChip.selectable 高度 = 上下各 12 的内边距 + 13px 文字行高，约 43，
      // 固定高度过小会把标签文字裁切，这里用 48 保证完整显示
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => AppSpacings.sm.wGap,
        itemBuilder: (context, index) {
          final c = categories[index];
          return AppChip.selectable(
            label: c,
            selected: _selectedCategory == c,
            onTap: () {
              _selectedCategory = c;
              _refreshCache();
              setState(() {});
            },
          );
        },
        clipBehavior: Clip.none,
      ),
    );
  }

  Widget _buildQuoteCard(BuildContext context, Quote quote) {
    final deletable = !quote.id.startsWith('builtin_');
    final author = _authorDisplay(quote);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacings.md),
      child: GlassCard(
        borderRadius: AppRadii.lg,
        onTap: () => Navigator.pop(context, quote),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quote.text,
              style: TextStyle(
                fontSize: AppFontSizes.base,
                color: context.textPrimary,
                height: AppLineHeights.relaxed,
              ),
            ),
            AppSpacings.md.hGap,
            Container(height: 1, color: context.divider),
            AppSpacings.md.hGap,
            Row(
              children: [
                AppChip.tag(label: quote.category),
                const Spacer(),
                if (deletable) ...[
                  GestureDetector(
                    onTap: () => _confirmDelete(quote),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 16, color: context.textTertiary),
                    ),
                  ),
                  8.wGap,
                ],
                if (author.isNotEmpty)
                  Flexible(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.sm,
                        fontStyle: FontStyle.italic,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(BuildContext context, TextEditingController controller, String hint,
      {int maxLines = 1, bool autofocus = false}) {
    return Container(
      decoration: BoxDecoration(
        color: GlassColors.bg(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: GlassColors.borderSubtle(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacings.lg, vertical: AppSpacings.md),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        autofocus: autofocus,
        style: TextStyle(fontSize: AppFontSizes.base, color: context.textPrimary),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: context.textTertiary),
        ),
      ),
    );
  }

  String _authorDisplay(Quote quote) {
    if (quote.author != null) return '— ${quote.author}';
    if (quote.source != null) return '— ${quote.source}';
    return '';
  }
}
