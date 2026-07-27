import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/stock_api.dart';
import '../models/stock_info.dart';

/// 价格预警设置页
class AlertSettingPage extends StatefulWidget {
  const AlertSettingPage({super.key});

  @override
  State<AlertSettingPage> createState() => _AlertSettingPageState();
}

class _AlertSettingPageState extends State<AlertSettingPage> {
  final _api = ApiClient();

  List<Map<String, dynamic>> _alarmList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarmList();
  }

  Future<void> _loadAlarmList() async {
    setState(() => _loading = true);
    final resp = await _api.get('/alert/list');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      if (mounted) {
        setState(() {
          _alarmList = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAlarm() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddAlarmSheet(
        onSaved: _loadAlarmList,
      ),
    );
  }

  Future<void> _editAlarm(Map<String, dynamic> item) async {
    final stockCode = item['stock_code'] as String? ?? '';
    final stockName = item['name'] as String? ?? item['Name'] as String? ?? '';
    final currentPercent = (item['alarm_change_percent'] as num?)?.toDouble() ?? 0;
    final currentPrice = (item['alarm_price'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditAlarmSheet(
        stockCode: stockCode,
        stockName: stockName,
        currentPercent: currentPercent,
        currentPrice: currentPrice,
        onSaved: _loadAlarmList,
      ),
    );
  }

  String _formatAlarmDescription(Map<String, dynamic> item) {
    final percent = (item['alarm_change_percent'] as num?)?.toDouble() ?? 0;
    final price = (item['alarm_price'] as num?)?.toDouble() ?? 0;
    final parts = <String>[];
    if (percent > 0) {
      parts.add('涨跌 $percent%');
    }
    if (price > 0) {
      parts.add('触发 ¥$price');
    }
    return parts.isEmpty ? '未设置预警' : parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('盘中预警'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加预警',
            onPressed: _addAlarm,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alarmList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text('暂无预警设置', style: TextStyle(color: theme.disabledColor)),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _addAlarm,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加预警'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlarmList,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _alarmList.length,
                    itemBuilder: (_, i) {
                      final item = _alarmList[i];
                      final stockCode = item['stock_code'] as String? ?? item['StockCode'] as String? ?? '';
                      final stockName = item['name'] as String? ?? item['Name'] as String? ?? '';
                      final changePercent = (item['change_percent'] as num?)?.toDouble() ?? 0;
                      final currentPrice = (item['price'] as num?)?.toDouble() ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _editAlarm(item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // 股票信息
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            stockName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            stockCode,
                                            style: TextStyle(color: theme.disabledColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatAlarmDescription(item),
                                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 当前价格
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currentPrice > 0 ? currentPrice.toStringAsFixed(2) : '-',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: changePercent >= 0 ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// 添加预警底部表单
class _AddAlarmSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddAlarmSheet({required this.onSaved});

  @override
  State<_AddAlarmSheet> createState() => _AddAlarmSheetState();
}

class _AddAlarmSheetState extends State<_AddAlarmSheet> {
  final _stockCodeCtrl = TextEditingController();
  final _stockNameCtrl = TextEditingController();
  final _percentCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _saving = false;

  List<StockRealTime> _searchResults = [];

  @override
  void dispose() {
    _stockCodeCtrl.dispose();
    _stockNameCtrl.dispose();
    _percentCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchStock(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await StockApi().getStockList(name: keyword, pageSize: 10);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      // ignore search errors
    }
  }

  void _selectStock(StockRealTime stock) {
    _stockCodeCtrl.text = stock.stockCode;
    _stockNameCtrl.text = stock.stockName;
    setState(() => _searchResults = []);
  }

  Future<void> _save() async {
    final stockCode = _stockCodeCtrl.text.trim();
    final percent = double.tryParse(_percentCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (stockCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入或搜索股票代码')),
      );
      return;
    }
    if (percent <= 0 && price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请设置涨跌幅或提醒价格') ),
      );
      return;
    }

    setState(() => _saving = true);
    final resp = await ApiClient().post('/alert/setting', data: {
      'stockCode': stockCode,
      'alarmChangePercent': percent,
      'alarmPrice': price,
    });
    setState(() => _saving = false);

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.isSuccess ? '预警设置成功' : '设置失败')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Text('添加价格预警', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stockCodeCtrl,
            decoration: InputDecoration(
              hintText: '搜索股票代码',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            onChanged: _searchStock,
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
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
                    onTap: () => _selectStock(s),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 12),
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
          Text('涨跌幅阈值 (%)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _percentCtrl,
            decoration: InputDecoration(
              hintText: '如：3 表示涨跌超过3%时提醒',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Text('提醒价格', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _priceCtrl,
            decoration: InputDecoration(
              hintText: '如：10.5 表示价格触达10.5时提醒',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('设置预警', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 编辑预警底部表单
class _EditAlarmSheet extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final double currentPercent;
  final double currentPrice;
  final VoidCallback onSaved;

  const _EditAlarmSheet({
    required this.stockCode,
    required this.stockName,
    required this.currentPercent,
    required this.currentPrice,
    required this.onSaved,
  });

  @override
  State<_EditAlarmSheet> createState() => _EditAlarmSheetState();
}

class _EditAlarmSheetState extends State<_EditAlarmSheet> {
  late final TextEditingController _percentCtrl;
  late final TextEditingController _priceCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _percentCtrl = TextEditingController(
      text: widget.currentPercent > 0 ? widget.currentPercent.toStringAsFixed(1) : '',
    );
    _priceCtrl = TextEditingController(
      text: widget.currentPrice > 0 ? widget.currentPrice.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _percentCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final percent = double.tryParse(_percentCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    final resp = await ApiClient().post('/alert/setting', data: {
      'stockCode': widget.stockCode,
      'alarmChangePercent': percent,
      'alarmPrice': price,
    });
    setState(() => _saving = false);

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.isSuccess ? '预警已更新' : '设置失败')),
    );
  }

  Future<void> _clearAlarm() async {
    setState(() => _saving = true);
    final resp = await ApiClient().post('/alert/setting', data: {
      'stockCode': widget.stockCode,
      'alarmChangePercent': 0,
      'alarmPrice': 0,
    });
    setState(() => _saving = false);

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.isSuccess ? '预警已清除' : '操作失败')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Text('编辑预警', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${widget.stockName} (${widget.stockCode})', style: TextStyle(color: theme.disabledColor)),
          const SizedBox(height: 16),
          Text('涨跌幅阈值 (%)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _percentCtrl,
            decoration: InputDecoration(
              hintText: '如：3 表示涨跌超过3%时提醒',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Text('提醒价格', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _priceCtrl,
            decoration: InputDecoration(
              hintText: '如：10.5 表示价格触达10.5时提醒',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存预警', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: _saving ? null : _clearAlarm,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('清除此预警'),
            ),
          ),
        ],
      ),
    );
  }
}
