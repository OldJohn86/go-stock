import '../models/kline_data.dart';
import '../models/minute_data.dart';
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

  /// 获取全部股票列表
  Future<List<StockRealTime>> getStockList({
    int page = 1,
    int pageSize = 20,
    String name = '',
  }) async {
    final resp = await _client.get('/stock/list', params: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (name.isNotEmpty) 'name': name,
    });
    if (resp.isSuccess && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result != null) {
        final list = result['data'] as List<dynamic>?;
        if (list != null) {
          return list
              .map((e) => _convertMarketItem(e as Map<String, dynamic>))
              .map((e) => StockRealTime.fromJson(e))
              .toList();
        }
      }
    }
    return [];
  }

  /// 将全市场列表的英文字段映射为中文key（StockRealTime 需要）
  Map<String, dynamic> _convertMarketItem(Map<String, dynamic> item) {
    return {
      '股票代码': item['SECUCODE'] as String? ?? '',
      '股票名称': item['SECURITY_NAME_ABBR'] as String? ?? '',
      '当前价格': (item['NEW_PRICE'] as num?)?.toDouble() ?? 0,
      '昨日收盘价': (item['PRE_CLOSE_PRICE'] as num?)?.toDouble() ?? 0,
      '今日开盘价': 0.0,
      '今日最高价': (item['HIGH_PRICE'] as num?)?.toDouble() ?? 0,
      '今日最低价': (item['LOW_PRICE'] as num?)?.toDouble() ?? 0,
      '日期': item['MAX_TRADE_DATE'] as String? ?? '',
      '时间': '',
    };
  }

  /// 获取K线数据
  /// type: 101=日K, 102=周K, 103=月K, 5/15/30/60=分钟线
  Future<List<KLineData>> getKLineData(String stockCode,
      {String type = '101', int days = 100}) async {
    final resp = await _client.get(
      '/stock/$stockCode/kline',
      params: {'type': type, 'days': days.toString()},
    );
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list
          .map((e) => KLineData.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取分时数据
  Future<Map<String, dynamic>> getMinuteData(String stockCode) async {
    final resp = await _client.get('/stock/$stockCode/minute');
    if (resp.isSuccess && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      final date = data['date'] as String? ?? '';
      final list = (data['data'] as List<dynamic>?)
              ?.map((e) => MinuteData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return {'date': date, 'data': list};
    }
    return {'date': '', 'data': <MinuteData>[]};
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
