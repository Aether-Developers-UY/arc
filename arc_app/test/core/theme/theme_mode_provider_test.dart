import 'package:arc_app/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(themeModeProvider);
  await container.read(themeModeProvider.notifier).ready;
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('follows the system until the user picks a mode', () async {
    final container = await containerWith({});

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('a picked mode applies and is remembered', () async {
    final container = await containerWith({});

    await container.read(themeModeProvider.notifier).select(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('restores the stored mode on start', () async {
    final container = await containerWith({'theme_mode': 'light'});

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('an unknown stored value falls back to the system', () async {
    final container = await containerWith({'theme_mode': 'sepia'});

    expect(container.read(themeModeProvider), ThemeMode.system);
  });
}
