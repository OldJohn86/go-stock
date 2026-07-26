import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/trading_api.dart';
import '../models/trading_record.dart';
import 'stock_detail_page.dart';

/// 交易日志页
class TradingRecordPage extends ConsumerStatefulWidget {
  const TradingRecordPage({super.key});

  @override
  ConsumerState<TradingRecordPage> createState() => _TradingRecordPageState();
}

class _TradingRecordPageState extends ConsumerState<TradingRecordPage> {
  final _api = TradingApi();
  final _scrollController = ScrollController();

  List<TradingRecordItem> _records = [];
  TradingRecordStatistics? _stats;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _directionFilter;
  String _keyword = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _page = 1;
    _hasMore = true;
    await Future.wait([
      _loadRecords(),
      _loadStats(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRecords() async {
    final result = await _api.getRecords(
      page: _page,
      pageSize: 20,
      direction: _directionFilter,
      keyword: _keyword.isEmpty ? null : _keyword,
    );
    if (result != null && mounted) {
      setState(() {
        _records = result.list;
        _hasMore = result.page < result.totalPages;
      });
    }
  }

  Future<void> _loadStats() async {
    final stats = await _api.getStatistics();
    if (stats != null && mounted) {
      setState(() => _stats = stats);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    final result = await _api.getRecords(
      page: _page,
      pageSize: 20,
      direction: _directionFilter,
      keyword: _keyword.isEmpty ? null : _keyword,
    );
    if (result != null && mounted) {
      setState(() {
        _records.addAll(result.list);
        _hasMore = _page < result.totalPages;
        _loadingMore = false;
      });
    } else {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String value) {
    _keyword = value;
    _loadData();
  }

  void _setDirectionFilter(String? direction) {
    setState(() => _directionFilter = direction);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 统计卡片
                  if (_stats != null) SliverToBoxAdapter(
                    child: _buildStatsCard(theme),
                  ),
                  // 筛选栏
                  SliverToBoxAdapter(
                    child: _buildFilterBar(theme),
                  ),
                  // 记录列表
                  if (_records.isEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text('暂无交易记录', style: TextStyle(color: theme.disabledColor)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildRecordItem(_records[index], theme),
                        childCount: _records.length,
                      ),
                    ),
                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final s = _stats!;
    final isProfit = s.totalProfit >= 0;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 总盈亏
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isProfit ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isProfit ? Icons.trending_up : Icons.trending_down,
                  color: isProfit ? Colors.red : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text('总盈亏', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Text(
                _formatMoney(s.totalProfit),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isProfit ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '收益率 ${_formatPercent(s.profitRate)}',
            style: TextStyle(color: theme.disabledColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // 详细数据
          Row(
            children: [
              _buildStatItem(
                icon: Icons.account_balance_wallet,
                label: '持仓市值',
                value: _formatMoney(s.currentValue),
                theme: theme,
              ),
              _buildStatItem(
                icon: Icons.inventory_2,
                label: '持仓数量',
                value: '${s.stockCount} 只',
                theme: theme,
              ),
              _buildStatItem(
                icon: Icons.shopping_cart,
                label: '买入总额',
                value: _formatMoney(s.totalBuyAmount),
                theme: theme,
              ),
              _buildStatItem(
                icon: Icons.monetization_on,
                label: '卖出总额',
                value: _formatMoney(s.totalSellAmount),
                theme: theme,
              ),
            ],
          ),
          // 今日盈亏
          if (s.todayProfit != 0) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.today, size: 16, color: theme.disabledColor),
                const SizedBox(width: 4),
                Text('今日盈亏：', style: TextStyle(color: theme.disabledColor, fontSize: 13)),
                Text(
                  '${s.todayProfit >= 0 ? '+' : ''}${_formatMoney(s.todayProfit)} (${_formatPercent(s.todayProfitRate)})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: s.todayProfit >= 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: theme.disabledColor),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: theme.disabledColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索股票代码或名称',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
              suffixIcon: _keyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
            ),
            onSubmitted: _onSearch,
          ),
          const SizedBox(height: 8),
          // 方向筛选
          Row(
            children: [
              _buildFilterChip('全部', null, theme),
              const SizedBox(width: 8),
              _buildFilterChip('买入', '买入', theme),
              const SizedBox(width: 8),
              _buildFilterChip('卖出', '卖出', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, ThemeData theme) {
    final selected = _directionFilter == value;
    IconData icon;
    switch (value) {
      case '买入':
        icon = Icons.shopping_cart;
        break;
      case '卖出':
        icon = Icons.monetization_on;
        break;
      default:
        icon = Icons.all_inclusive;
    }
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selected ? Colors.white : theme.disabledColor),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
      selected: selected,
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
      onSelected: (_) => _setDirectionFilter(value),
    );
  }

  Widget _buildRecordItem(TradingRecordItem item, ThemeData theme) {
    final isBuy = item.direction == '买入';
    final isProfit = item.profitAmount >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailPage.fromCode(item.stockCode, item.stockName),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 方向标识
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isBuy ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isBuy ? '买' : '卖',
                    style: TextStyle(
                      color: isBuy ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 股票信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.stockName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.stockCode,
                          style: TextStyle(color: theme.disabledColor, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.tradingTime.substring(0, 10)}  ${item.price.toStringAsFixed(2)} × ${item.volume}股',
                      style: TextStyle(color: theme.disabledColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // 盈亏
              if (!isBuy)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isProfit ? '+' : ''}${_formatMoney(item.profitAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.red : Colors.green,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _formatPercent(item.profitPercent),
                      style: TextStyle(
                        color: isProfit ? Colors.red : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  _formatMoney(item.amount),
                  style: TextStyle(color: theme.disabledColor, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMoney(double value) {
    if (value.abs() >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(2)}万';
    }
    return '¥${value.toStringAsFixed(2)}';
  }

  String _formatPercent(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
  }
}
