import 'package:flutter/material.dart';

import '../theme/arca_theme.dart';

/// Small pill showing a musical key (e.g. "G", "Bb").
class KeyBadge extends StatelessWidget {
  const KeyBadge(this.musicalKey, {super.key});

  final String musicalKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        musicalKey,
        style: ArcaTheme.mono(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}
