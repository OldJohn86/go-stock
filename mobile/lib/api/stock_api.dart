import '../models/stock_info.dart';
import 'api_client.dart';

class StockApi {
  final _client = ApiClient();

  /// 获取单只股票实时行情
  Future<StockRealTime?> getRealTimePrice(String stockCode) async {
    final resp = await _client.get('/stock/real-time/$stockCode');
    if (resp.isSuccess && resp.data != null) {
      return StockRealTime.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 批量获取实时行情
  Future<List<StockRealTime>> getRealTimeBatch(List<String> codes) async {
    final resp = await _client.get(
      '/stock/realtime-batch',
      params: {'codes': codes},
    );
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list
          .map((e) => StockRealTime.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取自选股列表实时数据
  Future<List<StockRealTime>> getFollowList({int groupId = 0}) async {
    final resp = await _client.get('/follow/list', params: {
      'groupId': groupId.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list
          .map((e) => StockRealTime.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 关注股票
  Future<String> followStock(String stockCode) async {
    final resp = await _client.post('/follow/follow', data: {
      'stockCode': stockCode,
    });
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as Map<String, dynamic>)['message'] as String? ?? '';
    }
    return resp.message;
  }

  /// 取消关注
  Future<String> unfollowStock(String stockCode) async {
    final resp = await _client.post('/follow/unfollow', data: {
      'stockCode': stockCode,
    });
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as Map<String, dynamic>)['message'] as String? ?? '';
    }
    return resp.message;
  }
}
