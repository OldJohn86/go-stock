import 'api_client.dart';

/// 风控管理 API
class RiskApi {
  final _client = ApiClient();

  /// 获取风控报告
  Future<Map<String, dynamic>> getRiskReport() async {
    final resp = await _client.get('/dashboard/risk-report');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取持仓列表（含实时盈亏）
  Future<Map<String, dynamic>> getPositions() async {
    final resp = await _client.get('/dashboard/positions');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 添加持仓
  Future<bool> addPosition(Map<String, dynamic> position) async {
    final resp = await _client.post('/dashboard/position/add', data: position);
    return resp.isSuccess;
  }

  /// 更新持仓
  Future<bool> updatePosition(Map<String, dynamic> position) async {
    final resp = await _client.post('/dashboard/position/update', data: position);
    return resp.isSuccess;
  }

  /// 删除持仓
  Future<bool> deletePosition(int id) async {
    final resp = await _client.post('/dashboard/position/delete/$id');
    return resp.isSuccess;
  }

  /// 获取近期交易
  Future<List<dynamic>> getRecentTrades({String? stockCode, int days = 30}) async {
    final params = <String, String>{'days': days.toString()};
    if (stockCode != null && stockCode.isNotEmpty) {
      params['stockCode'] = stockCode;
    }
    final resp = await _client.get('/dashboard/recent-trades', params: params);
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }
}
