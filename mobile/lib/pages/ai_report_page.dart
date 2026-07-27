import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/ai_report_api.dart';

/// AI 研究报告浏览页
class AiReportPage extends ConsumerStatefulWidget {
  const AiReportPage({super.key});

  @override
  ConsumerState<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends ConsumerState<AiReportPage> {
  final _api = AiReportApi();
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
  int? _expandedIndex;

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
    setState(() { _loading = true; _error = null; _expandedIndex = null; });
    _page = 1;
    _hasMore = true;
    try {
      final result = await _api.getList(keyword: _keyword, page: _page);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final list = (result['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _list = list;
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
      final result = await _api.getList(keyword: _keyword, page: _page);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final list = (result['list'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _list.addAll(list);
          _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
          _hasMore = _page < _totalPages;
          _loadingMore = false;
        });
      } else {
        setState(() { _page--; _loadingMore = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _page--; _loadingMore = false; });
    }
  }

  Future<void> _deleteReport(int id, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除此研究报告？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await _api.delete(id);
      if (ok && mounted) {
        setState(() => _list.removeAt(index));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 研究报告'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索股票名称或关键词...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _keyword = ''; _loadData(); })
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
        Icon(Icons.article_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16), FilledButton.tonal(onPressed: _loadData, child: const Text('重试')),
      ]),
    );
    }    if (_list.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 12), Text('暂无研究报告', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _list.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _list.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          return _ReportCard(
            item: _list[index],
            index: index,
            isExpanded: _expandedIndex == index,
            onTap: () => setState(() => _expandedIndex = _expandedIndex == index ? null : index),
            onDelete: () => _deleteReport((_list[index]['ID'] as num?)?.toInt() ?? 0, index),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReportCard({required this.item, required this.index, required this.isExpanded, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stockName = (item['stockName'] as String?) ?? '';
    final stockCode = (item['stockCode'] as String?) ?? '';
    final question = (item['question'] as String?) ?? '';
    final content = (item['content'] as String?) ?? '';
    final modelName = (item['modelName'] as String?) ?? '';
    final createdAt = (item['CreatedAt'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (stockName.isNotEmpty) Text(stockName, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (stockCode.isNotEmpty) ...[const SizedBox(width: 6), Text(stockCode, style: TextStyle(fontSize: 12, color: Colors.grey[500]))],
                const Spacer(),
                if (modelName.isNotEmpty) Text(modelName, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                const SizedBox(width: 4),
                IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]), onPressed: onDelete, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
              ]),
              if (question.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(question, style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: isExpanded ? 10 : 2, overflow: TextOverflow.ellipsis),
              ),
              if (isExpanded && content.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                  child: SelectableText(content, style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5)),
                ),
              ),
              if (createdAt.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_formatDate(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String s) {
    try {
      final dt = DateTime.parse(s.replaceAll('T', ' ').replaceAll('Z', ''));
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return s; }
  }
}
