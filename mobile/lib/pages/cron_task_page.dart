import 'package:flutter/material.dart';
import '../api/cron_task_api.dart';

/// 定时任务管理页面
class CronTaskPage extends StatefulWidget {
  const CronTaskPage({super.key});

  @override
  State<CronTaskPage> createState() => _CronTaskPageState();
}

class _CronTaskPageState extends State<CronTaskPage> {
  final _api = CronTaskApi();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<dynamic> _tasks = [];
  int _total = 0;
  int _page = 1;
  final int _pageSize = 20;
  String _keyword = '';
  final String _filterType = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getTaskList(
        page: _page,
        pageSize: _pageSize,
        keyword: _keyword,
        taskType: _filterType,
      );
      if (!mounted) return;
      setState(() {
        _tasks = result['data'] as List<dynamic>? ?? [];
        _total = result['total'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleEnable(dynamic task) async {
    final id = task['id'] as int? ?? 0;
    final enable = task['enable'] as bool? ?? false;
    final ok = await _api.enableTask(id, !enable);
    if (ok) _loadTasks();
  }

  Future<void> _deleteTask(int id) async {
    final ok = await _api.deleteTask(id);
    if (ok) _loadTasks();
  }

  void _showCreateDialog({Map<String, dynamic>? editTask}) {
    final isEdit = editTask != null;
    final nameCtrl = TextEditingController(text: editTask?['name'] ?? '');
    final cronCtrl = TextEditingController(text: editTask?['cronExpr'] ?? '');
    final typeCtrl = TextEditingController(text: editTask?['taskType'] ?? '');
    final targetCtrl = TextEditingController(text: editTask?['target'] ?? '');
    final descCtrl = TextEditingController(text: editTask?['description'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? '编辑任务' : '新建任务'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '任务名称')),
              TextField(controller: cronCtrl, decoration: const InputDecoration(labelText: 'Cron 表达式', hintText: '0 30 9 * * *')),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: '任务类型', hintText: 'stock_analysis / market_analysis')),
              TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: '目标', hintText: '股票代码等')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '备注'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final task = {
                if (isEdit) 'id': editTask['id'],
                'name': nameCtrl.text,
                'cronExpr': cronCtrl.text,
                'taskType': typeCtrl.text,
                'target': targetCtrl.text,
                'description': descCtrl.text,
                'enable': editTask?['enable'] ?? true,
              };
              final ok = isEdit ? await _api.updateTask(task) : await _api.createTask(task);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (ok) _loadTasks();
            },
            child: Text(isEdit ? '保存' : '创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定时任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(),
            tooltip: '新建任务',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索任务名称...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _keyword = '';
                          _loadTasks();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onSubmitted: (v) {
                _keyword = v;
                _page = 1;
                _loadTasks();
              },
            ),
          ),
          const SizedBox(height: 8),
          // 状态摘要
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('共 $_total 个任务', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 任务列表
          Expanded(child: _buildTaskList()),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('暂无定时任务', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index] as Map<String, dynamic>;
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final id = task['id'] as int? ?? 0;
    final name = task['name'] as String? ?? '';
    final taskType = task['taskType'] as String? ?? '';
    final cronExpr = task['cronExpr'] as String? ?? '';
    final enable = task['enable'] as bool? ?? false;
    final description = task['description'] as String? ?? '';
    final target = task['target'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enable ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                // 启用/禁用切换
                Switch(
                  value: enable,
                  onChanged: (_) => _toggleEnable(task),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTag(taskType, Colors.blue),
                const SizedBox(width: 6),
                _buildTag(cronExpr, Colors.teal),
              ],
            ),
            if (target.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('目标: $target', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  onPressed: () async {
                    await _api.executeTask(id);
                    _loadTasks();
                  },
                  tooltip: '立即执行',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showCreateDialog(editTask: task),
                  tooltip: '编辑',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _deleteTask(id),
                  tooltip: '删除',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.red[300],
                ),
              ],
            ),
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
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
