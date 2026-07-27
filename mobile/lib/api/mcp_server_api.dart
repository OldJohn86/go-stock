import 'api_client.dart';

/// MCP 服务器管理 API
class McpServerApi {
  final _client = ApiClient();

  /// 获取服务器列表
  Future<Map<String, dynamic>> getServerList({
    int page = 1,
    int pageSize = 20,
    String keyword = '',
    String status = '',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (keyword.isNotEmpty) params['name'] = keyword;
    if (status.isNotEmpty) params['status'] = status;
    final resp = await _client.get('/mcp-servers/list', params: params);
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 创建服务器
  Future<bool> createServer(Map<String, dynamic> server) async {
    final resp = await _client.post('/mcp-servers/create', data: server);
    return resp.isSuccess;
  }

  /// 更新服务器
  Future<bool> updateServer(Map<String, dynamic> server) async {
    final resp = await _client.post('/mcp-servers/update', data: server);
    return resp.isSuccess;
  }

  /// 删除服务器
  Future<bool> deleteServer(int id) async {
    final resp = await _client.post('/mcp-servers/delete/$id');
    return resp.isSuccess;
  }

  /// 启用/禁用服务器
  Future<bool> enableServer(int id, bool enable) async {
    final resp = await _client.post('/mcp-servers/enable/$id', data: {'enable': enable});
    return resp.isSuccess;
  }

  /// 测试连接
  Future<Map<String, dynamic>> testConnection(int id) async {
    final resp = await _client.post('/mcp-servers/test/$id');
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 获取工具列表
  Future<List<dynamic>> getTools(int serverId) async {
    final resp = await _client.get('/mcp-servers/tools/$serverId');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }
}
