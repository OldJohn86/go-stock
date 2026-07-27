import 'package:flutter/material.dart';
import '../api/kline_pattern_api.dart';

/// K线形态识别页面
class KLinePatternPage extends StatefulWidget {
  final String? initialCode;

  const KLinePatternPage({super.key, this.initialCode});

  @override
  State<KLinePatternPage> createState() => _KLinePatternPageState();
}

class _KLinePatternPageState extends State<KLinePatternPage> {
  final _api = KLinePatternApi();
  final _codeController = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _analysisResult;
  Map<String, dynamic>? _summaryResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
      _fetchData(widget.initialCode!);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchData(String code) async {
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.analyzePattern(code),
        _api.getPatternSummary(code),
      ]);

      if (!mounted) return;
      setState(() {
        _analysisResult = results[0] as Map<String, dynamic>?;
        _summaryResult = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '请求失败: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('K线形态识别'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: '输入股票代码，如 600519.SH',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (value) => _fetchData(value.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : () => _fetchData(_codeController.text.trim()),
                  child: const Text('分析'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchData(_codeController.text.trim()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_analysisResult == null || _analysisResult!.isEmpty) {
      if (_codeController.text.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('输入股票代码分析K线形态', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        );
      }
      return const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey)));
    }

    final patterns = _analysisResult!['patterns'] as List<dynamic>? ?? [];
    final summary = _analysisResult!['summary'] as String? ?? '';
    final stockCode = _analysisResult!['stockCode'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 趋势概览卡片
        if (_summaryResult != null) _buildSummaryCard(),
        const SizedBox(height: 12),

        // 形态统计
        _buildSectionHeader('形态统计'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('股票: $stockCode', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(summary, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 形态列表
        _buildSectionHeader('识别到的形态 (${patterns.length}个)'),
        if (patterns.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('未识别到经典K线形态', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...patterns.map((p) {
            final map = p is Map<String, dynamic> ? p : <String, dynamic>{};
            return _buildPatternCard(map);
          }),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final s = _summaryResult!;
    final trend = s['trend'] as String? ?? '';
    final latestClose = s['latestClose'] as String? ?? '';
    final ma5 = _formatPrice(s['ma5']);
    final ma10 = _formatPrice(s['ma10']);
    final ma20 = _formatPrice(s['ma20']);

    final trendColor = trend.contains('多头') ? Colors.red : (trend.contains('空头') ? Colors.green : Colors.grey);

    return Card(
      color: trendColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('趋势: ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(trend, style: TextStyle(color: trendColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('最新收盘: $latestClose'),
            Text('MA5: $ma5 | MA10: $ma10 | MA20: $ma20'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPatternCard(Map<String, dynamic> map) {
    final date = map['date'] as String? ?? '';
    final pattern = map['pattern'] as String? ?? '';
    final direction = map['direction'] as String? ?? '';
    final score = (map['score'] as num?)?.toDouble() ?? 0;
    final detail = map['detail'] as String? ?? '';

    Color dirColor;
    IconData dirIcon;
    String dirLabel;
    switch (direction) {
      case 'bullish':
        dirColor = Colors.red;
        dirIcon = Icons.arrow_upward;
        dirLabel = '看涨';
      case 'bearish':
        dirColor = Colors.green;
        dirIcon = Icons.arrow_downward;
        dirLabel = '看跌';
      default:
        dirColor = Colors.grey;
        dirIcon = Icons.remove;
        dirLabel = '中性';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(dirIcon, color: dirColor, size: 20),
                const SizedBox(width: 6),
                Text(pattern, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTag(dirLabel, dirColor),
                const SizedBox(width: 8),
                _buildTag('${(score * 100).toStringAsFixed(0)}%置信度', Colors.blue),
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  String _formatPrice(dynamic value) {
    if (value == null) return '--';
    if (value is num) return value.toStringAsFixed(2);
    return value.toString();
  }
}
