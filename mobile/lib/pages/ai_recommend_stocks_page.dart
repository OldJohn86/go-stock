import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/ai_recommend_api.dart';
import 'stock_detail_page.dart';

/// AI 推荐股票列表页
class AiRecommendStocksPage extends ConsumerStatefulWidget {
  const AiRecommendStocksPage({super.key});

  @override
  ConsumerState<AiRecommendStocksPage> createState() =>
      _AiRecommendStocksPageState();
}

class _AiRecommendStocksPageState
    extends ConsumerState<AiRecommendStocksPage> {
  final _api = AiRecommendApi();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalPages = 0;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    _page = 1;
    _hasMore = true;

    try {
      final result = await _api.getList(
        keyword: _keyword,
        page: _page,
        pageSize: 20,
      );
      if (!mounted) return;

      if (result.isNotEmpty) {
        final list = (result['list'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        setState(() {
          _list = list;
          _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
          _hasMore = _page < _totalPages;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '网络异常：${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;

    try {
      final result = await _api.getList(
        keyword: _keyword,
        page: _page,
        pageSize: 20,
      );
      if (!mounted) return;

      if (result.isNotEmpty) {
        final list = (result['list'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        setState(() {
          _list.addAll(list);
          _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
          _hasMore = _page < _totalPages;
          _loadingMore = false;
        });
      } else {
        setState(() {
          _page--;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _page--;
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearch(String value) {
    _keyword = value;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 推荐股票'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索股票代码、名称或板块...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onSearch,
            ),
          ),

          // 列表
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadData,
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
            Text('暂无推荐数据', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _list.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _StockRecommendCard(
            item: _list[index],
            api: _api,
            onChanged: _loadData,
            onTap: () => _openStockDetail(_list[index]),
          );
        },
      ),
    );
  }

  void _openStockDetail(Map<String, dynamic> item) {
    final code = (item['stockCode'] as String?) ?? '';
    final name = (item['stockName'] as String?) ?? '';
    if (code.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailPage.fromCode(code, name),
      ),
    );
  }
}

class _StockRecommendCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final AiRecommendApi api;
  final VoidCallback onChanged;
  final VoidCallback onTap;

  const _StockRecommendCard({
    required this.item,
    required this.api,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = (item['stockName'] as String?) ?? '';
    final code = (item['stockCode'] as String?) ?? '';
    final bkName = (item['bkName'] as String?) ?? '';
    final modelName = (item['modelName'] as String?) ?? '';
    final rating = (item['rating'] as String?) ?? '';
    final reason = (item['recommendReason'] as String?) ?? '';
    final buyPrice = (item['recommendBuyPrice'] as String?) ?? '';
    final stopProfit = (item['recommendStopProfitPrice'] as String?) ?? '';
    final stopLoss = (item['recommendStopLossPrice'] as String?) ?? '';
    final price = (item['stockPrice'] as String?) ?? '';
    final currentPrice = (item['stockCurrentPrice'] as String?) ?? '';
    final prePrice = (item['stockPrePrice'] as String?) ?? '';
    final risk = (item['riskRemarks'] as String?) ?? '';
    final enableAlert = (item['enableAlert'] as bool?) ?? false;
    final dateStr = (item['dataTime'] as String?) ?? '';

    // 计算涨跌幅
    String changePercent = '';
    Color? changeColor;
    if (currentPrice.isNotEmpty && prePrice.isNotEmpty && prePrice != '0') {
      final cur = double.tryParse(currentPrice) ?? 0;
      final pre = double.tryParse(prePrice) ?? 0;
      if (pre > 0) {
        final pct = ((cur - pre) / pre * 100);
        changePercent = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
        changeColor = pct >= 0 ? Colors.red : Colors.green;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：股票名称 + 代码 + 评级
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          code,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                        if (bkName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bkName,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (rating.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: rating.contains('买入')
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        rating,
                        style: textTheme.labelSmall?.copyWith(
                          color: rating.contains('买入')
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              // 价格信息行
              const SizedBox(height: 8),
              Row(
                children: [
                  // 推荐价格
                  if (price.isNotEmpty)
                    _InfoChip(label: '推荐', value: price),
                  const SizedBox(width: 8),
                  // 当前价格
                  if (currentPrice.isNotEmpty)
                    _InfoChip(
                        label: '当前', value: currentPrice),
                  const SizedBox(width: 8),
                  // 涨跌幅
                  if (changePercent.isNotEmpty && changeColor != null)
                    Text(
                      changePercent,
                      style: textTheme.bodyMedium?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Spacer(),
                  // 预警开关
                  SizedBox(
                    height: 28,
                    child: Switch.adaptive(
                      value: enableAlert,
                      onChanged: (v) async {
                        final id = (item['ID'] as num?)?.toInt() ?? 0;
                        if (id > 0) {
                          await api.updateAlert(id, v);
                          onChanged();
                        }
                      },
                    ),
                  ),
                  const Text('预警', style: TextStyle(fontSize: 11)),
                ],
              ),

              // 买卖价位
              if (buyPrice.isNotEmpty || stopProfit.isNotEmpty || stopLoss.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (buyPrice.isNotEmpty)
                        _TagChip(
                          label: '买入: $buyPrice',
                          color: Colors.red,
                        ),
                      if (stopProfit.isNotEmpty)
                        _TagChip(
                          label: '止盈: $stopProfit',
                          color: Colors.orange,
                        ),
                      if (stopLoss.isNotEmpty)
                        _TagChip(
                          label: '止损: $stopLoss',
                          color: Colors.green,
                        ),
                    ],
                  ),
                ),

              // 推荐理由
              if (reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

              // 风险提示
              if (risk.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.orange[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          risk,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.orange[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 底部：模型 + 时间
              if (modelName.isNotEmpty || dateStr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      if (modelName.isNotEmpty)
                        Text(
                          modelName,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      if (modelName.isNotEmpty && dateStr.isNotEmpty)
                        const SizedBox(width: 8),
                      if (dateStr.isNotEmpty)
                        Text(
                          _formatDate(dateStr),
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr.replaceAll('T', ' ').replaceAll('Z', ''));
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
