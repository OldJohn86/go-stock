import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/fund_api.dart';

/// 基金搜索页
class FundSearchPage extends ConsumerStatefulWidget {
  const FundSearchPage({super.key});

  @override
  ConsumerState<FundSearchPage> createState() => _FundSearchPageState();
}

class _FundSearchPageState extends ConsumerState<FundSearchPage> {
  final _api = FundApi();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  final _controller = TextEditingController();

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() { _results = []; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.search(keyword.trim());
      if (mounted) setState(() => _results = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _follow(String code) async {
    final msg = await _api.follow(code);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
      if (msg.contains('成功')) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索基金'), centerTitle: true),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '输入基金代码或名称',
              prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
            onChanged: (v) async {
              if (v.trim().length >= 2) {
                await _search(v);
              } else {
                setState(() { _results = []; _error = null; });
              }
            },
          ),
        ),
        Expanded(child: _buildResults()),
      ]),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('查询失败: $_error'));
    if (_results.isEmpty) return Center(child: Text('输入 2 个字符以上搜索', style: TextStyle(color: Colors.grey[500])));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _results[index];
        final code = (item['code'] as String?) ?? '';
        final name = (item['name'] as String?) ?? '';
        final type = (item['type'] as String?) ?? '';

        return ListTile(
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Row(children: [
            Text(code, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            if (type.isNotEmpty) ...[const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(type, style: TextStyle(fontSize: 10, color: Colors.blue[600]))),
            ],
          ]),
          trailing: FilledButton.tonal(onPressed: () => _follow(code), child: const Text('关注')),
        );
      },
    );
  }
}
