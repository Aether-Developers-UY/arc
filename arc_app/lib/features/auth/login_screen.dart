import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_logo.dart';
import '../../core/widgets/theme_mode_menu.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final form = _LoginForm(
      emailController: _emailController,
      passwordController: _passwordController,
      onSubmit: _submit,
      showLogo: !wide,
    );

    return Scaffold(
      body: Stack(
        children: [
          wide
              ? Row(
                  children: [
                    const Expanded(child: _BrandPanel()),
                    Expanded(child: Center(child: form)),
                  ],
                )
              : SafeArea(child: Center(child: SingleChildScrollView(child: form))),
          // Lets people pick Claro / Oscuro before signing in.
          const Positioned(
            top: 8,
            right: 8,
            child: SafeArea(child: ThemeModeMenu()),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    // Verde noche (the church site's footer) in light mode; in dark mode a
    // charcoal a step deeper than the background, so the panel still reads
    // as its own area. The logo and text go cream on both.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFFF0EDE4);
    final subtitle = isDark ? context.arca.textSecondary : const Color(0xFFC9C0AE);

    return Container(
      color: isDark ? const Color(0xFF18191C) : const Color(0xFF353C2D),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ArcaLogo(size: 64, showWordmark: true, wordmarkColor: title, markColor: const Color(0xFFF0EDE4)),
          const SizedBox(height: 32),
          Text(
            'Las canciones del ministerio, listas para el servicio.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: title,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Letra, acordes y tonalidad en un solo lugar.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: subtitle,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends ConsumerWidget {
  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
    required this.showLogo,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final bool showLogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLogo) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: ArcaLogo(size: 48, showWordmark: true),
              ),
              const SizedBox(height: 32),
            ],
            Text('Ingresá a Arca', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Usá tu correo y contraseña.',
              style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 20),
            if (authState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  authState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: authState.isLoading ? null : onSubmit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
          ],
        ),
      ),
    );
  }
}
