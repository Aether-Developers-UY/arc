import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/auth_repository.dart';
import 'package:arc_app/features/home/home_screen.dart';
import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/setlists/setlist_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

final centro = Annex(id: 1, name: 'Centro');
final norte = Annex(id: 7, name: 'Norte');

/// Signed in as a member of Centro and Norte, but the server already took
/// them out of Centro (from another device): /me answers with Norte only.
class LeftCentroElsewhere extends AuthNotifier {
  int refreshes = 0;

  @override
  AuthState build() =>
      AuthState(user: AuthUser(id: 1, name: 'Ana', username: 'ana', annexes: [centro, norte]));

  @override
  Future<void> refreshUser() async {
    refreshes++;
    state = AuthState(user: AuthUser(id: 1, name: 'Ana', username: 'ana', annexes: [norte]));
  }
}

/// Answers 404 for Centro's setlists, as the server does for non-members.
class CentroGoneRepository extends FakeSetlistRepository {
  CentroGoneRepository() : super([]);

  @override
  Future<List<Setlist>> list({int? annexId}) async {
    listedAnnexIds.add(annexId);
    if (annexId == centro.id) throw httpError(404);
    return [sampleSetlist(id: 70, name: 'Culto del Norte')];
  }
}

late LeftCentroElsewhere auth;

Future<void> pump(WidgetTester tester, Widget child, {Map<String, Object> stored = const {}}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(stored);
  auth = LeftCentroElsewhere();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => auth),
        setlistRepositoryProvider.overrideWithValue(CentroGoneRepository()),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('a lost active annex moves the list to another annex', (tester) async {
    await pump(tester, SetlistListScreen(onChooseAnnexes: () {}));

    expect(auth.refreshes, 1);
    expect(find.text('No se pudieron cargar los setlists'), findsNothing);
    expect(find.text('Culto del Norte'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(SetlistListScreen)));
    expect(container.read(activeAnnexProvider), norte);
  });

  testWidgets('a lost annex keeps its pins', (tester) async {
    await pump(
      tester,
      HomeScreen(onOpenSongs: () {}, onOpenLines: () {}, onOpenSetlists: () {}, onChooseAnnexes: () {}),
      stored: {'pinned_setlist_ids_1': ['5']},
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pinned_setlist_ids_1'), ['5']);
  });
}
