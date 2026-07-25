import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Generic JSON cache using SharedPreferences.
///
/// Each cache entry stores:
/// - The data as a JSON-encoded string (key prefix: `cache_`)
/// - A millisecond timestamp (key prefix: `cache_ts_`)
///
/// Default max ages:
/// - Real-time data: 30 seconds
/// - Stock list: 5 minutes
/// - F10 financial data: 1 hour
class CacheManager {
  CacheManager._();

  static const String _prefix = 'cache_';
  static const String _timestampPrefix = 'cache_ts_';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Default max ages for different data categories.
  static const Duration realtimeMaxAge = Duration(seconds: 30);
  static const Duration stockListMaxAge = Duration(minutes: 5);
  static const Duration financeMaxAge = Duration(hours: 1);

  /// Retrieve cached data.
  ///
  /// Returns `null` if the key doesn't exist, the data has expired (older than
  /// [maxAge]), or deserialization fails. Expired entries are automatically
  /// cleaned up.
  static Future<T?> get<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson, {
    Duration maxAge = realtimeMaxAge,
  }) async {
    final prefs = await _prefs;
    final ts = prefs.getInt('$_timestampPrefix$key');
    if (ts == null) return null;

    if (DateTime.now().millisecondsSinceEpoch - ts > maxAge.inMilliseconds) {
      // Expired, clean up
      await prefs.remove('$_prefix$key');
      await prefs.remove('$_timestampPrefix$key');
      return null;
    }

    final data = prefs.getString('$_prefix$key');
    if (data == null) return null;

    try {
      return fromJson(json.decode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Retrieve cached data ignoring expiry (stale data).
  ///
  /// Useful when offline — returns the most recently cached value even if
  /// expired, as long as the raw data exists in SharedPreferences.
  static Future<T?> getStale<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final prefs = await _prefs;
    final data = prefs.getString('$_prefix$key');
    if (data == null) return null;

    try {
      return fromJson(json.decode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Store data in the cache.
  ///
  /// [toJson] converts the domain object to a JSON-serializable map. The
  /// current timestamp is saved alongside the data for expiry checks.
  static Future<void> set<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final prefs = await _prefs;
    await prefs.setString('$_prefix$key', json.encode(toJson(data)));
    await prefs.setInt(
      '$_timestampPrefix$key',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Remove a specific cache entry.
  static Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_timestampPrefix$key');
  }

  /// Clear all cache entries managed by this [CacheManager].
  static Future<void> clearAll() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith(_prefix) || key.startsWith(_timestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
