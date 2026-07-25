import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/plan_api.dart';
import '../models/operation_plan.dart';
import 'stock_detail_page.dart';

/// 每日操作计划页
class OperationPlanPage extends ConsumerStatefulWidget {
  const OperationPlanPage({super.key});

  @override
  ConsumerState<OperationPlanPage> createState() => _OperationPlanPageState();
}

class _OperationPlanPageState extends ConsumerState<OperationPlanPage> {
  final _api = PlanApi();
  final _scrollController = ScrollController();

  List<DailyOperationPlan> _plans = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _statusFilter;
  bool _showTodayOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

    final result = await _api.getList(
      page: _page,
      pageSize: 20,
      status: _statusFilter,
      planDate: _showTodayOnly ? _todayDate() : null,
    );

    if (result != null && mounted) {
      setState(() {
        _plans = result.list;
        _hasMore = _page < result.totalPages;
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;

    final result = await _api.getList(
      page: _page,
      pageSize: 20,
      status: _statusFilter,
      planDate: _showTodayOnly ? _todayDate() : null,
    );

    if (result != null && mounted) {
      setState(() {
        _plans.addAll(result.list);
        _hasMore = _page < result.totalPages;
        _loadingMore = false;
      });
    } else {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _setStatusFilter(String? status) {
    setState(() => _statusFilter = status);
    _loadData();
  }

  Future<void> _deletePlan(DailyOperationPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${plan.stockName} (${plan.planDate}) 的操作计划吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _api.delete(plan.id);
      if (ok && mounted) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }

  Future<void> _changeStatus(DailyOperationPlan plan, String newStatus) async {
    final ok = await _api.updateStatus(plan.id, newStatus);
    if (ok && mounted) {
      _loadData();
    }
  }

  void _showPlanDetail(DailyOperationPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlanDetailPage(plan: plan, api: _api, onChanged: _loadData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('每日操作计划'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showTodayOnly ? Icons.calendar_view_day : Icons.calendar_month),
            tooltip: '仅今日',
            onPressed: () {
              setState(() => _showTodayOnly = !_showTodayOnly);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 状态筛选
                  SliverToBoxAdapter(child: _buildFilterBar(theme)),
                  // 计划列表
                  if (_plans.isEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text('暂无操作计划', style: TextStyle(color: theme.disabledColor)),
                              const SizedBox(height: 4),
                              Text('点击右下角 + 创建', style: TextStyle(color: theme.disabledColor, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildPlanCard(_plans[index], theme),
                        childCount: _plans.length,
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
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _PlanEditPage(api: _api, onSaved: _loadData),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    const statuses = <String?>{null, 'pending', 'executing', 'completed', 'expired'};
    const labels = <String>{'全部', '待执行', '执行中', '已完成', '已过期'};
    final statusList = statuses.toList();
    final labelList = labels.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(statusList.length, (i) {
            final selected = _statusFilter == statusList[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labelList[i], style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (_) => _setStatusFilter(statusList[i]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPlanCard(DailyOperationPlan plan, ThemeData theme) {
    final statusColor = _statusColor(plan.status);
    // Get stock initial
    final initial = plan.stockName.isNotEmpty ? plan.stockName[0] : '?';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPlanDetail(plan),
        onLongPress: () => _showPlanActions(plan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading icon with stock initial
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: date + status
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: theme.disabledColor),
                        const SizedBox(width: 4),
                        Text(plan.planDate, style: TextStyle(color: theme.disabledColor, fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            plan.statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Stock name + code
                    Row(
                      children: [
                        Text(plan.stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(plan.stockCode, style: TextStyle(color: theme.disabledColor, fontSize: 12)),
                      ],
                    ),
                    // Summary
                    if (plan.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        plan.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.disabledColor, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlanActions(DailyOperationPlan plan) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(ctx);
                _showPlanDetail(plan);
              },
            ),
            if (plan.status == 'pending')
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.orange),
                title: const Text('开始执行'),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeStatus(plan, 'executing');
                },
              ),
            if (plan.status == 'executing')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('标记完成'),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeStatus(plan, 'completed');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(ctx);
                _deletePlan(plan);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'executing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// 操作计划详情页
class _PlanDetailPage extends StatelessWidget {
  final DailyOperationPlan plan;
  final PlanApi api;
  final VoidCallback onChanged;

  const _PlanDetailPage({
    required this.plan,
    required this.api,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${plan.stockName} 计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: '查看行情',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockDetailPage.fromCode(plan.stockCode, plan.stockName),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final ok = await api.delete(plan.id);
                if (ok && context.mounted) {
                  onChanged();
                  Navigator.pop(context);
                }
              } else if (value == 'executing' || value == 'completed') {
                await api.updateStatus(plan.id, value);
                if (context.mounted) onChanged();
              }
            },
            itemBuilder: (_) => [
              if (plan.status == 'pending')
                const PopupMenuItem(value: 'executing', child: Text('开始执行')),
              if (plan.status == 'executing')
                const PopupMenuItem(value: 'completed', child: Text('标记完成')),
              const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息
            _buildSection(theme, '基本信息', [
              _buildInfoRow('日期', plan.planDate),
              _buildInfoRow('股票', '${plan.stockName} (${plan.stockCode})'),
              _buildInfoRow('状态', plan.statusLabel),
            ]),
            if (plan.summary.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(theme, '一句话总结', [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(plan.summary, style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ]),
            ],
            if (plan.overallJudgment.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(theme, '总体判断', [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(plan.overallJudgment, style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ]),
            ],
            if (plan.riskWarning.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(theme, '风险提示', [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(plan.riskWarning,
                            style: TextStyle(fontSize: 15, height: 1.4, color: Colors.orange[800])),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
            if (plan.scenarioList.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(theme, '情景方案 (${plan.scenarioList.length})', [
                ...plan.scenarioList.map((s) => Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            _buildInfoRow('条件', s.condition),
                            _buildInfoRow('操作', s.action),
                            if (s.position.isNotEmpty) _buildInfoRow('仓位', s.position),
                            if (s.buyPriceRange.isNotEmpty) _buildInfoRow('买入区间', s.buyPriceRange),
                            if (s.stopLossPrice.isNotEmpty) _buildInfoRow('止损价', s.stopLossPrice),
                          ],
                        ),
                      ),
                    )),
              ]),
            ],
            if (plan.remarks.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(theme, '备注', [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(plan.remarks, style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// 创建/编辑操作计划
class _PlanEditPage extends StatefulWidget {
  final PlanApi api;
  final VoidCallback onSaved;

  const _PlanEditPage({required this.api, required this.onSaved});

  @override
  State<_PlanEditPage> createState() => _PlanEditPageState();
}

class _PlanEditPageState extends State<_PlanEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _stockCodeCtrl = TextEditingController();
  final _stockNameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _judgmentCtrl = TextEditingController();
  final _riskCtrl = TextEditingController();
  String _planDate = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _planDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stockCodeCtrl.dispose();
    _stockNameCtrl.dispose();
    _summaryCtrl.dispose();
    _judgmentCtrl.dispose();
    _riskCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final plan = DailyOperationPlan(
      planDate: _planDate,
      stockCode: _stockCodeCtrl.text.trim(),
      stockName: _stockNameCtrl.text.trim(),
      overallJudgment: _judgmentCtrl.text.trim(),
      summary: _summaryCtrl.text.trim(),
      riskWarning: _riskCtrl.text.trim(),
    );

    final ok = await widget.api.save(plan);
    if (ok && mounted) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建操作计划'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: '计划日期', prefixIcon: Icon(Icons.calendar_today)),
              readOnly: true,
              controller: TextEditingController(text: _planDate),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() {
                    _planDate =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockCodeCtrl,
              decoration: const InputDecoration(labelText: '股票代码', prefixIcon: Icon(Icons.tag)),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入股票代码' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockNameCtrl,
              decoration: const InputDecoration(labelText: '股票名称', prefixIcon: Icon(Icons.business)),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入股票名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _summaryCtrl,
              decoration: const InputDecoration(labelText: '一句话总结（可选）', prefixIcon: Icon(Icons.short_text)),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _judgmentCtrl,
              decoration: const InputDecoration(
                labelText: '总体判断（可选）',
                prefixIcon: Icon(Icons.assessment),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _riskCtrl,
              decoration: const InputDecoration(
                labelText: '风险提示（可选）',
                prefixIcon: Icon(Icons.warning_amber),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
