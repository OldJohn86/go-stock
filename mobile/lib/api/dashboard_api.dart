import 'api_client.dart';

/// 大盘仪表盘 API
class DashboardApi {
  final _client = ApiClient();

  /// 获取大盘仪表盘概览
  Future<Map<String, dynamic>?> getOverview() async {
    final resp = await _client.get('/dashboard/overview');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// 获取投资组合概览
  Future<Map<String, dynamic>?> getPortfolio() async {
    final resp = await _client.get('/dashboard/portfolio');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }
}
