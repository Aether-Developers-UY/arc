import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/core/theme/theme_mode_provider.dart';
import 'package:arc_app/core/widgets/app_shell.dart';
import 'package:arc_app/features/admin/admin_repository.dart';
import 'package:arc_app/features/annexes/annex_repository.dart';
import 'package:arc_app/features/annexes/my_annexes_screen.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/auth_repository.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/admin/admin_screen_test.dart' show FakeAdminRepository;
import '../../features/annexes/my_annexes_screen_test.dart' show FakeAnnexRepository;
import '../../features/home/home_test_helpers.dart';

class _LoggedInAuth extends AuthNotifier {
  _LoggedInAuth({this.role = 'standard'});
  final String role;

  @override
  AuthState build() => AuthState(
        user: AuthUser(
          id: 1,
          name: 'Test',
          email: 'test@arc.local',
          role: role,
          annexes: [testAnnex],
        ),
      );
}

class _NoSongs extends SongListNotifier {
  @override
  Future<List<Song>> build() async => [];
}

const _songsSubtitle = 'El repertorio del ministerio';
const _setlistsSubtitle = 'Las canciones de cada servicio';

Future<FakeSetlistRepository> pumpShell(
  WidgetTester tester, {
  required Size size,
  List<int> pinned = const [],
  bool asAdmin = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'pinned_setlist_ids': [for (final id in pinned) '$id'],
  });
  final repository = FakeSetlistRepository([sampleSetlist(id: 1, name: 'Culto viejo')]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _LoggedInAuth(role: asAdmin ? 'admin' : 'standard')),
        songListProvider.overrideWith(_NoSongs.new),
        setlistRepositoryProvider.overrideWithValue(repository),
        annexRepositoryProvider.overrideWithValue(FakeAnnexRepository([testAnnex], {testAnnex.id})),
        adminRepositoryProvider.overrideWithValue(FakeAdminRepository()),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: const AppShell()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  for (final (label, size) in [('desktop', const Size(1200, 900)), ('phone', const Size(390, 844))]) {
    testWidgets('starts on Inicio, the first destination ($label)', (tester) async {
      await pumpShell(tester, size: size);

      expect(find.text('Todavía no elegiste un culto'), findsOneWidget);
      final inicio = tester.getTopLeft(find.text('Inicio').last);
      final canciones = tester.getTopLeft(find.text('Canciones'));
      // First item: above Canciones in the sidebar, left of it in the bottom bar.
      expect(inicio.dy < canciones.dy || inicio.dx < canciones.dx, isTrue);
    });
  }

  for (final (label, size) in [('desktop', const Size(1200, 900)), ('phone', const Size(390, 844))]) {
    testWidgets('the selector is visible ($label)', (tester) async {
      await pumpShell(tester, size: size);

      expect(find.text('Anexo principal'), findsOneWidget);
    });
  }

  for (final (label, size) in [('desktop', const Size(1200, 900)), ('phone', const Size(390, 844))]) {
    testWidgets('Mis anexos opens from the shell ($label)', (tester) async {
      await pumpShell(tester, size: size);

      await tester.tap(find.byTooltip('Mis anexos'));
      await tester.pumpAndSettle();

      expect(find.byType(MyAnnexesScreen), findsOneWidget);
    });
  }

  for (final (label, size) in [('desktop', const Size(1200, 900)), ('phone', const Size(390, 844))]) {
    testWidgets('the theme can be switched to dark from the shell ($label)', (tester) async {
      await pumpShell(tester, size: size);

      await tester.tap(find.byTooltip('Tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  }

  testWidgets('the Administración tab only shows for admins', (tester) async {
    await pumpShell(tester, size: const Size(1200, 900));

    expect(find.text('Administración'), findsNothing);
  });

  for (final (label, size, logo) in [('desktop', const Size(1200, 900), 46.0), ('phone', const Size(390, 844), 36.0)]) {
    testWidgets('the church logo is shown large ($label)', (tester) async {
      await pumpShell(tester, size: size);

      expect(tester.getSize(find.byType(Image).first), Size(logo, logo));
    });
  }

  testWidgets('on desktop the annex selector sits above the divider, over Mis anexos', (tester) async {
    await pumpShell(tester, size: const Size(1200, 900));

    final selector = tester.getTopLeft(find.text('Anexo principal')).dy;
    final divider = tester.getTopLeft(find.byType(Divider).first).dy;
    final setlists = tester.getTopLeft(find.text('Setlists')).dy;
    expect(selector, greaterThan(setlists));
    expect(selector, lessThan(divider));
  });

  testWidgets('on the phone the Arca name is larger', (tester) async {
    await pumpShell(tester, size: const Size(390, 844));

    expect(tester.widget<Text>(find.text('Arca')).style!.fontSize, 22);
  });

  testWidgets('admins get the Administración tab', (tester) async {
    await pumpShell(tester, size: const Size(1200, 900), asAdmin: true);

    expect(find.text('Administración'), findsOneWidget);
  });

  testWidgets('Biblioteca de canciones jumps to the Canciones tab', (tester) async {
    await pumpShell(tester, size: const Size(1200, 900));
    expect(find.text(_songsSubtitle), findsNothing);

    await tester.tap(find.text('Biblioteca de canciones'));
    await tester.pumpAndSettle();

    expect(find.text(_songsSubtitle), findsOneWidget);
  });

  testWidgets('Todos los setlists jumps to the Setlists tab', (tester) async {
    await pumpShell(tester, size: const Size(1200, 900));

    await tester.tap(find.text('Todos los setlists'));
    await tester.pumpAndSettle();

    expect(find.text(_setlistsSubtitle), findsOneWidget);
  });

  testWidgets('returning to Inicio refreshes the pinned setlists', (tester) async {
    final repository = await pumpShell(tester, size: const Size(1200, 900), pinned: [1]);
    expect(find.text('Culto viejo'), findsOneWidget);

    repository.setlists[1] = sampleSetlist(id: 1, name: 'Culto nuevo');
    await tester.tap(find.text('Setlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();

    expect(find.text('Culto nuevo'), findsOneWidget);
  });
}
