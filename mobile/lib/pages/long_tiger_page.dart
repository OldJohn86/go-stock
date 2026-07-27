import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/market_api.dart';
import 'stock_detail_page.dart';

/// 龙虎榜页面
class LongTigerPage extends ConsumerStatefulWidget {
  const LongTigerPage({super.key});

  @override
  ConsumerState<LongTigerPage> createState() => _LongTigerPageState();
}

class _LongTigerPageState extends ConsumerState<LongTigerPage> {
  final _api = MarketApi();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;
  String _selectedDate = _todayDate();

  static String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

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
      final data = await _api.getLongTiger(date: _selectedDate);
      if (mounted) setState(() => _list = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _load();
    }
  }

  String _formatAmount(dynamic val) {
    final v = (val as num?)?.toDouble() ?? 0;
    if (v.abs() >= 100000000) {
      return '${(v / 100000000).toStringAsFixed(2)}亿';
    } else if (v.abs() >= 10000) {
      return '${(v / 10000).toStringAsFixed(0)}万';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('龙虎榜'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              _selectedDate.substring(5),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      body: _buildBody(textTheme),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(child: Text('今日无龙虎榜数据', style: TextStyle(color: Colors.grey[500])));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _list[index];
          final name = (item['SECURITY_NAME_ABBR'] as String?) ?? '';
          final code = (item['SECURITY_CODE'] as String?) ?? '';
          final closePrice = (item['CLOSE_PRICE'] as num?)?.toDouble() ?? 0;
          final changeRate = (item['CHANGE_RATE'] as num?)?.toDouble() ?? 0;
          final netAmt = (item['BILLBOARD_NET_AMT'] as num?)?.toDouble() ?? 0;
          final buyAmt = (item['BILLBOARD_BUY_AMT'] as num?)?.toDouble() ?? 0;
          final sellAmt = (item['BILLBOARD_SELL_AMT'] as num?)?.toDouble() ?? 0;
          final dealAmt = (item['BILLBOARD_DEAL_AMT'] as num?)?.toDouble() ?? 0;
          final accumAmt = (item['ACCUM_AMOUNT'] as num?)?.toDouble() ?? 0;
          final dealAmtRatio = (item['DEAL_AMOUNT_RATIO'] as num?)?.toDouble() ?? 0;
          final explain = (item['EXPLAIN'] as String?) ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (code.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockDetailPage.fromCode(code, name),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 股票名称 + 代码 + 涨幅
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                name,
                                style: textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                code,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: changeRate >= 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),

                    if (explain.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          explain,
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // 数据行
                    Row(
                      children: [
                        _DataColumn(
                            label: '收盘价', value: closePrice.toStringAsFixed(2)),
                        _DataColumn(label: '净买入', value: _formatAmount(netAmt)),
                        _DataColumn(
                            label: '买入额', value: _formatAmount(buyAmt)),
                        _DataColumn(
                            label: '卖出额', value: _formatAmount(sellAmt)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _DataColumn(
                            label: '成交额', value: _formatAmount(dealAmt)),
                        _DataColumn(
                            label: '总金额', value: _formatAmount(accumAmt)),
                        _DataColumn(
                            label: '成交占比',
                            value: '${dealAmtRatio.toStringAsFixed(1)}%'),
                        const SizedBox(width: 60), // placeholder
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DataColumn extends StatelessWidget {
  final String label;
  final String value;

  const _DataColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
