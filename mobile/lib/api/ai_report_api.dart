import 'api_client.dart';

class AiReportApi {
  final _client = ApiClient();

  /// 获取AI研究报告列表
  Future<Map<String, dynamic>> getList({
    String keyword = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (keyword.isNotEmpty) params['keyword'] = keyword;

    final resp = await _client.get('/ai-report/list', params: params);
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 删除研究报告
  Future<bool> delete(int id) async {
    final resp = await _client.post('/ai-report/delete/$id');
    return resp.isSuccess;
  }
}
