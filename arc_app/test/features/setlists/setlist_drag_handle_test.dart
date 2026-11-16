import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

/// Saves a new order, like the server does.
class _Reorderable extends FakeSetlistRepository {
  _Reorderable(super.setlists);

  @override
  Future<void> reorder({required int setlistId, required List<int> setlistSongIds}) async {
    final setlist = setlists[setlistId]!;
    final byId = {for (final s in setlist.songs) s.id: s};
    setlists[setlistId] = Setlist(
      id: setlist.id,
      serviceDate: setlist.serviceDate,
      name: setlist.name,
      songs: [for (final id in setlistSongIds) byId[id]!],
      annexId: setlist.annexId,
    );
  }
}

Future<void> showSetlist(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setlistRepositoryProvider.overrideWithValue(_Reorderable([
          sampleSetlist(songs: const [('Sublime Gracia', 'G'), ('Digno', 'E')]),
        ])),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: const SetlistDetailScreen(setlistId: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  for (final (label, size) in [('desktop', const Size(1200, 1000)), ('phone', const Size(390, 844))]) {
    testWidgets('each song has one drag handle, at the far left ($label)', (tester) async {
      await showSetlist(tester, size);

      // Only ours: no extra handle added on the right over the remove button.
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      final handles = find.byIcon(Icons.drag_indicator);
      expect(handles, findsNWidgets(2));

      final handle = tester.getCenter(handles.first);
      final number = tester.getCenter(find.text('1'));
      final remove = tester.getRect(find.byTooltip('Quitar del setlist').first);
      expect(handle.dx, lessThan(number.dx));
      expect(remove.contains(handle), isFalse);
    });
  }

  testWidgets('dragging by the handle reorders the songs', (tester) async {
    await showSetlist(tester, const Size(1200, 1000));

    final handle = find.byIcon(Icons.drag_indicator).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.text('Digno')).dy;
    final second = tester.getTopLeft(find.text('Sublime Gracia')).dy;
    expect(first, lessThan(second));
  });
}
