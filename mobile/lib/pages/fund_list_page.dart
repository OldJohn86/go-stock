import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/fund_api.dart';
import 'fund_ranking_page.dart';
import 'fund_search_page.dart';
import 'fund_detail_page.dart';

/// 基金追踪主页 — 关注的基金列表
class FundListPage extends ConsumerStatefulWidget {
  const FundListPage({super.key});

  @override
  ConsumerState<FundListPage> createState() => _FundListPageState();
}

class _FundListPageState extends ConsumerState<FundListPage> {
  final _api = FundApi();
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
    setState(() { _loading = true; _error = null; });
    _page = 1;
    _hasMore = true;
    try {
      final result = await _api.getList(keyword: _keyword, pageIndex: _page);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final items = (result['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _list = items;
          _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
          _hasMore = _page < _totalPages;
          _loading = false;
        });
      } else {
        setState(() { _error = '加载失败'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '网络异常: $e'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final result = await _api.getList(keyword: _keyword, pageIndex: _page);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final items = (result['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() { _list.addAll(items); _hasMore = _page < _totalPages; _loadingMore = false; });
      } else { setState(() { _page--; _loadingMore = false; }); }
    } catch (_) { if (mounted) setState(() { _page--; _loadingMore = false; }); }
  }

  Future<void> _unfollow(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消关注'),
        content: Text('确定取消关注基金 $code？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('取消关注')),
        ],
      ),
    );
    if (confirm == true) {
      final msg = await _api.unfollow(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('基金追踪'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search), tooltip: '搜索基金', onPressed: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FundSearchPage()));
            if (result == true && mounted) _loadData();
          }),
          IconButton(icon: const Icon(Icons.leaderboard), tooltip: '基金排行', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundRankingPage()))),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索已关注的基金...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _keyword = ''; _loadData(); })
                    : null,
                filled: true, fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) { _keyword = v; _loadData(); },
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16), FilledButton.tonal(onPressed: _loadData, child: const Text('重试')),
        ]),
      );
    }
    if (_list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12), const Text('还没有关注的基金', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8), const Text('点击右上角搜索添加基金', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _list.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _list.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          return _FundCard(item: _list[index], onTap: () => _openDetail(_list[index]), onUnfollow: () => _unfollow(_list[index]['code'] as String? ?? ''));
        },
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
    final code = (item['code'] as String?) ?? '';
    final name = (item['name'] as String?) ?? '';
    if (code.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => FundDetailPage(fundCode: code, fundName: name)));
  }
}

class _FundCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onUnfollow;

  const _FundCard({required this.item, required this.onTap, required this.onUnfollow});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final code = (item['code'] as String?) ?? '';
    final name = (item['name'] as String?) ?? '';
    final netValue = (item['netUnitValue'] as num?)?.toDouble();
    final estimatedRate = (item['netEstimatedRate'] as num?)?.toDouble();
    final actualRate = (item['netActualRate'] as num?)?.toDouble();
    final date = (item['netUnitValueDate'] as String?) ?? '';
    final estTime = (item['netEstimatedUnitTime'] as String?) ?? '';

    // Determine which rate to show
    final rate = actualRate ?? estimatedRate;
    Color? rateColor = rate != null ? (rate >= 0 ? Colors.red : Colors.green) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(code, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              if (netValue != null) Text(netValue.toStringAsFixed(4), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (rate != null) Text('${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%', style: TextStyle(color: rateColor, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text(date.isNotEmpty ? date.substring(5) : '', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              if (estTime.isNotEmpty) Text(' $estTime', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const SizedBox(width: 4),
              InkWell(onTap: onUnfollow, child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey[400]))),
            ]),
          ]),
        ),
      ),
    );
  }
}
