import 'api_client.dart';

class AiRecommendApi {
  final _client = ApiClient();

  /// 获取AI推荐股票列表
  Future<Map<String, dynamic>> getList({
    String keyword = '',
    String startDate = '',
    String endDate = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (keyword.isNotEmpty) params['keyword'] = keyword;
    if (startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate.isNotEmpty) params['endDate'] = endDate;

    final resp = await _client.get('/ai-recommend/list', params: params);
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 更新预警状态
  Future<bool> updateAlert(int id, bool enableAlert) async {
    final resp = await _client.post('/ai-recommend/alert', data: {
      'id': id,
      'enableAlert': enableAlert,
    });
    return resp.isSuccess;
  }

  /// 删除推荐记录
  Future<bool> delete(int id) async {
    final resp = await _client.post('/ai-recommend/delete/$id');
    return resp.isSuccess;
  }
}
