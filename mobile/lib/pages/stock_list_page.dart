import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_page.dart';

/// 行情页 — 自选 / 全市场
class StockListPage extends ConsumerStatefulWidget {
  const StockListPage({super.key});

  @override
  ConsumerState<StockListPage> createState() => _StockListPageState();
}

class _StockListPageState extends ConsumerState<StockListPage> {
  int _tabIndex = 1; // 默认显示"市场"

  // 全市场数据
  List<StockRealTime> _marketStocks = [];
  bool _marketLoading = false;
  int _page = 1;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMarketStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMarketStocks({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() => _marketLoading = true);
    }
    try {
      final api = StockApi();
      final stocks = await api.getStockList(
        page: loadMore ? _page + 1 : 1,
        pageSize: 50,
        name: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          if (loadMore) {
            _marketStocks.addAll(stocks);
            _page++;
          } else {
            _marketStocks = stocks;
            _page = 1;
          }
          _marketLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _marketLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final followAsync = ref.watch(followListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segmentedButton('自选', 0),
            const SizedBox(width: 8),
            _segmentedButton('市场', 1),
          ],
        ),
        centerTitle: true,
      ),
      body: _tabIndex == 0 ? _buildFollowTab(followAsync) : _buildMarketTab(),
    );
  }

  Widget _segmentedButton(String label, int index) {
    final selected = _tabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              index == 0 ? Icons.star : Icons.explore,
              size: 16,
              color: selected ? Colors.white : Colors.grey[500],
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[600],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowTab(AsyncValue<List<StockRealTime>> followAsync) {
    return RefreshIndicator(
      onRefresh: () => ref.read(followListProvider.notifier).refresh(),
      child: followAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(ref, e, isFollow: true),
        data: (stocks) {
          if (stocks.isEmpty) {
            return _buildEmpty(
              icon: Icons.star_border,
              title: '还没有关注任何股票',
              subtitle: '切换到"市场"页浏览并关注',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: stocks.length,
            itemBuilder: (_, i) => StockCard(
              stock: stocks[i],
              onTap: () => _openDetail(stocks[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarketTab() {
    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索股票名称',
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.07),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                      onPressed: () {
                        _searchController.clear();
                        _fetchMarketStocks();
                      },
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _fetchMarketStocks(),
          ),
        ),
        // 列表
        Expanded(
          child: _marketLoading && _marketStocks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _fetchMarketStocks(),
                  child: _marketStocks.isEmpty
                      ? _buildEmpty(
                          icon: Icons.search_off,
                          title: '未找到相关股票',
                          subtitle: '请尝试其他搜索词',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 4),
                          itemCount: _marketStocks.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _marketStocks.length) {
                              return _marketLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: TextButton(
                                          onPressed: () =>
                                              _fetchMarketStocks(
                                                  loadMore: true),
                                          child: const Text('加载更多'),
                                        ),
                                      ),
                                    );
                            }
                            return StockCard(
                              stock: _marketStocks[i],
                              onTap: () => _openDetail(_marketStocks[i]),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildError(WidgetRef ref, Object error, {bool isFollow = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '获取数据失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isFollow
                ? () => ref.read(followListProvider.notifier).refresh()
                : () => _fetchMarketStocks(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openDetail(StockRealTime stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailPage(stock: stock),
      ),
    );
  }
}
