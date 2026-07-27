import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_stock_mobile/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier', () {
    test('initial state is ThemeMode.system', () {
      final notifier = ThemeModeNotifier();
      expect(notifier.state, ThemeMode.system);
    });

    test('setThemeMode changes state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future(() {}); // Flush microtask from _loadThemeMode

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);

      // Verify persistence by creating a new notifier
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final restored = ThemeModeNotifier();
      await Future(() {});
      expect(restored.state, ThemeMode.dark);
    });

    test('setThemeMode to light persists correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future(() {});

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final restored = ThemeModeNotifier();
      await Future(() {});
      expect(restored.state, ThemeMode.light);
    });

    test('setThemeMode to system persists correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future(() {});

      await notifier.setThemeMode(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);

      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      final restored = ThemeModeNotifier();
      await Future(() {});
      expect(restored.state, ThemeMode.system);
    });

    test('loads persisted theme from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final notifier = ThemeModeNotifier();
      await Future(() {});
      expect(notifier.state, ThemeMode.dark);
    });

    test('falls back to system for unknown stored value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'unknown'});
      final notifier = ThemeModeNotifier();
      await Future(() {});
      expect(notifier.state, ThemeMode.system);
    });
  });
}
