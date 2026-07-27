import 'api_client.dart';

/// K线形态识别 API
class KLinePatternApi {
  final _client = ApiClient();

  /// 获取K线形态识别结果
  Future<Map<String, dynamic>> analyzePattern(String code, {String klt = '101', int limit = 120}) async {
    final resp = await _client.get('/kline/pattern/$code', params: {
      'klt': klt,
      'limit': limit.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取K线形态摘要（含均线、趋势）
  Future<Map<String, dynamic>> getPatternSummary(String code, {String klt = '101', int limit = 60}) async {
    final resp = await _client.get('/kline/pattern-summary/$code', params: {
      'klt': klt,
      'limit': limit.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }
}
