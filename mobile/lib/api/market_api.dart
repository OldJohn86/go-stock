import 'api_client.dart';

/// 市场数据（板块行情、资金流向）API
class MarketApi {
  final _client = ApiClient();

  /// 获取行业资金流排名
  /// [fenlei] 0=行业板块 1=概念板块
  /// [sort] 排序字段（netamount=净流入, inflow=流入, outflow=流出）
  Future<List<Map<String, dynamic>>> getIndustryMoneyRank({
    int fenlei = 0,
    String sort = 'netamount',
  }) async {
    final resp = await _client.get(
      '/market/industry-money-rank',
      params: {'fenlei': fenlei, 'sort': sort},
    );
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取行业估值数据
  Future<List<Map<String, dynamic>>> getIndustryValuation({
    String name = '',
  }) async {
    final params = <String, dynamic>{};
    if (name.isNotEmpty) params['name'] = name;
    final resp = await _client.get('/market/industry-valuation', params: params);
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取概念资金流向排名
  Future<List<Map<String, dynamic>>> getConceptFundFlowRank({
    int topN = 20,
  }) async {
    final resp = await _client.get(
      '/market/concept-fund-flow',
      params: {'topN': topN},
    );
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取热门股票排行
  Future<List<Map<String, dynamic>>> getHotStocks({int size = 20, String marketType = '10'}) async {
    final resp = await _client.get('/market/hot-stocks', params: {
      'size': size.toString(),
      'marketType': marketType,
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取热门事件
  Future<List<Map<String, dynamic>>> getHotEvents({int size = 20}) async {
    final resp = await _client.get('/market/hot-events', params: {
      'size': size.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取热门题材
  Future<List<Map<String, dynamic>>> getHotTopics({int size = 20}) async {
    final resp = await _client.get('/market/hot-topics', params: {
      'size': size.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取龙虎榜数据
  Future<List<Map<String, dynamic>>> getLongTiger({String? date}) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    final resp = await _client.get('/market/long-tiger', params: params);
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取股票公告
  Future<List<Map<String, dynamic>>> getStockNotice(String stockList) async {
    final resp = await _client.get('/market/stock-notice', params: {
      'stockList': stockList,
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取板块成分股列表
  /// 返回 stocks 列表
  Future<List<Map<String, dynamic>>> getSectorStocks({
    required String name,
    String type = 'industry',
    String sort = 'changeRate',
    int page = 1,
    int pageSize = 50,
  }) async {
    final resp = await _client.get('/market/sector-stocks', params: {
      'name': name,
      'type': type,
      'sort': sort,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
    // 后端返回 { code, message, data: { total, page, pageSize, stocks: [...] } }
    if (resp.isSuccess && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      final innerData = data['data'] as Map<String, dynamic>?;
      final stocks = innerData?['stocks'] as List<dynamic>?;
      if (stocks != null) {
        return stocks.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }
}
