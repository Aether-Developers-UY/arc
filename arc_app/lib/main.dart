import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/arca_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'core/widgets/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: ArcApp()));
}

final _navigatorKey = GlobalKey<NavigatorState>();

class ArcApp extends ConsumerWidget {
  const ArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Signing out swaps the home screen, but screens pushed on top of it
    // (a setlist, an editor, a dialog) would stay open over the login:
    // close them all. Matters when the server ends the session mid-use.
    ref.listen(authProvider.select((s) => s.isLoggedIn), (wasLoggedIn, isLoggedIn) {
      if (wasLoggedIn == true && !isLoggedIn) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final Widget home;
    if (authState.isLoggedIn) {
      home = const AppShell();
    } else if (authState.isLoading) {
      // Still restoring a possibly-stored session — avoid flashing the
      // login screen before we know whether a valid token exists.
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Arca',
      debugShowCheckedModeBanner: false,
      theme: ArcaTheme.light(),
      darkTheme: ArcaTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: home,
    );
  }
}
