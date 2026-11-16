import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/setlists/setlist_editor_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_helpers.dart';

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('a new setlist is created in the active annex', (tester) async {
    final repository = FakeSetlistRepository([]);
    final norte = Annex(id: 7, name: 'Norte');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setlistRepositoryProvider.overrideWithValue(repository),
          activeAnnexProvider.overrideWith(() => FixedActiveAnnex(norte)),
        ],
        child: MaterialApp(theme: ArcaTheme.light(), home: const SetlistEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.createdInAnnexIds, [7]);
  });
}
