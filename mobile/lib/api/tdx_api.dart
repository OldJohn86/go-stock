import 'api_client.dart';

/// TDX 深度数据 API
class TdxApi {
  final _client = ApiClient();

  /// 获取分时图数据
  Future<Map<String, dynamic>> getMinuteTime(String code) async {
    final resp = await _client.get('/tdx/minute-time/$code');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取历史分时图数据
  Future<Map<String, dynamic>> getHistoryMinuteTime(String code, String tradeDate) async {
    final resp = await _client.get('/tdx/history-minute-time/$code', params: {'tradeDate': tradeDate});
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取当日分笔成交
  Future<List<dynamic>> getTransactions(String code, {int start = 0, int count = 500}) async {
    final resp = await _client.get('/tdx/transactions/$code', params: {
      'start': start.toString(),
      'count': count.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取全量分笔成交
  Future<List<dynamic>> getAllTransactions(String code) async {
    final resp = await _client.get('/tdx/all-transactions/$code');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取历史分笔成交
  Future<List<dynamic>> getHistoryTransactions(String code, String tradeDate) async {
    final resp = await _client.get('/tdx/history-transactions/$code', params: {'tradeDate': tradeDate});
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取集合竞价数据
  Future<List<dynamic>> getCallAuction(String code, {int start = 0, int count = 500}) async {
    final resp = await _client.get('/tdx/call-auction/$code', params: {
      'start': start.toString(),
      'count': count.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取公司概况
  Future<Map<String, dynamic>> getCompanyInfo(String code) async {
    final resp = await _client.get('/tdx/company-info/$code');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取财务数据
  Future<Map<String, dynamic>> getFinanceInfo(String code) async {
    final resp = await _client.get('/tdx/finance-info/$code');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取除权除息信息
  Future<List<dynamic>> getXDXRInfo(String code) async {
    final resp = await _client.get('/tdx/xdxr-info/$code');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取公司分类列表
  Future<List<dynamic>> getCompanyCategoryList(String code) async {
    final resp = await _client.get('/tdx/company-categories/$code');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取公司分类内容
  Future<Map<String, dynamic>> getCompanyCategoryContent(String code, String categoryName) async {
    final resp = await _client.get('/tdx/company-category-content/$code', params: {'categoryName': categoryName});
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取所属板块
  Future<List<dynamic>> getSymbolBoards(String code) async {
    final resp = await _client.get('/tdx/symbol-boards/$code');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取筹码分布
  Future<Map<String, dynamic>> getChipDistribution(String code, {int days = 365, int bins = 100, String adjustFlag = 'qfq'}) async {
    final resp = await _client.get('/tdx/chip-distribution/$code', params: {
      'days': days.toString(),
      'bins': bins.toString(),
      'adjustFlag': adjustFlag,
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取东方财富K线
  Future<List<dynamic>> getKLine(String code, {String klt = '101', int limit = 500}) async {
    final resp = await _client.get('/tdx/kline/$code', params: {
      'klt': klt,
      'limit': limit.toString(),
    });
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }

  /// 获取多源K线
  Future<Map<String, dynamic>> getKLineFallback(String code, {String klt = '101', int limit = 500, String adjustFlag = 'qfq'}) async {
    final resp = await _client.get('/tdx/kline-fallback/$code', params: {
      'klt': klt,
      'limit': limit.toString(),
      'adjustFlag': adjustFlag,
    });
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }
}
