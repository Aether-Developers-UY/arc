import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/arca_tokens.dart';
import '../theme/theme_mode_provider.dart';

const _labels = {
  ThemeMode.system: 'Sistema',
  ThemeMode.light: 'Claro',
  ThemeMode.dark: 'Oscuro',
};

const _icons = {
  ThemeMode.system: Icons.brightness_auto_outlined,
  ThemeMode.light: Icons.light_mode_outlined,
  ThemeMode.dark: Icons.dark_mode_outlined,
};

/// Picks Sistema / Claro / Oscuro. As an icon in the app bar, or as a full
/// row ("Tema · Oscuro") in the sidebar when [expanded].
class ThemeModeMenu extends ConsumerWidget {
  const ThemeModeMenu({super.key, this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Tema',
      position: PopupMenuPosition.under,
      onSelected: (m) => ref.read(themeModeProvider.notifier).select(m),
      itemBuilder: (_) => [
        for (final m in ThemeMode.values)
          CheckedPopupMenuItem(value: m, checked: m == mode, child: Text(_labels[m]!)),
      ],
      icon: expanded ? null : Icon(_icons[mode]),
      child: expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(_icons[mode], color: scheme.onSurface, size: 22),
                  const SizedBox(width: 12),
                  Text('Tema', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(_labels[mode]!, style: TextStyle(color: context.arca.textSecondary)),
                ],
              ),
            )
          : null,
    );
  }
}
