import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/market_api.dart';
import '../api/stock_api.dart';

/// 股票公告页面
class StockNoticePage extends ConsumerStatefulWidget {
  const StockNoticePage({super.key});

  @override
  ConsumerState<StockNoticePage> createState() => _StockNoticePageState();
}

class _StockNoticePageState extends ConsumerState<StockNoticePage> {
  final _api = MarketApi();
  final _stockApi = StockApi();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;
  List<String> _followedCodes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Get followed stock codes
      final followed = await _stockApi.getFollowList();
      if (!mounted) return;

      if (followed.isEmpty) {
        setState(() {
          _list = [];
          _loading = false;
          _error = '自选股列表为空，请先添加自选股';
        });
        return;
      }

      _followedCodes = followed
          .map((s) => s.stockCode)
          .where((c) => c.isNotEmpty)
          .toList();

      if (_followedCodes.isEmpty) {
        setState(() {
          _list = [];
          _loading = false;
          _error = '无有效的股票代码';
        });
        return;
      }

      // Query notices for first 10 followed stocks
      final codes = _followedCodes.take(10).join(',');
      final data = await _api.getStockNotice(codes);
      if (!mounted) return;

      setState(() {
        _list = data;
        _loading = false;
        if (data.isEmpty) {
          _error = '暂无公告数据';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('上市公司公告'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(textTheme),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _load,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('暂无公告', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _list[index];
          final title = (item['title'] as String?) ?? '';
          final noticeDate = (item['notice_date'] as String?) ?? '';
          final artCode = (item['art_code'] as String?) ?? '';
          final columns = item['columns'] as List<dynamic>?;
          String columnName = '';
          if (columns != null && columns.isNotEmpty) {
            final col = columns[0] as Map<String, dynamic>?;
            columnName = (col?['column_name'] as String?) ?? '';
          }

          return ListTile(
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (columnName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        columnName,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (columnName.isNotEmpty) const SizedBox(width: 8),
                  Text(
                    noticeDate,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              // Try to open the notice URL
              if (artCode.isNotEmpty) {
                _openNoticeUrl(artCode, title);
              }
            },
          );
        },
      ),
    );
  }

  void _openNoticeUrl(String artCode, String title) {
    // EastMoney notice URL format
    final url =
        'https://np-anotice-stock.eastmoney.com/api/security/ann?art_code=$artCode';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Text('公告链接:\n$url\n\n请在浏览器中查看完整内容。'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
