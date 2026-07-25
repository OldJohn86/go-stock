import '../models/trading_record.dart';
import 'api_client.dart';

/// 交易日志 API
class TradingApi {
  final _client = ApiClient();

  /// 获取交易日志列表
  Future<TradingRecordPageData?> getRecords({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? direction,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (direction != null && direction.isNotEmpty) params['direction'] = direction;
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

    final resp = await _client.get('/trading/records', params: params);
    if (resp.isSuccess && resp.data != null) {
      return TradingRecordPageData.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 获取交易统计数据
  Future<TradingRecordStatistics?> getStatistics() async {
    final resp = await _client.get('/trading/statistics');
    if (resp.isSuccess && resp.data != null) {
      return TradingRecordStatistics.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }
}
