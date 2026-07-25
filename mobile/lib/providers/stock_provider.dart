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

  Future<List<StockRealTime>> _fetch({bool forceRefresh = false}) async {
    final api = ref.read(stockApiProvider);
    if (forceRefresh) {
      return api.getFollowList();
    }
    // 默认走缓存，30 秒 TTL
    return api.getFollowListCached();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch(forceRefresh: true));
  }

  /// 关注一只股票
  Future<void> follow(String stockCode) async {
    final api = ref.read(stockApiProvider);
    await api.followStock(stockCode);
    // 刷新后清除缓存，确保下次读取最新数据
    await api.clearFollowListCache();
    state = AsyncData(await _fetch(forceRefresh: true));
  }

  /// 取消关注一只股票
  Future<void> unfollow(String stockCode) async {
    final api = ref.read(stockApiProvider);
    await api.unfollowStock(stockCode);
    // 刷新后清除缓存，确保下次读取最新数据
    await api.clearFollowListCache();
    state = AsyncData(await _fetch(forceRefresh: true));
  }
}
