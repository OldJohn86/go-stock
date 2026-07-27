import 'package:flutter/material.dart';
import '../api/tdx_api.dart';

/// TDX 深度数据页面
class TdxDeepDataPage extends StatefulWidget {
  final String? initialCode;

  const TdxDeepDataPage({super.key, this.initialCode});

  @override
  State<TdxDeepDataPage> createState() => _TdxDeepDataPageState();
}

class _TdxDeepDataPageState extends State<TdxDeepDataPage>
    with SingleTickerProviderStateMixin {
  final _api = TdxApi();
  final _codeController = TextEditingController();

  late TabController _tabController;

  // 数据状态
  Map<String, dynamic> _minuteTimeData = {};
  Map<String, dynamic> _companyInfo = {};
  Map<String, dynamic> _financeInfo = {};
  List<dynamic> _transactions = [];
  List<dynamic> _callAuction = [];
  List<dynamic> _symbolBoards = [];
  List<dynamic> _xdxrInfo = [];
  Map<String, dynamic> _chipDistribution = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
      _loadAllData(widget.initialCode!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData(String code) async {
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 并发加载所有数据
      final results = await Future.wait([
        _api.getMinuteTime(code),
        _api.getCompanyInfo(code),
        _api.getFinanceInfo(code),
        _api.getTransactions(code),
        _api.getCallAuction(code),
        _api.getSymbolBoards(code),
        _api.getXDXRInfo(code),
        _api.getChipDistribution(code),
      ]);

      if (!mounted) return;
      setState(() {
        _minuteTimeData = results[0] as Map<String, dynamic>;
        _companyInfo = results[1] as Map<String, dynamic>;
        _financeInfo = results[2] as Map<String, dynamic>;
        _transactions = results[3] as List<dynamic>;
        _callAuction = results[4] as List<dynamic>;
        _symbolBoards = results[5] as List<dynamic>;
        _xdxrInfo = results[6] as List<dynamic>;
        _chipDistribution = results[7] as Map<String, dynamic>;
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
        title: const Text('TDX 深度数据'),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (value) => _loadAllData(value.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : () => _loadAllData(_codeController.text.trim()),
                  child: const Text('查询'),
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
                onPressed: () => _loadAllData(_codeController.text.trim()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final hasData = _companyInfo.isNotEmpty ||
        _transactions.isNotEmpty ||
        _symbolBoards.isNotEmpty ||
        _chipDistribution.isNotEmpty;

    if (!hasData && _codeController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('输入股票代码查看深度数据', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '分时成交'),
            Tab(text: 'F10资料'),
            Tab(text: '所属板块'),
            Tab(text: '财务/除权'),
            Tab(text: '筹码分布'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionTab(),
              _buildF10Tab(),
              _buildBoardTab(),
              _buildFinanceTab(),
              _buildChipDistributionTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ============ 分时成交 Tab ============
  Widget _buildTransactionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分时图数据概要
          if (_minuteTimeData.isNotEmpty) ...[
            _buildSectionTitle('分时图数据'),
            _buildJsonCard(_minuteTimeData),
            const SizedBox(height: 12),
          ],
          // 集合竞价
          if (_callAuction.isNotEmpty) ...[
            _buildSectionTitle('集合竞价 (最多500条)'),
            _buildTransactionTable(_callAuction),
            const SizedBox(height: 12),
          ],
          // 分笔成交
          if (_transactions.isNotEmpty) ...[
            _buildSectionTitle('分笔成交 (最多500条)'),
            _buildTransactionTable(_transactions),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTable(List<dynamic> items) {
    if (items.isEmpty) return const Text('暂无数据', style: TextStyle(color: Colors.grey));
    // 取前50条显示
    final display = items.length > 50 ? items.sublist(0, 50) : items;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('共 ${items.length} 条，显示前 ${display.length} 条',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(),
            ...display.map((item) {
              final map = item is Map<String, dynamic> ? item : {};
              final time = map['time'] ?? map['Time'] ?? '';
              final price = map['price'] ?? map['Price'] ?? '';
              final volume = map['volume'] ?? map['Vol'] ?? map['Volume'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text('$time', style: const TextStyle(fontSize: 13))),
                    SizedBox(width: 80, child: Text('$price', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    Text('量: $volume', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ============ F10资料 Tab ============
  Widget _buildF10Tab() {
    if (_companyInfo.isEmpty) {
      return const Center(child: Text('暂无F10资料', style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _buildJsonCard(_companyInfo),
    );
  }

  // ============ 所属板块 Tab ============
  Widget _buildBoardTab() {
    if (_symbolBoards.isEmpty) {
      return const Center(child: Text('暂无板块数据', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _symbolBoards.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _symbolBoards[index];
        final map = item is Map<String, dynamic> ? item : {};
        // Try common field names
        final name = map['name'] ?? map['Name'] ?? map['boardName'] ?? map['BoardName'] ?? '';
        final code = map['code'] ?? map['Code'] ?? map['boardCode'] ?? '';
        final type = map['type'] ?? map['Type'] ?? map['boardType'] ?? '';
        return ListTile(
          dense: true,
          title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('代码: $code  类型: $type', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        );
      },
    );
  }

  // ============ 财务/除权 Tab ============
  Widget _buildFinanceTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_financeInfo.isNotEmpty) ...[
          _buildSectionTitle('财务数据'),
          _buildJsonCard(_financeInfo),
          const SizedBox(height: 16),
        ],
        if (_xdxrInfo.isNotEmpty) ...[
          _buildSectionTitle('除权除息信息'),
          _buildXdxrList(_xdxrInfo),
        ],
        if (_financeInfo.isEmpty && _xdxrInfo.isEmpty)
          const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey))),
      ],
    );
  }

  Widget _buildXdxrList(List<dynamic> items) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final map = item is Map<String, dynamic> ? item : {};
          final date = map['date'] ?? map['Date'] ?? map['exDate'] ?? '';
          final desc = map['description'] ?? map['Desc'] ?? map['note'] ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$date', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (desc.toString().isNotEmpty)
                  Text('$desc', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============ 筹码分布 Tab ============
  Widget _buildChipDistributionTab() {
    if (_chipDistribution.isEmpty) {
      return const Center(child: Text('暂无筹码分布数据', style: TextStyle(color: Colors.grey)));
    }
    final bins = _chipDistribution['bins'] ?? _chipDistribution['Bins'] ?? _chipDistribution['distribution'] ?? [];
    final stockCode = _chipDistribution['stockCode'] ?? _chipDistribution['StockCode'] ?? '';
    final avgCost = _chipDistribution['avgCost'] ?? _chipDistribution['AvgCost'] ?? '';
    final concentration = _chipDistribution['concentration'] ?? _chipDistribution['Concentration'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('筹码分布概览'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('股票: $stockCode'),
                  if (avgCost.toString().isNotEmpty) Text('平均成本: $avgCost'),
                  if (concentration.toString().isNotEmpty) Text('集中度: $concentration'),
                ],
              ),
            ),
          ),
          if (bins is List && bins.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionTitle('各价位筹码分布'),
            ...bins.take(80).map((bin) {
              final m = bin is Map<String, dynamic> ? bin : {};
              final price = m['price'] ?? m['Price'] ?? '';
              final ratio = m['ratio'] ?? m['Ratio'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text('$price', style: const TextStyle(fontSize: 13))),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (ratio is num ? ratio.toDouble() : double.tryParse('$ratio') ?? 0) / 100,
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    SizedBox(width: 40, child: Text('${(ratio is num ? ratio : 0).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12))),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ============ 辅助方法 ============
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildJsonCard(Map<String, dynamic> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList();
    // Limit display to prevent overflow
    final display = entries.length > 30 ? entries.sublist(0, 30) : entries;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: display.map((e) {
            var value = e.value;
            if (value is Map || value is List) {
              value = value.toString();
              if (value.length > 100) value = '${value.substring(0, 100)}...';
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: Text('${e.key}:', style: const TextStyle(fontSize: 13, color: Colors.grey))),
                  Expanded(child: Text('$value', style: const TextStyle(fontSize: 13))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
