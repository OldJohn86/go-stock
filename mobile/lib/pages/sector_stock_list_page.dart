import 'package:flutter/material.dart';

import '../api/market_api.dart';
import 'stock_detail_page.dart';

/// 板块成分股列表页 — 展示某个行业/概念板块下的全部个股
class SectorStockListPage extends StatefulWidget {
  final String sectorName;
  final String sectorType; // "industry" 或 "concept"

  const SectorStockListPage({
    super.key,
    required this.sectorName,
    required this.sectorType,
  });

  @override
  State<SectorStockListPage> createState() => _SectorStockListPageState();
}

class _SectorStockListPageState extends State<SectorStockListPage> {
  final _api = MarketApi();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _stocks = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 50;
  String? _error;

  // 排序
  String _sortField = 'CHANGE_RATE';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchData();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final data = await _api.getSectorStocks(
        name: widget.sectorName,
        type: widget.sectorType,
        page: 1,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _stocks = data;
          _loading = false;
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchData();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final data = await _api.getSectorStocks(
        name: widget.sectorName,
        type: widget.sectorType,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _page++;
          _stocks.addAll(data);
          _loadingMore = false;
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = false;
      }
    });
  }

  List<Map<String, dynamic>> get _sortedStocks {
    final sorted = List<Map<String, dynamic>>.from(_stocks);
    sorted.sort((a, b) {
      final va = _toDouble(a[_sortField]);
      final vb = _toDouble(b[_sortField]);
      return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
    });
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.sectorName)),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 首次加载中
    if (_loading && _stocks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 加载失败且无缓存数据
    if (_error != null && _stocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.disabledColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 空状态
    if (!_loading && _stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
              '暂无成分股数据',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // 排序栏 + 计数
          SliverToBoxAdapter(
            child: _buildSortBar(theme),
          ),

          // 股票列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildStockItem(_sortedStocks[i], theme),
              childCount: _sortedStocks.length,
            ),
          ),

          // 加载更多指示
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),

          // 没有更多
          if (!_hasMore && _stocks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '— 已展示全部 ${_stocks.length} 只股票 —',
                    style: TextStyle(fontSize: 12, color: theme.disabledColor),
                  ),
                ),
              ),
            ),

          // 底部间距
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSortBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Text(
            '共 ${_stocks.length} 只股票',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          _sortButton(theme, '涨幅', 'CHANGE_RATE'),
          const SizedBox(width: 4),
          _sortButton(theme, '换手率', 'TURNOVERRATE'),
          const SizedBox(width: 4),
          _sortButton(theme, '量比', 'VOLUME_RATIO'),
          const SizedBox(width: 4),
          _sortButton(theme, '价格', 'NEW_PRICE'),
        ],
      ),
    );
  }

  Widget _sortButton(ThemeData theme, String label, String field) {
    final active = _sortField == field;
    return GestureDetector(
      onTap: () => _setSort(field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? theme.colorScheme.primary : theme.disabledColor,
              ),
            ),
            if (active)
              Icon(
                _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockItem(Map<String, dynamic> item, ThemeData theme) {
    final code = item['SECUCODE'] as String? ?? '';
    final name = item['SECURITY_NAME_ABBR'] as String? ?? '';
    final price = _toDouble(item['NEW_PRICE']);
    final changeRate = _toDouble(item['CHANGE_RATE']);
    final turnoverRate = _toDouble(item['TURNOVERRATE']);
    final volumeRatio = _toDouble(item['VOLUME_RATIO']);
    final isUp = changeRate >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailPage.fromCode(code, name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // 左侧：股票信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称 + 代码
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          code.replaceAll(RegExp(r'\.(SZ|SH|BJ)$'), ''),
                          style: TextStyle(
                            color: theme.disabledColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 换手率 + 量比
                    Row(
                      children: [
                        if (turnoverRate > 0)
                          _miniTag(
                            theme,
                            '换手 ${turnoverRate.toStringAsFixed(1)}%',
                            theme.disabledColor,
                          ),
                        if (turnoverRate > 0 && volumeRatio > 0)
                          const SizedBox(width: 6),
                        if (volumeRatio > 0)
                          _miniTag(
                            theme,
                            '量比 ${volumeRatio.toStringAsFixed(2)}',
                            volumeRatio > 2 ? Colors.orange : theme.disabledColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 右侧：价格 + 涨幅
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price > 0 ? price.toStringAsFixed(2) : '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isUp ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    '${isUp ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isUp ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
