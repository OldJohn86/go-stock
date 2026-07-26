import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

const _kApiUrlKey = 'custom_api_url';

/// Provider for the current backend API base URL.
///
/// Allows the user to override the compiled-in default via SharedPreferences.
final apiUrlProvider =
    StateNotifierProvider<ApiUrlNotifier, String>((ref) {
  return ApiUrlNotifier();
});

class ApiUrlNotifier extends StateNotifier<String> {
  ApiUrlNotifier() : super(ApiConfig.baseUrl) {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kApiUrlKey);
      if (stored != null && stored.trim().isNotEmpty) {
        state = stored.trim();
      }
    } catch (_) {}
  }

  Future<void> setUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      // Reset to default
      state = ApiConfig.baseUrl;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kApiUrlKey);
      } catch (_) {}
      return;
    }
    state = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kApiUrlKey, trimmed);
    } catch (_) {}
  }

  /// Resets to the compiled-in default URL.
  Future<void> resetToDefault() async {
    state = ApiConfig.baseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kApiUrlKey);
    } catch (_) {}
  }
}
