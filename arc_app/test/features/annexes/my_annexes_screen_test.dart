import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/annexes/annex_repository.dart';
import 'package:arc_app/features/annexes/my_annexes_screen.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart' show networkError;

/// Annexes in memory; [members] are the ids the user belongs to.
class FakeAnnexRepository implements AnnexRepository {
  FakeAnnexRepository(this.all, this.members);

  final List<Annex> all;
  final Set<int> members;
  bool fail = false;
  final List<String> calls = [];

  @override
  Future<List<Annex>> list() async => [
        for (final a in all) Annex(id: a.id, name: a.name, isMember: members.contains(a.id)),
      ];

  @override
  Future<void> join(int id) async {
    calls.add('join $id');
    if (fail) throw networkError();
    members.add(id);
  }

  @override
  Future<void> leave(int id) async {
    calls.add('leave $id');
    if (fail) throw networkError();
    members.remove(id);
  }
}

/// A signed-in user whose annexes follow the fake repository on refresh.
class RepoAuth extends AuthNotifier {
  RepoAuth(this.repository);
  final FakeAnnexRepository repository;
  int refreshes = 0;

  AuthUser _user() => AuthUser(
        id: 1,
        name: 'Ana',
        username: 'ana',
        annexes: [for (final a in repository.all) if (repository.members.contains(a.id)) a],
      );

  @override
  AuthState build() => AuthState(user: _user());

  @override
  Future<void> refreshUser() async {
    refreshes++;
    state = AuthState(user: _user());
  }
}

final centro = Annex(id: 3, name: 'Centro');
final norte = Annex(id: 7, name: 'Norte');

late RepoAuth auth;

Future<ProviderContainer> pumpScreen(WidgetTester tester, FakeAnnexRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  auth = RepoAuth(repository);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        annexRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => auth),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: const MyAnnexesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MyAnnexesScreen)));
}

bool switchOf(WidgetTester tester, String name) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, name))
    .value;

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('lists annexes with my membership', (tester) async {
    await pumpScreen(tester, FakeAnnexRepository([centro, norte], {3}));

    expect(switchOf(tester, 'Centro'), isTrue);
    expect(switchOf(tester, 'Norte'), isFalse);
  });

  testWidgets('joining calls the repository and refreshes the user', (tester) async {
    final repository = FakeAnnexRepository([centro, norte], {3});
    await pumpScreen(tester, repository);

    await tester.tap(find.text('Norte'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['join 7']);
    expect(auth.refreshes, 1);
    expect(switchOf(tester, 'Norte'), isTrue);
  });

  testWidgets('leaving the active annex moves to another', (tester) async {
    final repository = FakeAnnexRepository([centro, norte], {3, 7});
    final container = await pumpScreen(tester, repository);
    await container.read(activeAnnexProvider.notifier).ready;
    expect(container.read(activeAnnexProvider), centro);

    await tester.tap(find.text('Centro'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['leave 3']);
    expect(container.read(activeAnnexProvider), norte);
  });

  testWidgets('a failed change reverts the switch', (tester) async {
    final repository = FakeAnnexRepository([centro, norte], {3})..fail = true;
    await pumpScreen(tester, repository);

    await tester.tap(find.text('Norte'));
    await tester.pumpAndSettle();

    expect(switchOf(tester, 'Norte'), isFalse);
    expect(find.text('No se pudo actualizar el anexo.'), findsOneWidget);
  });

  testWidgets('empty state when there are no annexes', (tester) async {
    await pumpScreen(tester, FakeAnnexRepository([], {}));

    expect(find.text('Todavía no hay anexos. Pedile al admin que cree uno.'), findsOneWidget);
  });
}
