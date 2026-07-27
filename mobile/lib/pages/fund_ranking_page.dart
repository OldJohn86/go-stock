import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/fund_api.dart';
import 'fund_detail_page.dart';

/// 基金排名页
class FundRankingPage extends ConsumerStatefulWidget {
  const FundRankingPage({super.key});

  @override
  ConsumerState<FundRankingPage> createState() => _FundRankingPageState();
}

class _FundRankingPageState extends ConsumerState<FundRankingPage> {
  final _api = FundApi();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalPages = 0;
  String? _error;
  String _fundType = '1'; // 1=全部
  String _sortField = 'yearGrowth';

  final _fundTypes = ['1', '2', '3', '4', '5'];
  final _fundTypeLabels = ['全部', '股票型', '混合型', '债券型', '指数型'];
  final _sortFields = ['yearGrowth', 'monthGrowth', 'weekGrowth', 'dailyGrowth', 'sixMonthGrowth'];
  final _sortLabels = ['近1年', '近1月', '近1周', '日涨幅', '近6月'];

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    _page = 1;
    _hasMore = true;
    try {
      final result = await _api.getRanking(fundType: _fundType, sortField: _sortField, pageIndex: _page);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final its = (result['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _items = its;
          _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
          _hasMore = _page < _totalPages;
          _loading = false;
        });
      } else { setState(() { _error = '暂无数据'; _loading = false; }); }
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final result = await _api.getRanking(fundType: _fundType, sortField: _sortField, pageIndex: _page);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final its = (result['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() { _items.addAll(its); _hasMore = _page < _totalPages; _loadingMore = false; });
      } else { setState(() { _page--; _loadingMore = false; }); }
    } catch (_) { if (mounted) setState(() { _page--; _loadingMore = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('基金排行'), centerTitle: true),
      body: Column(children: [
        // 筛选行
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 类型筛选
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fundTypes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => FilterChip(
                  label: Text(_fundTypeLabels[i], style: TextStyle(fontSize: 12, color: _fundType == _fundTypes[i] ? colorScheme.onPrimaryContainer : null)),
                  selected: _fundType == _fundTypes[i],
                  onSelected: (_) { setState(() => _fundType = _fundTypes[i]); _load(); },
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sortFields.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => FilterChip(
                  label: Text(_sortLabels[i], style: TextStyle(fontSize: 12, color: _sortField == _sortFields[i] ? colorScheme.onPrimaryContainer : null)),
                  selected: _sortField == _sortFields[i],
                  onSelected: (_) { setState(() => _sortField = _sortFields[i]); _load(); },
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ]),
        ),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) return Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));

          final item = _items[index];
          final name = (item['name'] as String?) ?? '';
          final code = (item['code'] as String?) ?? '';
          final dailyGrowth = (item['dailyGrowth'] as num?)?.toDouble();
          final weekGrowth = (item['weekGrowth'] as num?)?.toDouble();
          final monthGrowth = (item['monthGrowth'] as num?)?.toDouble();
          final yearGrowth = (item['yearGrowth'] as num?)?.toDouble();
          final netValue = (item['netUnitValue'] as num?)?.toDouble();

          final displayGrowth = switch (_sortField) {
            'weekGrowth' => weekGrowth,
            'monthGrowth' => monthGrowth,
            'yearGrowth' => yearGrowth,
            'sixMonthGrowth' => (item['sixMonthGrowth'] as num?)?.toDouble(),
            _ => dailyGrowth,
          };

          return ListTile(
            dense: true,
            leading: SizedBox(width: 24, child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: index < 3 ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant))),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            subtitle: Text('$code${netValue != null ? '  |  ${netValue.toStringAsFixed(4)}' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            trailing: displayGrowth != null
                ? Text('${displayGrowth >= 0 ? '+' : ''}${displayGrowth.toStringAsFixed(2)}%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: displayGrowth >= 0 ? Colors.red : Colors.green))
                : null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FundDetailPage(fundCode: code, fundName: name))),
          );
        },
      ),
    );
  }
}
