import 'package:flutter/material.dart';
import '../api/mcp_server_api.dart';

/// MCP 服务器管理页面
class McpServerPage extends StatefulWidget {
  const McpServerPage({super.key});

  @override
  State<McpServerPage> createState() => _McpServerPageState();
}

class _McpServerPageState extends State<McpServerPage> {
  final _api = McpServerApi();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<dynamic> _servers = [];
  int _total = 0;
  int _page = 1;
  String _keyword = '';
  final String _filterStatus = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getServerList(page: _page, keyword: _keyword, status: _filterStatus);
      if (!mounted) return;
      setState(() {
        _servers = result['data'] as List<dynamic>? ?? [];
        _total = result['total'] as int? ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleEnable(dynamic server) async {
    final id = server['id'] as int? ?? 0;
    final enable = server['enable'] as bool? ?? false;
    if (await _api.enableServer(id, !enable)) _loadServers();
  }

  Future<void> _deleteServer(int id) async {
    if (await _api.deleteServer(id)) _loadServers();
  }

  Future<void> _testConnection(int id) async {
    setState(() => _testing = true);
    final result = await _api.testConnection(id);
    if (!mounted) return;
    setState(() => _testing = false);
    final message = result['message'] as String? ?? '测试完成';
    _showToast(message);
    _loadServers();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _showFormDialog({Map<String, dynamic>? edit}) {
    final isEdit = edit != null;
    final nameCtrl = TextEditingController(text: edit?['name'] ?? '');
    final urlCtrl = TextEditingController(text: edit?['url'] ?? '');
    final descCtrl = TextEditingController(text: edit?['description'] ?? '');
    final typeCtrl = TextEditingController(text: edit?['type'] ?? 'streamable-http');
    final headersCtrl = TextEditingController(text: edit?['headers'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? '编辑服务器' : '新建服务器'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称 *')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL', hintText: 'http://localhost:8080/sse')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述'), maxLines: 2),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: '类型', hintText: 'sse / streamable-http')),
              TextField(controller: headersCtrl, decoration: const InputDecoration(labelText: 'Headers (JSON)'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final server = <String, dynamic>{
                if (isEdit) 'id': edit['id'],
                'name': nameCtrl.text,
                'url': urlCtrl.text,
                'description': descCtrl.text,
                'type': typeCtrl.text.isEmpty ? 'streamable-http' : typeCtrl.text,
                'headers': headersCtrl.text,
              };
              final ok = isEdit ? await _api.updateServer(server) : await _api.createServer(server);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (ok) _loadServers();
            },
            child: Text(isEdit ? '保存' : '创建'),
          ),
        ],
      ),
    );
  }

  void _showToolsDialog(dynamic server) async {
    final id = server['id'] as int? ?? 0;
    final name = server['name'] as String? ?? '';
    final tools = await _api.getTools(id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name 的工具列表'),
        content: SizedBox(
          width: double.maxFinite,
          child: tools.isEmpty
              ? const Text('暂无工具，请先测试连接', style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: tools.length,
                  itemBuilder: (_, i) {
                    final t = tools[i] as Map<String, dynamic>;
                    final toolName = t['toolName'] as String? ?? '';
                    final toolDesc = t['description'] as String? ?? '';
                    return ListTile(
                      dense: true,
                      title: Text(toolName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: toolDesc.isNotEmpty ? Text(toolDesc, style: const TextStyle(fontSize: 12)) : null,
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP 服务管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showFormDialog(), tooltip: '新建'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索服务器...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _keyword = ''; _loadServers(); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onSubmitted: (v) { _keyword = v; _page = 1; _loadServers(); },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('共 $_total 个服务器', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                _testing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const SizedBox.shrink(),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('暂无 MCP 服务器', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加服务器'),
              onPressed: () => _showFormDialog(),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadServers,
      child: ListView.builder(
        itemCount: _servers.length,
        itemBuilder: (_, i) => _buildCard(_servers[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> s) {
    final id = s['id'] as int? ?? 0;
    final name = s['name'] as String? ?? '';
    final url = s['url'] as String? ?? '';
    final desc = s['description'] as String? ?? '';
    final enable = s['enable'] as bool? ?? false;
    final status = s['status'] as String? ?? '';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'available':
        statusColor = Colors.green;
        statusText = '可用';
      case 'testing':
        statusColor = Colors.orange;
        statusText = '测试中';
      case 'unavailable':
        statusColor = Colors.red;
        statusText = '不可用';
      default:
        statusColor = Colors.grey;
        statusText = '未连接';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: enable ? Colors.green : Colors.grey)),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor)),
                ),
                const SizedBox(width: 4),
                Switch(value: enable, onChanged: (_) => _toggleEnable(s), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ],
            ),
            if (url.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(url, style: const TextStyle(fontSize: 12, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionBtn(Icons.cable, '测试', () => _testConnection(id)),
                const SizedBox(width: 12),
                _actionBtn(Icons.build_outlined, '工具', () => _showToolsDialog(s)),
                const SizedBox(width: 12),
                _actionBtn(Icons.edit, '编辑', () => _showFormDialog(edit: s)),
                const SizedBox(width: 12),
                _actionBtn(Icons.delete_outline, '删除', () => _deleteServer(id), danger: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: danger ? Colors.red[300] : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 11, color: danger ? Colors.red[300] : Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
