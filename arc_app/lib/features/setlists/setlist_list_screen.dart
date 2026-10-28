import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/view_mode.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/view_mode_toggle.dart';
import 'setlist.dart';
import 'setlist_block.dart';
import 'setlist_detail_screen.dart';
import 'setlist_editor_screen.dart';
import 'setlist_list_provider.dart';

const _viewModeKey = 'setlist_list_view';

class SetlistListScreen extends ConsumerWidget {
  const SetlistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistListProvider);
    final viewMode = ref.watch(viewModeProvider(_viewModeKey)).value ?? ViewMode.grid;

    return ContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Setlists',
            subtitle: 'Las canciones de cada servicio',
            trailing: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo setlist'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SetlistEditorScreen())),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: ViewModeToggle(prefsKey: _viewModeKey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: setlistsAsync.when(
              data: (setlists) => setlists.isEmpty
                  ? const _EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'Todavía no hay setlists',
                      message: 'Creá el del próximo servicio con «Nuevo setlist».',
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(setlistListProvider.notifier).refresh(),
                      child: viewMode == ViewMode.grid
                          ? GridView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              // Fits the date row, name, three songs and the
                              // total, like the pinned blocks in Inicio.
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 380,
                                mainAxisExtent: 204,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: setlists.length,
                              itemBuilder: (context, index) => SetlistBlock(
                                setlist: setlists[index],
                                onTap: () => _openSetlist(context, ref, setlists[index].id),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: setlists.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _SetlistCard(
                                setlist: setlists[index],
                                onTap: () => _openSetlist(context, ref, setlists[index].id),
                              ),
                            ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const _EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar los setlists',
                message: 'Revisá tu conexión y deslizá hacia abajo para reintentar.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openSetlist(BuildContext context, WidgetRef ref, int setlistId) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SetlistDetailScreen(setlistId: setlistId)));
  // Songs may have been added, removed or reordered inside; invalidate (not
  // refresh) so the current blocks stay on screen while the list reloads.
  ref.invalidate(setlistListProvider);
}

class _SetlistCard extends StatelessWidget {
  const _SetlistCard({required this.setlist, required this.onTap});

  final Setlist setlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = setlist.serviceDate;
    final hasName = setlist.name?.isNotEmpty == true;

    return ArcaCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: text.titleLarge?.copyWith(color: scheme.primary, height: 1.1),
                ),
                Text(
                  monthAbbr(date).toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? setlist.name! : weekdayName(date),
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  hasName ? '${weekdayName(date)} · ${shortDate(date)}' : shortDate(date),
                  style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.arca.textSecondary),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: context.arca.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.arca.textSecondary),
          ),
        ],
      ),
    );
  }
}
