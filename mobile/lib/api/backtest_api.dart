import 'api_client.dart';

/// 回测分析 API
class BacktestApi {
  final _client = ApiClient();

  /// 获取回测分析数据
  Future<Map<String, dynamic>?> getBacktestAnalysis() async {
    final resp = await _client.get('/trading/backtest');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }
}
