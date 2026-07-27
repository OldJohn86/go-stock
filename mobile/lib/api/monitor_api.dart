import 'api_client.dart';

/// 预警监控 API
class MonitorApi {
  final _client = ApiClient();

  /// 获取预警监控状态
  Future<Map<String, dynamic>?> getMonitorStatus() async {
    final resp = await _client.get('/radar/monitor-status');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// 启动预警监控
  Future<bool> startMonitor() async {
    final resp = await _client.post('/radar/monitor-start');
    return resp.isSuccess;
  }

  /// 停止预警监控
  Future<bool> stopMonitor() async {
    final resp = await _client.post('/radar/monitor-stop');
    return resp.isSuccess;
  }
}
