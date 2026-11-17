import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final centro = Annex(id: 3, name: 'Centro');
final norte = Annex(id: 7, name: 'Norte');

/// Signed in as a user who belongs to [annexes].
class FakeAuth extends AuthNotifier {
  FakeAuth(this.annexes);
  final List<Annex> annexes;

  @override
  AuthState build() =>
      AuthState(user: AuthUser(id: 1, name: 'Ana', username: 'ana', annexes: annexes));
}

Future<ProviderContainer> containerWith(List<Annex> annexes, {int? stored}) async {
  SharedPreferences.setMockInitialValues({'active_annex_id': ?stored});
  final container = ProviderContainer(
    overrides: [authProvider.overrideWith(() => FakeAuth(annexes))],
  );
  addTearDown(container.dispose);
  await container.read(activeAnnexProvider.notifier).ready;
  return container;
}

void main() {
  test('active annex defaults to my first annex', () async {
    final container = await containerWith([centro, norte]);

    expect(container.read(activeAnnexProvider), centro);
  });

  test('active annex restores the stored one', () async {
    final container = await containerWith([centro, norte], stored: 7);

    expect(container.read(activeAnnexProvider), norte);
  });

  test('active annex falls back when it is no longer mine', () async {
    final container = await containerWith([centro], stored: 9);

    expect(container.read(activeAnnexProvider), centro);
  });

  test('active annex is null without annexes', () async {
    final container = await containerWith([]);

    expect(container.read(activeAnnexProvider), isNull);
  });

  test('select persists the choice', () async {
    final container = await containerWith([centro, norte]);

    await container.read(activeAnnexProvider.notifier).select(norte);

    expect(container.read(activeAnnexProvider), norte);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('active_annex_id'), 7);
  });

  test('AuthUser.fromJson reads role and annexes', () {
    final user = AuthUser.fromJson({
      'id': 1,
      'name': 'Ana',
      'username': 'ana',
      'role': 'admin',
      'annexes': [
        {'id': 3, 'name': 'Centro'},
      ],
    });

    expect(user.isAdmin, isTrue);
    expect(user.annexes.single.name, 'Centro');
    expect(user.annexes.single.isMember, isTrue);
  });

  test('isAdmin is false for standard users and missing roles', () {
    expect(AuthUser.fromJson({'id': 1, 'name': 'A', 'username': 'a', 'role': 'standard'}).isAdmin,
        isFalse);
    expect(AuthUser(id: 1, name: 'A', username: 'a').isAdmin, isFalse);
  });
}
