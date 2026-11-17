import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/page_header.dart';
import '../annexes/active_annex_provider.dart';
import '../annexes/no_annex_prompt.dart';
import 'pin_setlist_sheet.dart';
import 'pinned_setlist_card.dart';
import 'pinned_setlists_provider.dart';

/// Inicio: the setlists pinned on this device, shortcuts to the library
/// and the setlists, and room for future sections.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSongs,
    required this.onOpenLines,
    required this.onOpenSetlists,
    required this.onChooseAnnexes,
  });

  final VoidCallback onOpenSongs;
  final VoidCallback onOpenLines;
  final VoidCallback onOpenSetlists;

  /// Opens Mis anexos, from the prompt shown while the user has none.
  final VoidCallback onChooseAnnexes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWide(context);
    final shortcuts = [
      _ShortcutCard(
        icon: Icons.library_music_outlined,
        label: 'Biblioteca de canciones',
        onTap: onOpenSongs,
      ),
      _ShortcutCard(
        icon: Icons.queue_music_outlined,
        label: 'Biblioteca de líneas',
        onTap: onOpenLines,
      ),
      _ShortcutCard(
        icon: Icons.event_note_outlined,
        label: 'Todos los setlists',
        onTap: onOpenSetlists,
      ),
    ];

    return ContentFrame(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const PageHeader(title: 'Inicio', subtitle: 'Tus cultos a mano'),
          Text('Fijados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (ref.watch(activeAnnexProvider) == null)
            _OutlinedBlock(child: NoAnnexPrompt(onChoose: onChooseAnnexes))
          else
            ref
                .watch(pinnedSetlistsProvider)
                .when(
                  // Never show the empty state before the stored ids are read.
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => _EmptyPins(onOpenSetlists: onOpenSetlists),
                  data: (ids) => ids.isEmpty
                      ? _EmptyPins(onOpenSetlists: onOpenSetlists)
                      : _PinnedRow(ids: ids, wide: wide, onOpenSetlists: onOpenSetlists),
                ),
          const SizedBox(height: 28),
          if (wide)
            Row(
              children: [
                for (var i = 0; i < shortcuts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: shortcuts[i]),
                ],
              ],
            )
          else
            for (final shortcut in shortcuts)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: shortcut),
        ],
      ),
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.ids, required this.wide, required this.onOpenSetlists});

  final List<int> ids;
  final bool wide;
  final VoidCallback onOpenSetlists;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[
      for (final id in ids) PinnedSetlistCard(key: ValueKey(id), setlistId: id),
      if (ids.length < kMaxPinnedSetlists) _AddPinBlock(onOpenSetlists: onOpenSetlists),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < kMaxPinnedSetlists; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            // Empty slots keep each block at a third of the row.
            Expanded(child: i < blocks.length ? blocks[i] : const SizedBox()),
          ],
        ],
      );
    }

    // On phones the row scrolls sideways, with the next block peeking in.
    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = constraints.maxWidth * 0.7;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                SizedBox(width: blockWidth, child: blocks[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AddPinBlock extends StatelessWidget {
  const _AddPinBlock({required this.onOpenSetlists});

  final VoidCallback onOpenSetlists;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OutlinedBlock(
      onTap: () => showPinSetlistSheet(context, onOpenSetlists: onOpenSetlists),
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '+ Fijar setlist',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _EmptyPins extends StatelessWidget {
  const _EmptyPins({required this.onOpenSetlists});

  final VoidCallback onOpenSetlists;

  @override
  Widget build(BuildContext context) {
    return _OutlinedBlock(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.push_pin_outlined, color: context.arca.textSecondary),
            const SizedBox(height: 8),
            Text(
              'Todavía no elegiste un culto',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => showPinSetlistSheet(context, onOpenSetlists: onOpenSetlists),
              child: const Text('Elegir setlist'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A transparent, outlined block for placeholders (no pins, add, coming soon).
class _OutlinedBlock extends StatelessWidget {
  const _OutlinedBlock({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: context.arca.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ArcaCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right, color: context.arca.textSecondary),
        ],
      ),
    );
  }
}
