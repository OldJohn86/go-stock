import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';

/// 设置页
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  bool _isLoading = false;
  String? _testMessage;
  bool _testSuccess = false;

  List<Map<String, dynamic>> _aiConfigs = [];
  bool _loadingConfigs = false;

  @override
  void initState() {
    super.initState();
    _loadAiConfigs();
  }

  Future<void> _loadAiConfigs() async {
    setState(() => _loadingConfigs = true);
    try {
      final resp = await ApiClient().get('/settings/ai-configs');
      if (resp.isSuccess && resp.data != null) {
        setState(() {
          _aiConfigs = List<Map<String, dynamic>>.from(resp.data);
        });
      }
    } catch (e) {
      debugPrint('Load AI configs failed: $e');
    } finally {
      setState(() => _loadingConfigs = false);
    }
  }

  Future<void> _testConnection() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty) {
      _setTestResult('请输入接口地址', false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{'baseUrl': baseUrl};
      if (apiKey.isNotEmpty) params['apiKey'] = apiKey;

      final resp = await ApiClient().get(
        '/settings/test-connection',
        params: params,
      );
      _setTestResult(
        resp.isSuccess ? '连接成功' : resp.message,
        resp.isSuccess,
      );
    } catch (e) {
      _setTestResult('连接失败: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setTestResult(String msg, bool success) {
    setState(() {
      _testMessage = msg;
      _testSuccess = success;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // About
          _buildSection('关于', [
            _buildAboutCard(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('版本'),
              trailing: Text(
                '1.0.0',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.api),
              title: const Text('API 地址'),
              subtitle: Text(
                ApiConfig.baseUrl,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // AI Service Test
          _buildSection('AI 模型服务测试', [
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: '接口地址',
                hintText: 'https://api.openai.com 或 http://localhost:11434',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key（Ollama 可留空）',
                prefixIcon: const Icon(Icons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: _isLoading
                    ? SizedBox(
                        width: 18, height: 18,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isLoading ? '测试中...' : '测试连接'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _testSuccess
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _testSuccess ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          color: _testSuccess
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // Server AI Configs
          _buildSection('服务端 AI 模型配置', [
            if (_loadingConfigs)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_aiConfigs.isEmpty)
              ListTile(
                leading: Icon(Icons.cloud_off_outlined,
                    color: Colors.grey[400]),
                title: Text(
                  '暂无 AI 模型配置',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                subtitle: const Text(
                  '请在桌面端添加 AI 模型服务配置',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              ..._aiConfigs.map((cfg) => _buildAiConfigCard(cfg)),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.show_chart, color: Colors.white),
      ),
      title: Text(
        'go-stock Mobile',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      subtitle: const Text('AI 智能选股 · 实时行情'),
    );
  }

  Widget _buildAiConfigCard(Map<String, dynamic> cfg) {
    final isOllama = (cfg['baseUrl'] ?? '').toString().contains(':11434') ||
        (cfg['baseUrl'] ?? '').toString().toLowerCase().contains('ollama');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOllama
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOllama ? 'Ollama' : 'API',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isOllama
                        ? Colors.orange[800]
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cfg['name']?.toString() ?? '未命名',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cfg['modelName']?.toString() ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.api_outlined,
                  size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cfg['baseUrl']?.toString() ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (cfg['thinking'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Chip(
                label: const Text('Thinking', style: TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                    color: Colors.purple.withValues(alpha: 0.3)),
              ),
            ),
        ],
      ),
    );
  }
}