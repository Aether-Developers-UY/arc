import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/admin/admin_repository.dart';
import 'package:arc_app/features/admin/admin_screen.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/annexes/annex_repository.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../annexes/my_annexes_screen_test.dart' show FakeAnnexRepository, RepoAuth;

class FakeAdminRepository implements AdminRepository {
  final List<AdminUser> people = [
    AdminUser(id: 1, name: 'Ana', email: 'ana@arc.local', role: 'admin'),
    AdminUser(id: 2, name: 'Beto', email: 'beto@arc.local', role: 'standard'),
  ];
  final List<String> calls = [];
  AdminException? nextError;
  FakeAnnexRepository? annexes;

  void _maybeFail() {
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
  }

  @override
  Future<List<AdminUser>> users() async => List.of(people);

  @override
  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    calls.add('create $name $email $password $role');
    _maybeFail();
    people.add(AdminUser(id: people.length + 1, name: name, email: email, role: role));
  }

  @override
  Future<void> updateUser(int id, {String? name, String? email, String? role, String? password}) async {
    calls.add('update $id ${[name, email, role, password].whereType<String>().join(' ')}');
    _maybeFail();
  }

  @override
  Future<void> deleteUser(int id) async {
    calls.add('delete $id');
    _maybeFail();
    people.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> createAnnex(String name) async {
    calls.add('createAnnex $name');
    _maybeFail();
    annexes!.all.add(Annex(id: 50, name: name));
  }

  @override
  Future<void> renameAnnex(int id, String name) async {
    calls.add('renameAnnex $id $name');
    _maybeFail();
    final i = annexes!.all.indexWhere((a) => a.id == id);
    annexes!.all[i] = Annex(id: id, name: name);
  }

  @override
  Future<void> deleteAnnex(int id) async {
    calls.add('deleteAnnex $id');
    _maybeFail();
    annexes!.all.removeWhere((a) => a.id == id);
  }
}

late FakeAdminRepository admin;

Future<void> pumpAdmin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final annexes = FakeAnnexRepository([Annex(id: 3, name: 'Centro')], {3});
  admin = FakeAdminRepository()..annexes = annexes;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(admin),
        annexRepositoryProvider.overrideWithValue(annexes),
        authProvider.overrideWith(() => RepoAuth(annexes)),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: const Scaffold(body: AdminScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, String name, String action) async {
  await tester.tap(find.byTooltip('Acciones de $name'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextField, label), text);

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('lists users', (tester) async {
    await pumpAdmin(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('beto@arc.local'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('creates a user', (tester) async {
    await pumpAdmin(tester);

    await tester.tap(find.text('Nuevo usuario'));
    await tester.pumpAndSettle();
    await fill(tester, 'Nombre', 'Caro');
    await fill(tester, 'Correo', 'caro@arc.local');
    await fill(tester, 'Contraseña', 'alabanza1');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(admin.calls, ['create Caro caro@arc.local alabanza1 standard']);
    expect(find.text('Caro'), findsOneWidget);
  });

  testWidgets('resetting a password sends it', (tester) async {
    await pumpAdmin(tester);

    await openMenu(tester, 'Beto', 'Restablecer contraseña');
    await fill(tester, 'Nueva contraseña', 'nuevaClave9');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(admin.calls, ['update 2 nuevaClave9']);
    expect(find.text('Contraseña actualizada. Se cerraron sus sesiones.'), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation', (tester) async {
    await pumpAdmin(tester);

    await openMenu(tester, 'Beto', 'Borrar');
    expect(find.text('¿Borrar a Beto?'), findsOneWidget);
    expect(find.text('Sus canciones y setlists se conservan.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(admin.calls, ['delete 2']);
    expect(find.text('Beto'), findsNothing);
  });

  testWidgets('shows the server message', (tester) async {
    await pumpAdmin(tester);
    admin.nextError = AdminException('No podés quitar el rol al último admin.');

    await openMenu(tester, 'Ana', 'Editar');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('No podés quitar el rol al último admin.'), findsOneWidget);
  });

  testWidgets('creates, renames and deletes an annex', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('Anexos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo anexo'));
    await tester.pumpAndSettle();
    await fill(tester, 'Nombre del anexo', 'Norte');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Norte'), findsOneWidget);

    await openMenu(tester, 'Norte', 'Renombrar');
    await fill(tester, 'Nombre del anexo', 'Zona Norte');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Zona Norte'), findsOneWidget);

    await openMenu(tester, 'Zona Norte', 'Borrar');
    expect(find.text('¿Borrar «Zona Norte»?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(admin.calls, ['createAnnex Norte', 'renameAnnex 50 Zona Norte', 'deleteAnnex 50']);
    expect(find.text('Zona Norte'), findsNothing);
  });

  testWidgets('deleting an annex with setlists shows the server message', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('Anexos'));
    await tester.pumpAndSettle();
    admin.nextError = AdminException('Este anexo tiene setlists; borralos antes.');

    await openMenu(tester, 'Centro', 'Borrar');
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(find.text('Este anexo tiene setlists; borralos antes.'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
  });
}
