import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_page.dart';

/// 全市场行情页 — 底部导航第二个 Tab
class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});

  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage>
    with WidgetsBindingObserver {
  final StockApi _api = StockApi();
  // 大盘指数
  List<StockRealTime> _indices = [];
  bool _indicesLoading = true;
  // 全市场股票
  List<StockRealTime> _stocks = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchIndices();
    _fetchStocks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchIndices();
      _fetchStocks(showLoading: false);
    }
  }

  Future<void> _fetchIndices() async {
    try {
      final data = await _api.getIndexList();
      if (mounted) setState(() { _indices = data; _indicesLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _indicesLoading = false);
    }
  }

  Future<void> _fetchStocks({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final stocks = await _api.getStockList(page: 1, pageSize: 50);
      if (mounted) {
        setState(() {
          _stocks = stocks;
          _page = 1;
          _hasMore = stocks.length >= 50;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (showLoading) _error = '数据加载失败，请检查网络后重试';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final stocks = await _api.getStockList(page: _page + 1, pageSize: 50);
      if (mounted) {
        setState(() {
          _stocks.addAll(stocks);
          _page++;
          _hasMore = stocks.length >= 50;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 大盘指数卡片
          _buildIndexSection(),
          // 市场统计
          _buildMarketStats(),
          const Divider(height: 1),
          // 股票列表
          Expanded(child: _buildStockList()),
        ],
      ),
    );
  }

  Widget _buildIndexSection() {
    if (_indicesLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_indices.isEmpty) return const SizedBox.shrink();

    // 只取前 4 个主要指数（上证/深证/创业板/科创50）
    final showIndices = _indices.take(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          for (int r = 0; r < (showIndices.length + 1) ~/ 2; r++)
            Padding(
              padding: EdgeInsets.only(bottom: r < ((showIndices.length + 1) ~/ 2) - 1 ? 10 : 0),
              child: Row(
                children: [
                  for (int c = 0; c < 2; c++)
                    if (r * 2 + c < showIndices.length)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: c == 0 ? 0 : 5,
                            right: c == 1 ? 0 : 5,
                          ),
                          child: _buildIndexCard(showIndices[r * 2 + c]),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIndexCard(StockRealTime idx) {
    final isUp = idx.isUp;
    final color = isUp ? Colors.red : Colors.green;
    final name = _indexName(idx.stockCode);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StockDetailPage(stock: idx)),
      ),
      child: Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    idx.currentPrice.toStringAsFixed(2),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isUp ? '+' : ''}${idx.changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isUp ? '+' : ''}${idx.change.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketStats() {
    final upCount = _stocks.where((s) => s.isUp).length;
    final downCount = _stocks.where((s) => !s.isUp && s.changePercent != 0).length;
    final flatCount = _stocks.where((s) => s.changePercent == 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _statChip('上涨', upCount, Colors.red),
          const SizedBox(width: 8),
          _statChip('下跌', downCount, Colors.green),
          const SizedBox(width: 8),
          _statChip('平盘', flatCount, Colors.grey),
          const Spacer(),
          Text(
            '共 ${_stocks.length} 只',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _fetchStocks(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetchStocks(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            _loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: _stocks.length + (_hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _stocks.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return _buildStockItem(_stocks[i]);
          },
        ),
      ),
    );
  }

  Widget _buildStockItem(StockRealTime stock) {
    final followAsync = ref.watch(followListProvider);
    final followedCodes =
        followAsync.valueOrNull?.map((e) => e.stockCode).toSet() ?? {};
    final isFollowed = followedCodes.contains(stock.stockCode);

    return StockCard(
      stock: stock,
      trailing: IconButton(
        icon: Icon(
          isFollowed ? Icons.star : Icons.star_border,
          color: isFollowed ? Colors.amber : Colors.grey,
          size: 20,
        ),
        onPressed: () {
          if (isFollowed) {
            _api.unfollowStock(stock.stockCode);
          } else {
            _api.followStock(stock.stockCode);
          }
          ref.read(followListProvider.notifier).refresh();
        },
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StockDetailPage(stock: stock)),
      ),
    );
  }

  String _indexName(String code) {
    final n = code.toUpperCase();
    if (n.contains('000001')) return '上证指数';
    if (n.contains('399001')) return '深证成指';
    if (n.contains('399006')) return '创业板指';
    if (n.contains('000688')) return '科创50';
    if (n.contains('000300')) return '沪深300';
    return code;
  }
}
