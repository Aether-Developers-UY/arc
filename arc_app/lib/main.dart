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

    return MaterialApp(
      title: 'Arc',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: authState.isLoggedIn ? const _PlaceholderHome() : const LoginScreen(),
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
