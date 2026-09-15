import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import 'auth_repository.dart';

final tokenStorageProvider = Provider((ref) => TokenStorage(const FlutterSecureStorage()));

final apiClientProvider = Provider((ref) => ApiClient(ref.watch(tokenStorageProvider)));

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
  AuthState build() => const AuthState();

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await ref.read(authRepositoryProvider).login(email: email, password: password);
      state = AuthState(user: user);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
