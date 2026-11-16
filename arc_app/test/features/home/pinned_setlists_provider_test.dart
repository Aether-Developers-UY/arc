import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/home/pinned_setlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_test_helpers.dart';

/// Where the pins of [testAnnex] (id 1) are stored.
const _key = 'pinned_setlist_ids_1';
const _legacyKey = 'pinned_setlist_ids';

Future<ProviderContainer> containerWith(
  Map<String, Object> stored, {
  bool withoutAnnex = false,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final container = ProviderContainer(
    overrides: [
      activeAnnexProvider.overrideWith(() => FixedActiveAnnex(withoutAnnex ? null : testAnnex)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(pinnedSetlistsProvider.future);
  return container;
}

/// Makes [annex] the active one and waits for its pins to load.
Future<void> switchTo(ProviderContainer container, Annex annex) async {
  (container.read(activeAnnexProvider.notifier) as FixedActiveAnnex).set(annex);
  await container.read(pinnedSetlistsProvider.future);
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
    final container = await containerWith({
      _key: ['1', '2'],
    });

    await container.read(pinnedSetlistsProvider.notifier).unpin(1);

    expect(container.read(pinnedSetlistsProvider).value, [2]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_key), ['2']);
  });

  test('unpin of an unknown id does nothing', () async {
    final container = await containerWith({
      _key: ['1'],
    });

    await container.read(pinnedSetlistsProvider.notifier).unpin(9);

    expect(container.read(pinnedSetlistsProvider).value, [1]);
  });

  test('reloads the stored ids', () async {
    final container = await containerWith({
      _key: ['7', '9'],
    });

    expect(container.read(pinnedSetlistsProvider).value, [7, 9]);
  });

  test('ignores corrupt, repeated and extra stored values', () async {
    final container = await containerWith({
      _key: ['1', 'x', '1', '2', '3', '4'],
    });

    expect(container.read(pinnedSetlistsProvider).value, [1, 2, 3]);
  });

  test('pins are stored per annex', () async {
    final container = await containerWith({});
    await container.read(pinnedSetlistsProvider.notifier).pin(4);

    await switchTo(container, Annex(id: 7, name: 'Norte'));
    expect(container.read(pinnedSetlistsProvider).value, isEmpty);
    await container.read(pinnedSetlistsProvider.notifier).pin(9);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_key), ['4']);
    expect(prefs.getStringList('pinned_setlist_ids_7'), ['9']);
  });

  test('the cap of 3 is per annex', () async {
    final container = await containerWith({
      _key: ['1', '2', '3'],
    });

    await switchTo(container, Annex(id: 7, name: 'Norte'));
    for (final id in [4, 5, 6]) {
      await container.read(pinnedSetlistsProvider.notifier).pin(id);
    }

    expect(container.read(pinnedSetlistsProvider).value, [4, 5, 6]);
  });

  test('legacy pins move to the first annex that loads', () async {
    final container = await containerWith({
      _legacyKey: ['5', '6'],
    });

    expect(container.read(pinnedSetlistsProvider).value, [5, 6]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_key), ['5', '6']);
    expect(prefs.containsKey(_legacyKey), isFalse);
  });

  test('switching annex keeps the other annex pins', () async {
    final container = await containerWith({
      _key: ['4'],
    });

    await switchTo(container, Annex(id: 7, name: 'Norte'));
    await switchTo(container, testAnnex);

    expect(container.read(pinnedSetlistsProvider).value, [4]);
  });

  test('no pins without an annex', () async {
    final container = await containerWith({
      _legacyKey: ['5'],
    }, withoutAnnex: true);

    expect(container.read(pinnedSetlistsProvider).value, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_legacyKey), ['5'], reason: 'kept for when they join one');
  });
}
