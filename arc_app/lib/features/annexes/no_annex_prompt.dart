import 'package:flutter/material.dart';

import '../../core/theme/arca_tokens.dart';

/// Shown instead of setlists or pins while the user belongs to no annex.
class NoAnnexPrompt extends StatelessWidget {
  const NoAnnexPrompt({super.key, required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 40, color: context.arca.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Todavía no estás en ningún anexo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Unite al de tu equipo para ver y armar sus setlists.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.arca.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onChoose, child: const Text('Elegir anexos')),
          ],
        ),
      ),
    );
  }
}
