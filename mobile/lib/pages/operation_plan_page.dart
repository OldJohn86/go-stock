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
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    _page = 1;
    _hasMore = true;

    try {
      final result = await _api.getList(
        page: _page,
        pageSize: 20,
        status: _statusFilter,
        planDate: _showTodayOnly ? _todayDate() : null,
      );

      if (mounted) {
        if (result != null) {
          setState(() {
            _plans = result.list;
            _hasMore = _page < result.totalPages;
            _loading = false;
          });
        } else {
          setState(() {
            _error = '加载数据失败，请下拉刷新重试';
            _loading = false;
          });
        }
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
        page: _page,
        pageSize: 20,
        status: _statusFilter,
        planDate: _showTodayOnly ? _todayDate() : null,
      );

      if (mounted) {
        if (result != null) {
          setState(() {
            _plans.addAll(result.list);
            _hasMore = _page < result.totalPages;
            _loadingMore = false;
          });
        } else {
          setState(() {
            _page--;
            _loadingMore = false;
          });
        }
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
        content: Text('确定删除 ${plan.stockName} (${plan.planDate}) 的操作计划吗？\n\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _api.delete(plan.id);
      if (ok && mounted) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除成功'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除失败'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _changeStatus(DailyOperationPlan plan, String newStatus) async {
    final ok = await _api.updateStatus(plan.id, newStatus);
    if (ok && mounted) {
      _loadData();
      if (mounted) {
        final statusLabel = DailyOperationPlan(
          planDate: plan.planDate,
          stockCode: plan.stockCode,
          stockName: plan.stockName,
          status: newStatus,
        ).statusLabel;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('状态已更新为「$statusLabel」'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('状态更新失败'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  void _showCreateEditDialog({DailyOperationPlan? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlanFormSheet(
        api: _api,
        existing: existing,
        onSaved: () {
          _loadData();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showStatusSelector(DailyOperationPlan plan) {
    final statuses = <String>['pending', 'executing', 'completed', 'expired'];
    final labels = <String>['待执行', '执行中', '已完成', '已过期'];
    final icons = <IconData>[
      Icons.schedule,
      Icons.play_circle_outline,
      Icons.check_circle_outline,
      Icons.timer_off_outlined,
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                '更新状态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
            ...List.generate(statuses.length, (i) {
              final isCurrent = plan.status == statuses[i];
              return ListTile(
                leading: Icon(
                  icons[i],
                  color: isCurrent ? _statusColor(statuses[i]) : null,
                ),
                title: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? _statusColor(statuses[i]) : null,
                  ),
                ),
                trailing: isCurrent ? const Icon(Icons.check, size: 18) : null,
                onTap: isCurrent
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _changeStatus(plan, statuses[i]);
                      },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Today filter toggle (was in AppBar actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    _showTodayOnly
                        ? Icons.calendar_view_day
                        : Icons.calendar_month,
                  ),
                  tooltip: '仅今日',
                  onPressed: () {
                    setState(() => _showTodayOnly = !_showTodayOnly);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            SizedBox(
              height: 320,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 56, color: theme.disabledColor),
                    const SizedBox(height: 16),
                    Text(
                      '暂无操作计划',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.disabledColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusFilter != null ? '当前筛选条件下无数据，点击下方按钮创建' : '点击右下角 + 创建',
                      style: TextStyle(color: theme.disabledColor, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => _showCreateEditDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('创建计划'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildFilterBar(theme)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPlanCard(_plans[index], theme),
              childCount: _plans.length,
            ),
          ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingMore
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Center(
                        child: Text(
                          '上拉加载更多',
                          style: TextStyle(color: theme.disabledColor, fontSize: 13),
                        ),
                      ),
              ),
            )
          else if (_plans.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '— 已加载全部 ${_plans.length} 条 —',
                    style: TextStyle(color: theme.disabledColor, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
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
    final directionColor = _directionColor(plan.direction);
    final directionIcon = _directionIcon(plan.direction);
    final initial = plan.stockName.isNotEmpty ? plan.stockName[0] : '?';

    // Format numbers for display
    final priceText = plan.plannedPrice > 0 ? '¥${plan.plannedPrice.toStringAsFixed(2)}' : '';
    final qtyText = plan.plannedQuantity > 0 ? '${plan.plannedQuantity}股' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPlanDetail(plan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: leading + content
              Row(
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
                            Text(
                              plan.planDate,
                              style: TextStyle(color: theme.disabledColor, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Icon(directionIcon, size: 14, color: directionColor),
                            const SizedBox(width: 4),
                            Text(
                              plan.directionLabel,
                              style: TextStyle(
                                color: directionColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            // Status badge (tappable)
                            GestureDetector(
                              onTap: () => _showStatusSelector(plan),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      plan.statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down, size: 14, color: statusColor),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Stock name + code
                        Row(
                          children: [
                            Text(
                              plan.stockName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              plan.stockCode,
                              style: TextStyle(color: theme.disabledColor, fontSize: 12),
                            ),
                          ],
                        ),
                        // Price & quantity row
                        if (priceText.isNotEmpty || qtyText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (priceText.isNotEmpty) ...[
                                Icon(Icons.attach_money, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 2),
                                Text(
                                  priceText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                              if (priceText.isNotEmpty && qtyText.isNotEmpty)
                                const SizedBox(width: 12),
                              if (qtyText.isNotEmpty) ...[
                                Icon(Icons.inventory_2_outlined, size: 14, color: theme.disabledColor),
                                const SizedBox(width: 2),
                                Text(
                                  qtyText,
                                  style: TextStyle(fontSize: 13, color: theme.disabledColor),
                                ),
                              ],
                            ],
                          ),
                        ],
                        // Reason / summary
                        if (plan.reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            plan.reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ] else if (plan.summary.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            plan.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Action buttons row
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit button
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: '编辑',
                    color: theme.colorScheme.primary,
                    onTap: () => _showCreateEditDialog(existing: plan),
                  ),
                  const SizedBox(width: 4),
                  // Status button
                  _ActionButton(
                    icon: Icons.swap_horiz,
                    label: '状态',
                    color: statusColor,
                    onTap: () => _showStatusSelector(plan),
                  ),
                  const SizedBox(width: 4),
                  // Delete button
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: Colors.red[400]!,
                    onTap: () => _deletePlan(plan),
                  ),
                ],
              ),
            ],
          ),
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

  Color _directionColor(String direction) {
    switch (direction) {
      case 'buy':
        return Colors.green;
      case 'sell':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _directionIcon(String direction) {
    switch (direction) {
      case 'buy':
        return Icons.trending_up;
      case 'sell':
        return Icons.trending_down;
      default:
        return Icons.remove_circle_outline;
    }
  }
}

/// Small action button used on plan cards
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet form for creating or editing an operation plan
class _PlanFormSheet extends StatefulWidget {
  final PlanApi api;
  final DailyOperationPlan? existing;
  final VoidCallback onSaved;

  const _PlanFormSheet({
    required this.api,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _stockCodeCtrl = TextEditingController();
  final _stockNameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  late String _planDate;
  late String _direction;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (_isEdit) {
      final p = widget.existing!;
      _stockCodeCtrl.text = p.stockCode;
      _stockNameCtrl.text = p.stockName;
      _planDate = p.planDate;
      _direction = p.direction;
      _reasonCtrl.text = p.reason;
      if (p.plannedPrice > 0) {
        _priceCtrl.text = p.plannedPrice.toStringAsFixed(2);
      }
      if (p.plannedQuantity > 0) {
        _quantityCtrl.text = p.plannedQuantity.toString();
      }
    } else {
      _planDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _direction = 'buy';
    }
  }

  @override
  void dispose() {
    _stockCodeCtrl.dispose();
    _stockNameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _directionLabel(String dir) {
    switch (dir) {
      case 'buy':
        return '买入';
      case 'sell':
        return '卖出';
      case 'hold':
        return '持有';
      default:
        return dir;
    }
  }

  Color _directionColor(String dir) {
    switch (dir) {
      case 'buy':
        return Colors.green;
      case 'sell':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final plan = DailyOperationPlan(
      id: widget.existing?.id ?? 0,
      planDate: _planDate,
      stockCode: _stockCodeCtrl.text.trim(),
      stockName: _stockNameCtrl.text.trim(),
      direction: _direction,
      plannedPrice: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      plannedQuantity: int.tryParse(_quantityCtrl.text.trim()) ?? 0,
      reason: _reasonCtrl.text.trim(),
      overallJudgment: widget.existing?.overallJudgment ?? '',
      summary: widget.existing?.summary ?? '',
      riskWarning: widget.existing?.riskWarning ?? '',
      status: widget.existing?.status ?? 'pending',
    );

    final ok = await widget.api.save(plan);
    if (ok && mounted) {
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存成功'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _isEdit ? '编辑操作计划' : '新建操作计划',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    // Plan date
                    _buildDateField(theme),
                    const SizedBox(height: 16),
                    // Stock code
                    TextFormField(
                      controller: _stockCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: '股票代码',
                        hintText: '例如: 600000',
                        prefixIcon: Icon(Icons.tag),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? '请输入股票代码' : null,
                    ),
                    const SizedBox(height: 16),
                    // Stock name
                    TextFormField(
                      controller: _stockNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '股票名称',
                        hintText: '例如: 浦发银行',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? '请输入股票名称' : null,
                    ),
                    const SizedBox(height: 16),
                    // Direction dropdown
                    DropdownButtonFormField<String>(
                      key: ValueKey(_direction),
                      initialValue: _direction,
                      decoration: const InputDecoration(
                        labelText: '操作方向',
                        prefixIcon: Icon(Icons.swap_vert),
                        border: OutlineInputBorder(),
                      ),
                      items: ['buy', 'sell', 'hold'].map((dir) {
                        return DropdownMenuItem(
                          value: dir,
                          child: Row(
                            children: [
                              Icon(
                                dir == 'buy'
                                    ? Icons.trending_up
                                    : dir == 'sell'
                                        ? Icons.trending_down
                                        : Icons.remove_circle_outline,
                                size: 18,
                                color: _directionColor(dir),
                              ),
                              const SizedBox(width: 8),
                              Text(_directionLabel(dir)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _direction = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Price & quantity side by side
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            decoration: const InputDecoration(
                              labelText: '计划价格',
                              hintText: '价格',
                              prefixIcon: Icon(Icons.attach_money),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityCtrl,
                            decoration: const InputDecoration(
                              labelText: '计划数量',
                              hintText: '股数',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Reason (multi-line)
                    TextFormField(
                      controller: _reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: '操作理由',
                        hintText: '填写操作理由...',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEdit ? '保存修改' : '创建计划',
                                style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(ThemeData theme) {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: '计划日期',
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
      ),
      readOnly: true,
      controller: TextEditingController(text: _planDate),
      onTap: () async {
        final initial = DateTime.tryParse(_planDate) ?? DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: initial,
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
      validator: (v) => v == null || v.trim().isEmpty ? '请选择计划日期' : null,
    );
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
              _buildInfoRow('方向', plan.directionLabel),
              if (plan.plannedPrice > 0)
                _buildInfoRow('计划价格', '¥${plan.plannedPrice.toStringAsFixed(2)}'),
              if (plan.plannedQuantity > 0)
                _buildInfoRow('计划数量', '${plan.plannedQuantity}股'),
              _buildInfoRow('状态', plan.statusLabel),
            ]),
            if (plan.reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(theme, '操作理由', [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(plan.reason, style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ]),
            ],
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
