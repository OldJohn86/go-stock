import 'api_client.dart';

/// 定时任务管理 API
class CronTaskApi {
  final _client = ApiClient();

  /// 获取任务列表
  Future<Map<String, dynamic>> getTaskList({
    int page = 1,
    int pageSize = 20,
    String keyword = '',
    String taskType = '',
    String status = '',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (keyword.isNotEmpty) params['name'] = keyword;
    if (taskType.isNotEmpty) params['taskType'] = taskType;
    if (status.isNotEmpty) params['status'] = status;
    final resp = await _client.get('/cron-tasks/list', params: params);
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return {};
  }

  /// 创建任务
  Future<bool> createTask(Map<String, dynamic> task) async {
    final resp = await _client.post('/cron-tasks/create', data: task);
    return resp.isSuccess;
  }

  /// 更新任务
  Future<bool> updateTask(Map<String, dynamic> task) async {
    final resp = await _client.post('/cron-tasks/update', data: task);
    return resp.isSuccess;
  }

  /// 删除任务
  Future<bool> deleteTask(int id) async {
    final resp = await _client.post('/cron-tasks/delete/$id');
    return resp.isSuccess;
  }

  /// 启用/禁用任务
  Future<bool> enableTask(int id, bool enable) async {
    final resp = await _client.post('/cron-tasks/enable/$id', data: {'enable': enable});
    return resp.isSuccess;
  }

  /// 立即执行任务
  Future<bool> executeTask(int id) async {
    final resp = await _client.post('/cron-tasks/execute/$id');
    return resp.isSuccess;
  }

  /// 获取任务类型列表
  Future<List<dynamic>> getTaskTypes() async {
    final resp = await _client.get('/cron-tasks/types');
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>;
      return list;
    }
    return [];
  }
}
