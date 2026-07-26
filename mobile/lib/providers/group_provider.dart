import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';

/// 分组数据模型
class GroupModel {
  final int id;
  final String name;
  final int sort;

  GroupModel({
    required this.id,
    required this.name,
    required this.sort,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['ID'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      sort: json['sort'] as int? ?? 0,
    );
  }
}

class GroupListNotifier extends StateNotifier<List<GroupModel>> {
  final Ref ref;
  final _api = StockApi();

  GroupListNotifier(this.ref) : super([]) {
    load();
  }

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
}

final groupListProvider = StateNotifierProvider<GroupListNotifier, List<GroupModel>>((ref) {
  return GroupListNotifier(ref);
});
