import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: ArcApp()));
}

class ArcApp extends ConsumerWidget {
  const ArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final Widget home;
    if (authState.isLoggedIn) {
      home = const _PlaceholderHome();
    } else if (authState.isLoading) {
      // Still restoring a possibly-stored session — avoid flashing the
      // login screen before we know whether a valid token exists.
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      title: 'Arc',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: home,
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Sesión iniciada')));
  }
}
