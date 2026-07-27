import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import 'stock_provider.dart';

/// 分组数据模型
class GroupModel {
  final int id;
  final String name;
  final int sort;
  final int stockCount;

  GroupModel({
    required this.id,
    required this.name,
    required this.sort,
    this.stockCount = 0,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['ID'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      sort: json['sort'] as int? ?? 0,
      stockCount: json['stockCount'] as int? ?? 0,
    );
  }
}

class GroupListNotifier extends StateNotifier<List<GroupModel>> {
  final Ref ref;

  GroupListNotifier(this.ref) : super([]) {
    load();
  }

  StockApi get _api => ref.read(stockApiProvider);

  Future<void> load() async {
    try {
      final list = await _api.getGroupList();
      state = list.map((e) => GroupModel.fromJson(e)).toList();
    } catch (e) {
      // ignore, state stays as-is
    }
  }

  Future<bool> addGroup(String name) async {
    final success = await _api.createGroup(name: name, sort: state.length + 1);
    if (success) await load();
    return success;
  }

  Future<bool> updateGroup(int id, String name) async {
    final success = await _api.updateGroup(id: id, name: name);
    if (success) await load();
    return success;
  }

  Future<bool> deleteGroup(int id) async {
    final success = await _api.deleteGroup(id);
    if (success) await load();
    return success;
  }

  Future<bool> reorder(List<GroupModel> newOrder) async {
    bool allOk = true;
    for (int i = 0; i < newOrder.length; i++) {
      final ok = await _api.updateGroupSort(newOrder[i].id, i + 1);
      if (!ok) allOk = false;
    }
    if (allOk) {
      state = newOrder;
    }
    return allOk;
  }

  /// 将股票添加到指定分组
  Future<bool> addStockToGroup({
    required int groupId,
    required String stockCode,
  }) async {
    return _api.addStockToGroup(groupId: groupId, stockCode: stockCode);
  }

  /// 从分组移除股票
  Future<bool> removeStockFromGroup({
    required int groupId,
    required String stockCode,
  }) async {
    return _api.removeStockFromGroup(groupId: groupId, stockCode: stockCode);
  }
}

final groupListProvider = StateNotifierProvider<GroupListNotifier, List<GroupModel>>((ref) {
  return GroupListNotifier(ref);
});
