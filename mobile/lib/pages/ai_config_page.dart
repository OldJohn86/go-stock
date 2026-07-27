import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

/// AI 配置管理页（增删改 AI 厂商）
class AiConfigPage extends ConsumerStatefulWidget {
  const AiConfigPage({super.key});

  @override
  ConsumerState<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends ConsumerState<AiConfigPage> {
  final _client = ApiClient();
  List<Map<String, dynamic>> _configs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await _client.get('/settings/ai-configs');
      if (mounted) {
        if (resp.isSuccess && resp.data != null) {
          setState(() => _configs = List<Map<String, dynamic>>.from(resp.data));
        } else {
          setState(() => _error = resp.message);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _saveAll() async {
    final resp = await _client.post('/settings/ai-configs', data: _configs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.isSuccess ? '保存成功' : '保存失败: ${resp.message}'),
        behavior: SnackBarBehavior.floating,
      ));
      if (resp.isSuccess) _load();
    }
  }

  void _add() {
    setState(() => _configs.add({
      'name': '',
      'baseUrl': '',
      'apiKey': '',
      'modelName': '',
      'maxTokens': 4096,
      'temperature': 0.7,
      'timeOut': 60,
      'httpProxy': '',
      'httpProxyEnabled': false,
      'thinking': false,
    }));
  }

  void _remove(int index) {
    setState(() => _configs.removeAt(index));
    _saveAll();
  }

  void _edit(int index, String field, dynamic value) {
    setState(() => _configs[index][field] = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 配置管理'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _add, tooltip: '添加配置'),
          IconButton(icon: const Icon(Icons.save), onPressed: _configs.isEmpty ? null : _saveAll, tooltip: '保存'),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16), FilledButton.tonal(onPressed: _load, child: const Text('重试')),
      ]),
    );
    }    if (_configs.isEmpty) {
      return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.settings_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12), const Text('暂无 AI 配置'),
        const SizedBox(height: 16), FilledButton.tonal(onPressed: _add, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, size: 18), SizedBox(width: 4), Text('添加配置')])),
      ]),
    );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _configs.length,
        itemBuilder: (context, i) => _ConfigCard(
          config: _configs[i],
          index: i,
          colorScheme: colorScheme,
          onChanged: (field, value) => _edit(i, field, value),
          onDelete: () => _remove(i),
        ),
      ),
    );
  }
}

class _ConfigCard extends StatefulWidget {
  final Map<String, dynamic> config;
  final int index;
  final ColorScheme colorScheme;
  final void Function(String field, dynamic value) onChanged;
  final VoidCallback onDelete;

  const _ConfigCard({required this.config, required this.index, required this.colorScheme, required this.onChanged, required this.onDelete});

  @override
  State<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<_ConfigCard> {
  late TextEditingController _nameCtl;
  late TextEditingController _urlCtl;
  late TextEditingController _keyCtl;
  late TextEditingController _modelCtl;
  late TextEditingController _proxyCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.config['name'] as String? ?? '');
    _urlCtl = TextEditingController(text: widget.config['baseUrl'] as String? ?? '');
    _keyCtl = TextEditingController(text: widget.config['apiKey'] as String? ?? '');
    _modelCtl = TextEditingController(text: widget.config['modelName'] as String? ?? '');
    _proxyCtl = TextEditingController(text: widget.config['httpProxy'] as String? ?? '');
  }

  @override
  void didUpdateWidget(covariant _ConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config) {
      _nameCtl.text = widget.config['name'] as String? ?? '';
      _urlCtl.text = widget.config['baseUrl'] as String? ?? '';
      _keyCtl.text = widget.config['apiKey'] as String? ?? '';
      _modelCtl.text = widget.config['modelName'] as String? ?? '';
      _proxyCtl.text = widget.config['httpProxy'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _urlCtl.dispose();
    _keyCtl.dispose();
    _modelCtl.dispose();
    _proxyCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cfg = widget.config;
    final maxTokens = (cfg['maxTokens'] as num?)?.toInt() ?? 4096;
    final temperature = (cfg['temperature'] as num?)?.toDouble() ?? 0.7;
    final timeout = (cfg['timeOut'] as num?)?.toInt() ?? 60;
    final thinking = (cfg['thinking'] as bool?) ?? false;
    final hasApiKey = (cfg['hasApiKey'] as bool?) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('配置 ${widget.index + 1}', style: textTheme.titleSmall),
              const Spacer(),
              IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[300]), onPressed: widget.onDelete, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
            ]),
            const SizedBox(height: 8),
            _Field(label: '名称', child: TextField(controller: _nameCtl, decoration: const InputDecoration(hintText: '例如: OpenAI', isDense: true), onChanged: (v) => widget.onChanged('name', v))),
            _Field(label: '接口地址', child: TextField(controller: _urlCtl, decoration: const InputDecoration(hintText: 'https://api.openai.com/v1', isDense: true), onChanged: (v) => widget.onChanged('baseUrl', v))),
            _Field(label: 'API Key', child: TextField(controller: _keyCtl, decoration: InputDecoration(
              hintText: hasApiKey ? '(已设置)' : 'sk-...',
              isDense: true,
              suffixText: hasApiKey ? '🔒' : null,
            ), onChanged: (v) => widget.onChanged('apiKey', v))),
            _Field(label: '模型', child: TextField(controller: _modelCtl, decoration: const InputDecoration(hintText: 'gpt-4o', isDense: true), onChanged: (v) => widget.onChanged('modelName', v))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Field(label: 'Max Tokens', child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                controller: TextEditingController(text: maxTokens.toString()),
                onChanged: (v) => widget.onChanged('maxTokens', int.tryParse(v) ?? 4096),
              ))),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Temperature', child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                controller: TextEditingController(text: temperature.toString()),
                onChanged: (v) => widget.onChanged('temperature', double.tryParse(v) ?? 0.7),
              ))),
            ]),
            Row(children: [
              Expanded(child: _Field(label: '超时(秒)', child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                controller: TextEditingController(text: timeout.toString()),
                onChanged: (v) => widget.onChanged('timeOut', int.tryParse(v) ?? 60),
              ))),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: '代理地址', child: TextField(controller: _proxyCtl, decoration: const InputDecoration(hintText: '可选', isDense: true), onChanged: (v) => widget.onChanged('httpProxy', v)))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Switch(value: widget.config['httpProxyEnabled'] as bool? ?? false, onChanged: (v) => widget.onChanged('httpProxyEnabled', v)),
              const Text('启用代理', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Switch(value: thinking, onChanged: (v) => widget.onChanged('thinking', v)),
              const Text('深度思考', style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 2),
        child,
      ]),
    );
  }
}
