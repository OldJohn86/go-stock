import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/push_api.dart';
import '../config/api_config.dart';
import '../providers/api_url_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/notification_helper.dart';
import 'cron_task_page.dart';
import 'fund_list_page.dart';
import 'mcp_server_page.dart';
import 'stock_notice_page.dart';
import 'trading_calendar_page.dart';

/// 设置页
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _aiBaseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  /// Backend URL editing
  final _backendUrlController = TextEditingController();
  bool _backendUrlChanged = false;
  bool _backendTesting = false;
  String? _backendTestResult;
  bool _backendTestSuccess = false;

  bool _isLoading = false;
  String? _testMessage;
  bool _testSuccess = false;

  List<Map<String, dynamic>> _aiConfigs = [];
  bool _loadingConfigs = false;

  /// Push notification state
  String _deviceId = '';
  bool _pushRegistered = false;
  bool _pushLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize backend URL field with current value
    final currentUrl = ApiClient().baseUrl.replaceAll('/api/v1', '');
    _backendUrlController.text = currentUrl;
    _backendUrlController.addListener(_onBackendUrlChanged);
    _loadAiConfigs();
    _initPush();
  }

  Future<void> _initPush() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('push_device_id') ?? '';
    final registered = prefs.getBool('push_registered') ?? false;
    if (mounted) {
      setState(() {
        _deviceId = deviceId;
        _pushRegistered = registered;
      });
    }
  }

  void _onBackendUrlChanged() {
    final currentUrl = ApiClient().baseUrl.replaceAll('/api/v1', '');
    final changed = _backendUrlController.text.trim() != currentUrl;
    if (changed != _backendUrlChanged) {
      setState(() => _backendUrlChanged = changed);
    }
  }

  Future<void> _saveBackendUrl() async {
    final url = _backendUrlController.text.trim();
    if (url.isEmpty) return;
    ApiClient().setBaseUrl(url);
    await ref.read(apiUrlProvider.notifier).setUrl(url);
    setState(() {
      _backendUrlChanged = false;
      _backendTestResult = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('后端地址已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetBackendUrl() async {
    await ref.read(apiUrlProvider.notifier).resetToDefault();
    final defaultUrl = ApiConfig.baseUrl;
    ApiClient().setBaseUrl(defaultUrl);
    _backendUrlController.text = defaultUrl;
    setState(() {
      _backendUrlChanged = false;
      _backendTestResult = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已恢复默认地址'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testBackendConnection() async {
    setState(() {
      _backendTesting = true;
      _backendTestResult = null;
    });
    try {
      final resp = await ApiClient().get('/settings');
      setState(() {
        _backendTestSuccess = resp.isSuccess;
        _backendTestResult = resp.isSuccess ? '连接成功' : resp.message;
      });
    } catch (e) {
      setState(() {
        _backendTestSuccess = false;
        _backendTestResult = '连接失败: $e';
      });
    } finally {
      setState(() => _backendTesting = false);
    }
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
    final baseUrl = _aiBaseUrlController.text.trim();
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
    _aiBaseUrlController.dispose();
    _apiKeyController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('本地通知测试'),
              subtitle: const Text('发送一条测试通知到通知栏'),
              trailing: FilledButton(
                onPressed: () async {
                  await NotificationHelper.sendPriceAlert(
                    stockCode: '000001',
                    stockName: '平安银行',
                    price: 11.50,
                    changePercent: 3.25,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('测试通知已发送，请下拉通知栏查看'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('发送'),
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

          // Backend Connection Config
          _buildSection('后端连接', [
            _buildBackendUrlTile(),
          ]),

          const SizedBox(height: 16),

          // Theme Mode Selector
          _buildSection('主题模式', [
            _buildThemeModeTile(),
          ]),

          const SizedBox(height: 16),

          // Push Notification
          _buildSection('推送通知', [
            _buildPushNotificationTile(),
          ]),

          const SizedBox(height: 16),

          // AI Service Test
          _buildSection('AI 模型服务测试', [
            TextField(
              controller: _aiBaseUrlController,
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
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _testSuccess
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                        : Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _testSuccess
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          color: _testSuccess
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                title: Text(
                  '暂无 AI 模型配置',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                subtitle: const Text(
                  '请在桌面端添加 AI 模型服务配置',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              ..._aiConfigs.map((cfg) => _buildAiConfigCard(cfg)),

          const SizedBox(height: 16),

          // 其他功能
          _buildSection('其他功能', [
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text("基金追踪"),
              subtitle: const Text("基金行情与短线机会"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundListPage())),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text("股票公告"),
              subtitle: const Text("业绩预告、重大公告"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockNoticePage())),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text("交易日历"),
              subtitle: const Text("A\u80a1\u5e02\u573a\u4ea4\u6613\u65e5/\u975e\u4ea4\u6613\u65e5"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradingCalendarPage())),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text("定时任务"),
              subtitle: const Text("自动任务调度与执行"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CronTaskPage())),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text("MCP服务管理"),
              subtitle: const Text("AI\u5de5\u5177AI工具集成服务配置"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const McpServerPage())),
            ),
          ]),

          ]),
        ],
      ),
    );
  }

  Widget _buildBackendUrlTile() {
    final theme = Theme.of(context);
    final currentUrl = ApiClient().baseUrl;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _backendUrlController,
            decoration: InputDecoration(
              labelText: '后端地址',
              hintText: 'http://192.168.x.x:8080',
              prefixIcon: const Icon(Icons.dns_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _backendUrlChanged ? _saveBackendUrl : null,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _resetBackendUrl,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('重置'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _backendTesting ? null : _testBackendConnection,
                icon: _backendTesting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find, size: 18),
                label: Text(_backendTesting ? '测试中' : '测试'),
              ),
            ],
          ),
          if (_backendTestResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _backendTestSuccess
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _backendTestSuccess
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _backendTestSuccess
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: _backendTestSuccess
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _backendTestResult!,
                      style: TextStyle(
                        color: _backendTestSuccess
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '当前: $currentUrl',
            style: TextStyle(fontSize: 11, color: theme.disabledColor),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeTile() {
    final theme = Theme.of(context);
    final currentMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '选择主题',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('浅色'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('深色'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness),
                label: Text('跟随系统'),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (selected) {
              ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPushNotificationTile() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          Row(
            children: [
              Icon(
                _pushRegistered ? Icons.check_circle : Icons.notifications_off_outlined,
                size: 20,
                color: _pushRegistered ? Colors.green : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                _pushRegistered ? '已注册推送服务' : '未注册推送服务',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _pushRegistered ? Colors.green : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _deviceId.isNotEmpty ? '设备 ID: ${_deviceId.length > 20 ? "${_deviceId.substring(0, 20)}..." : _deviceId}' : '尚未生成设备标识',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _pushLoading ? null : (_pushRegistered ? _unregisterDevice : _registerDevice),
                  icon: _pushLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_pushRegistered ? Icons.logout : Icons.login, size: 18),
                  label: Text(_pushLoading ? '处理中...' : (_pushRegistered ? '注销设备' : '注册设备')),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final sm = ScaffoldMessenger.of(context);
                  await NotificationHelper.sendPriceAlert(
                    stockCode: '000001',
                    stockName: '平安银行',
                    price: 11.50,
                    changePercent: 3.25,
                  );
                  if (!context.mounted) return;
                  sm.showSnackBar(
                    const SnackBar(
                      content: Text('测试通知已发送，请下拉通知栏查看'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_active, size: 18),
                label: const Text('测试'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '注册后，当服务端触发推送事件（如预警提醒、任务完成）时，将通过 FCM 推送到本设备。需要服务端配置 Firebase 项目。',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = random.nextInt(999999);
    return 'dart_${timestamp}_$rand';
  }

  Future<void> _registerDevice() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pushLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('push_device_id') ?? '';
      if (deviceId.isEmpty) {
        deviceId = _generateDeviceId();
        await prefs.setString('push_device_id', deviceId);
      }

      // Register on the server
      final api = PushApi();
      final ok = await api.registerToken(deviceId, 'android');
      if (mounted) {
        if (ok) {
          await prefs.setBool('push_registered', true);
          setState(() {
            _deviceId = deviceId;
            _pushRegistered = true;
          });
          messenger.showSnackBar(
            const SnackBar(content: Text('设备已注册推送服务'), behavior: SnackBarBehavior.floating),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('注册失败，请检查后端连接'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _pushLoading = false);
    }
  }

  Future<void> _unregisterDevice() async {
    setState(() => _pushLoading = true);
    try {
      final api = PushApi();
      final messenger = ScaffoldMessenger.of(context);
      await api.unregisterToken(_deviceId);
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('push_registered', false);
        setState(() => _pushRegistered = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('设备已注销推送服务'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注销失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _pushLoading = false);
    }
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
        'goldstock Mobile',
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
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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