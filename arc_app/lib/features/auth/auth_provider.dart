import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import 'auth_repository.dart';

final tokenStorageProvider = Provider((ref) => TokenStorage(const FlutterSecureStorage()));

final apiClientProvider = Provider(
  (ref) => ApiClient(
    ref.watch(tokenStorageProvider),
    // The server ended the session (password reset, user deleted).
    onUnauthorized: () => ref.read(authProvider.notifier).sessionExpired(),
  ),
);

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isLoggedIn => user != null;

  AuthState copyWith({AuthUser? user, bool? isLoading, String? errorMessage}) => AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState(isLoading: true);
  }

  Future<void> _restoreSession() async {
    final repository = ref.read(authRepositoryProvider);
    try {
      if (!await repository.hasStoredToken()) {
        state = const AuthState();
        return;
      }
      final user = await repository.currentUser();
      state = AuthState(user: user);
    } catch (_) {
      // No stored token, an invalid/expired one, or the secure-storage
      // platform channel is unavailable (e.g. in widget tests) — in every
      // case, fall back to starting logged out rather than crashing.
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await ref.read(authRepositoryProvider).login(email: email, password: password);
      state = AuthState(user: user);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  /// Reloads the user from `/me`, e.g. after joining or leaving an annex.
  Future<void> refreshUser() async {
    final user = await ref.read(authRepositoryProvider).currentUser();
    state = AuthState(user: user);
  }

  /// Back to the login screen without calling the server, whose session
  /// is already gone.
  Future<void> sessionExpired() async {
    if (!state.isLoggedIn) return;
    state = const AuthState();
    await ref.read(tokenStorageProvider).clear();
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
