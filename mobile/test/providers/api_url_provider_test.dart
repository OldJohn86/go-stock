import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_stock_mobile/config/api_config.dart';
import 'package:go_stock_mobile/providers/api_url_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiUrlNotifier', () {
    test('initial state is ApiConfig.baseUrl', () {
      final notifier = ApiUrlNotifier();
      expect(notifier.state, ApiConfig.baseUrl);
    });

    test('setUrl changes state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ApiUrlNotifier();
      await Future(() {});

      await notifier.setUrl('http://192.168.1.100:8080');
      expect(notifier.state, 'http://192.168.1.100:8080');

      // Verify persistence
      SharedPreferences.setMockInitialValues({'custom_api_url': 'http://192.168.1.100:8080'});
      final restored = ApiUrlNotifier();
      await Future(() {});
      expect(restored.state, 'http://192.168.1.100:8080');
    });

    test('setUrl with empty string resets to default', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ApiUrlNotifier();
      await Future(() {});

      await notifier.setUrl('  '); // trimmed empty
      expect(notifier.state, ApiConfig.baseUrl);
    });

    test('setUrl trims whitespace', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ApiUrlNotifier();
      await Future(() {});

      await notifier.setUrl('  http://example.com  ');
      expect(notifier.state, 'http://example.com');
    });

    test('resetToDefault restores baseUrl', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ApiUrlNotifier();
      await Future(() {});

      await notifier.setUrl('http://other:8080');
      expect(notifier.state, 'http://other:8080');

      await notifier.resetToDefault();
      expect(notifier.state, ApiConfig.baseUrl);
    });

    test('loads persisted URL from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'custom_api_url': 'http://192.168.1.50:9090'});
      final notifier = ApiUrlNotifier();
      await Future(() {});
      expect(notifier.state, 'http://192.168.1.50:9090');
    });

    test('ignores empty stored URL', () async {
      SharedPreferences.setMockInitialValues({'custom_api_url': ''});
      final notifier = ApiUrlNotifier();
      await Future(() {});
      expect(notifier.state, ApiConfig.baseUrl);
    });
  });
}
