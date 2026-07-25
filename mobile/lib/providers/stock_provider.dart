import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';

final stockApiProvider = Provider<StockApi>((ref) => StockApi());

/// 自选股列表（手动刷新，页面内可设置定时刷新）
final followListProvider =
    AsyncNotifierProvider<FollowListNotifier, List<StockRealTime>>(
  FollowListNotifier.new,
);

class FollowListNotifier extends AsyncNotifier<List<StockRealTime>> {
  @override
  Future<List<StockRealTime>> build() async {
    return _fetch();
  }

  Future<List<StockRealTime>> _fetch() async {
    final api = ref.read(stockApiProvider);
    return api.getFollowList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}
