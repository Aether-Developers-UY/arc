import 'package:arc_app/features/home/pinned_setlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'pinned_setlist_ids';

Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(pinnedSetlistsProvider.future);
  return container;
}

void main() {
  test('starts empty when nothing is stored', () async {
    final container = await containerWith({});

    expect(container.read(pinnedSetlistsProvider).value, isEmpty);
  });

  test('pin adds ids in order and persists them', () async {
    final container = await containerWith({});
    final notifier = container.read(pinnedSetlistsProvider.notifier);

    await notifier.pin(4);
    await notifier.pin(2);

    expect(container.read(pinnedSetlistsProvider).value, [4, 2]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_key), ['4', '2']);
  });

  test('pin ignores duplicates', () async {
    final container = await containerWith({});
    final notifier = container.read(pinnedSetlistsProvider.notifier);

    await notifier.pin(4);
    await notifier.pin(4);

    expect(container.read(pinnedSetlistsProvider).value, [4]);
  });

  test('pin ignores a fourth id', () async {
    final container = await containerWith({});
    final notifier = container.read(pinnedSetlistsProvider.notifier);

    for (final id in [1, 2, 3, 4]) {
      await notifier.pin(id);
    }

    expect(container.read(pinnedSetlistsProvider).value, [1, 2, 3]);
  });

  test('unpin removes the id and persists', () async {
    final container = await containerWith({_key: ['1', '2']});

    await container.read(pinnedSetlistsProvider.notifier).unpin(1);

    expect(container.read(pinnedSetlistsProvider).value, [2]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_key), ['2']);
  });

  test('unpin of an unknown id does nothing', () async {
    final container = await containerWith({_key: ['1']});

    await container.read(pinnedSetlistsProvider.notifier).unpin(9);

    expect(container.read(pinnedSetlistsProvider).value, [1]);
  });

  test('reloads the stored ids', () async {
    final container = await containerWith({_key: ['7', '9']});

    expect(container.read(pinnedSetlistsProvider).value, [7, 9]);
  });

  test('ignores corrupt, repeated and extra stored values', () async {
    final container = await containerWith({_key: ['1', 'x', '1', '2', '3', '4']});

    expect(container.read(pinnedSetlistsProvider).value, [1, 2, 3]);
  });
}
