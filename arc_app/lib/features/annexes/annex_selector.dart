import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../auth/auth_provider.dart';
import 'active_annex_provider.dart';
import 'annex.dart';

const _manage = 'manage';

/// "⛪ Centro ▾" — always shows where the user is standing, and lets
/// them switch annex or go manage their annexes. With a single annex the
/// arrow goes away but the menu still opens, to reach "Gestionar".
class AnnexSelector extends ConsumerWidget {
  const AnnexSelector({super.key, required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAnnexProvider);
    final annexes = ref.watch(authProvider.select((s) => s.user?.annexes ?? const <Annex>[]));
    final scheme = Theme.of(context).colorScheme;
    // Icon and name share one colour.
    final color = active == null ? context.arca.textSecondary : scheme.onSurface;

    return PopupMenuButton<Object>(
      tooltip: 'Cambiar de anexo',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == _manage) {
          onManage();
        } else if (value is Annex) {
          ref.read(activeAnnexProvider.notifier).select(value);
        }
      },
      itemBuilder: (context) => [
        for (final annex in annexes)
          CheckedPopupMenuItem<Object>(
            value: annex,
            checked: annex == active,
            child: Text(annex.name),
          ),
        if (annexes.isNotEmpty) const PopupMenuDivider(),
        const PopupMenuItem<Object>(
          value: _manage,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.groups_outlined),
            title: Text('Gestionar mis anexos'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.church_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                active == null ? 'Sin anexo' : active.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (annexes.length > 1) const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}
