import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../api/trading_api.dart';
import '../api/stock_api.dart';
import '../models/trading_record.dart';
import '../models/stock_info.dart';
import '../widgets/skeleton.dart';
import '../widgets/trading_charts.dart';
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
  bool _showCharts = false;

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

  Future<void> _deleteRecord(TradingRecordItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${item.stockName}(${item.stockCode}) 的交易记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await _api.deleteRecord(item.id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败')),
        );
      }
    }
  }

  void _showAddRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddRecordSheet(
        onSaved: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _exportRecords() async {
    final loading = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('正在导出...'),
        ],
      )),
    );

    final filePath = await _api.exportRecords(
      direction: _directionFilter,
      keyword: _keyword.isEmpty ? null : _keyword,
    );

    loading.close();

    if (!mounted) return;

    if (filePath != null) {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '交易记录导出',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _showAddRecordSheet,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const TradingRecordSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 统计卡片
                  if (_stats != null) SliverToBoxAdapter(
                    child: _buildStatsCard(theme),
                  ),
                  // 图表切换
                  if (_stats != null && _records.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(
                                _showCharts ? Icons.bar_chart : Icons.show_chart,
                                size: 16,
                              ),
                              label: Text(_showCharts ? '隐藏图表' : '交易图表'),
                              onPressed: () => setState(() => _showCharts = !_showCharts),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.file_download, size: 16),
                              label: const Text('导出CSV'),
                              onPressed: _exportRecords,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 图表内容
                  if (_showCharts && _stats != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TradingStatsCharts(stats: _stats!, records: _records),
                      ),
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
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: _showAddRecordSheet,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('添加第一条记录'),
                              ),
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

    return Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
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
        onLongPress: () => _deleteRecord(item),
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

// ============================================================
// 添加交易记录底部表单（unchanged from previous version）
// ============================================================
class _AddRecordSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddRecordSheet({required this.onSaved});

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _stockCodeCtrl = TextEditingController();
  final _stockNameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _stopLossCtrl = TextEditingController();
  final _takeProfitCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  String _direction = '买入';
  bool _saving = false;

  // 股票搜索
  List<StockRealTime> _searchResults = [];
  bool _searching = false;
  bool _searchFocused = false;

  @override
  void dispose() {
    _stockCodeCtrl.dispose();
    _stockNameCtrl.dispose();
    _priceCtrl.dispose();
    _volumeCtrl.dispose();
    _feeCtrl.dispose();
    _stopLossCtrl.dispose();
    _takeProfitCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchStock(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await StockApi().getStockList(name: keyword, pageSize: 10);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectStock(StockRealTime stock) {
    _stockCodeCtrl.text = stock.stockCode;
    _stockNameCtrl.text = stock.stockName;
    setState(() {
      _searchResults = [];
      _searchFocused = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final ok = await TradingApi().saveRecord(
      stockCode: _stockCodeCtrl.text.trim(),
      stockName: _stockNameCtrl.text.trim(),
      direction: _direction,
      price: double.parse(_priceCtrl.text.trim()),
      volume: int.parse(_volumeCtrl.text.trim()),
      fee: double.tryParse(_feeCtrl.text.trim()) ?? 0,
      stopLossPrice: double.tryParse(_stopLossCtrl.text.trim()) ?? 0,
      takeProfitPrice: double.tryParse(_takeProfitCtrl.text.trim()) ?? 0,
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
    );
    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('交易记录已保存')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请检查参数')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // 标题 + 关闭
                Row(
                  children: [
                    Text('添加交易记录', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 股票搜索
                Text('股票', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: _stockCodeCtrl,
                  decoration: InputDecoration(
                    hintText: '输入股票代码搜索',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    _searchStock(v);
                    setState(() => _searchFocused = true);
                  },
                  onTap: () => setState(() => _searchResults.isNotEmpty ? _searchFocused = true : null),
                ),
                if (_searchFocused && _searchResults.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _searchResults[i];
                        return ListTile(
                          dense: true,
                          title: Text(s.stockName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(s.stockCode, style: TextStyle(fontSize: 12, color: theme.disabledColor)),
                          trailing: Text(
                            s.currentPrice > 0 ? s.currentPrice.toStringAsFixed(2) : '-',
                            style: TextStyle(fontWeight: FontWeight.bold, color: s.isUp ? Colors.red : Colors.green),
                          ),
                          onTap: () => _selectStock(s),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stockNameCtrl,
                    decoration: InputDecoration(
                      hintText: '股票名称',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 交易方向
                Text('方向', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.shopping_cart, size: 16), SizedBox(width: 4), Text('买入')],
                        ),
                        selected: _direction == '买入',
                        selectedColor: Colors.red.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _direction = '买入'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.monetization_on, size: 16), SizedBox(width: 4), Text('卖出')],
                        ),
                        selected: _direction == '卖出',
                        selectedColor: Colors.green.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _direction = '卖出'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 价格和数量
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: InputDecoration(
                          labelText: '价格',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入价格';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return '请输入有效价格';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _volumeCtrl,
                        decoration: InputDecoration(
                          labelText: '数量（股）',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入数量';
                          final val = int.tryParse(v.trim());
                          if (val == null || val <= 0) return '请输入有效数量';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 可选字段
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feeCtrl,
                        decoration: InputDecoration(
                          labelText: '手续费（可选）',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _stopLossCtrl,
                        decoration: InputDecoration(
                          labelText: '止损价（可选）',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _takeProfitCtrl,
                        decoration: InputDecoration(
                          labelText: '止盈价（可选）',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 买入/卖出原因
                Text('原因（可选）', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '记录买入或卖出原因...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 24),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('保存记录', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
