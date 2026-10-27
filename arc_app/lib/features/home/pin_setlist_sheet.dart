import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../setlists/setlist_list_provider.dart';
import 'pinned_setlists_provider.dart';

/// Lets the user pick a setlist to pin to Inicio, newest first, leaving out
/// the ones already pinned.
Future<void> showPinSetlistSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _PinSetlistSheet(),
  );
}

class _PinSetlistSheet extends ConsumerWidget {
  const _PinSetlistSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedSetlistsProvider).value ?? const <int>[];
    final setlistsAsync = ref.watch(setlistListProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('Fijar setlist', style: Theme.of(context).textTheme.titleLarge),
          ),
          Flexible(
            child: setlistsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const _SheetMessage('No se pudieron cargar los setlists'),
              data: (setlists) {
                if (setlists.isEmpty) {
                  return const _SheetMessage('Primero creá un setlist en la pestaña Setlists.');
                }
                final available = setlists.where((s) => !pinned.contains(s.id)).toList()
                  ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
                if (available.isEmpty) {
                  return const _SheetMessage('Ya fijaste todos tus setlists.');
                }
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final setlist in available)
                      ListTile(
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(
                          setlist.name?.isNotEmpty == true
                              ? setlist.name!
                              : weekdayName(setlist.serviceDate),
                        ),
                        subtitle: Text(
                          '${weekdayName(setlist.serviceDate)} · ${shortDate(setlist.serviceDate)}',
                        ),
                        onTap: () async {
                          await ref.read(pinnedSetlistsProvider.notifier).pin(setlist.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.arca.textSecondary),
      ),
    );
  }
}
