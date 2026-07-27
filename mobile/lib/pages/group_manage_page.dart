import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/group_provider.dart';
import 'group_stock_page.dart';

/// 分组管理页 — 增删改 + 拖拽排序
class GroupManagePage extends ConsumerWidget {
  const GroupManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('分组管理')),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '还没有创建分组',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击下方按钮创建第一个分组',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: groups.length,
              onReorderItem: (oldIndex, newIndex) async {
                final correctedNewIndex =
                    oldIndex < newIndex ? newIndex - 1 : newIndex;
                final newList = List<GroupModel>.from(groups);
                final item = newList.removeAt(oldIndex);
                newList.insert(correctedNewIndex, item);
                await ref
                    .read(groupListProvider.notifier)
                    .reorder(newList);
              },
              itemBuilder: (context, index) {
                final group = groups[index];
                final groupColors = [
                  colorScheme.primary,
                  Colors.teal,
                  Colors.orange,
                  Colors.purple,
                  Colors.indigo,
                  Colors.pink,
                  Colors.cyan,
                  Colors.brown,
                ];
                final colorIndex = group.id % groupColors.length;
                final groupColor = groupColors[colorIndex];

                return Card(
                  key: ValueKey('group_${group.id}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: groupColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GroupStockPage(groupId: group.id, groupName: group.name),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          // 分组图标
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: groupColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.folder,
                              color: groupColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 分组名称 + 股票数量
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${group.stockCount} 只股票',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 编辑 / 删除
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _iconBtn(context, Icons.edit_outlined, '编辑', () =>
                                  _showEditDialog(context, ref, group)),
                              const SizedBox(width: 4),
                              _iconBtn(context, Icons.delete_outline, '删除', () =>
                                  _showDeleteConfirm(context, ref, group)),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.drag_handle,
                                color: Theme.of(context).disabledColor,
                                size: 20,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建分组'),
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '请输入分组名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final ok = await ref
                  .read(groupListProvider.notifier)
                  .addGroup(name);
              if (ok && context.mounted) Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, GroupModel group) {
    final ctrl = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑分组'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '请输入分组名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final ok = await ref
                  .read(groupListProvider.notifier)
                  .updateGroup(group.id, name);
              if (ok && context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, GroupModel group) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定删除「${group.name}」吗？分组内的股票不会被取消关注。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              final ok = await ref
                  .read(groupListProvider.notifier)
                  .deleteGroup(group.id);
              if (ok && context.mounted) Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
