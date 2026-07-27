import 'api_client.dart';

class FundApi {
  final _client = ApiClient();

  /// 获取关注的基金列表
  Future<Map<String, dynamic>> getList({
    int pageIndex = 1,
    int pageSize = 20,
    String keyword = '',
  }) async {
    final params = <String, String>{
      'pageIndex': pageIndex.toString(),
      'pageSize': pageSize.toString(),
    };
    if (keyword.isNotEmpty) params['keyword'] = keyword;

    final resp = await _client.get('/fund/list', params: params);
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 搜索基金
  Future<List<Map<String, dynamic>>> search(String keyword) async {
    final resp = await _client.get('/fund/search', params: {'keyword': keyword});
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 关注基金
  Future<String> follow(String code) async {
    final resp = await _client.post('/fund/follow', data: {'code': code});
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as Map<String, dynamic>)['message'] as String? ?? '';
    }
    return resp.message;
  }

  /// 取消关注
  Future<String> unfollow(String code) async {
    final resp = await _client.post('/fund/unfollow', data: {'code': code});
    if (resp.isSuccess && resp.data != null) {
      return (resp.data as Map<String, dynamic>)['message'] as String? ?? '';
    }
    return resp.message;
  }

  /// 获取基金排行
  Future<Map<String, dynamic>> getRanking({
    String marketType = '1',
    String fundType = '1',
    String sortField = 'yearGrowth',
    String sortOrder = 'desc',
    int pageIndex = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.get('/fund/ranking', params: {
      'marketType': marketType,
      'fundType': fundType,
      'sortField': sortField,
      'sortOrder': sortOrder,
      'pageIndex': pageIndex.toString(),
      'pageSize': pageSize.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取基金十大持仓
  Future<List<Map<String, dynamic>>> getHoldings(String code) async {
    final resp = await _client.get('/fund/$code/holdings');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取基金历史净值
  Future<List<Map<String, dynamic>>> getHistory(String code, {
    int pageIndex = 1,
    int pageSize = 20,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      'pageIndex': pageIndex.toString(),
      'pageSize': pageSize.toString(),
    };
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    final resp = await _client.get('/fund/$code/history', params: params);
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取基金K线
  Future<Map<String, dynamic>> getKLine(String code, {String klt = '101', int limit = 100}) async {
    final resp = await _client.get('/fund/$code/kline', params: {
      'klt': klt,
      'limit': limit.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取基金基本信息
  Future<Map<String, dynamic>> getBasic(String code) async {
    final resp = await _client.get('/fund/$code/basic');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }
}
