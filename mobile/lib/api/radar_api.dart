import 'api_client.dart';

/// 行情雷达 API
class RadarApi {
  final _client = ApiClient();

  /// 获取行情雷达概览
  Future<Map<String, dynamic>?> getOverview() async {
    final resp = await _client.get('/radar/overview');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// 获取个股资金流向
  Future<Map<String, dynamic>?> getMoneyFlow({
    required String code,
    int days = 5,
  }) async {
    final resp = await _client.get('/radar/money-flow', params: {
      'code': code,
      'days': days,
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// 获取涨停热点
  Future<Map<String, dynamic>?> getUplimitHot({
    String? date,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (date != null) params['date'] = date;
    final resp = await _client.get('/radar/uplimit-hot', params: params);
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }
}
