import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../setlists/setlist.dart';
import '../setlists/setlist_detail_screen.dart';
import 'pinned_setlists_provider.dart';
import 'setlist_detail_provider.dart';

/// How many songs a pinned block previews before the total count.
const _previewSongs = 3;

/// One setlist pinned to Inicio: date, name, the first songs with their key
/// and the total. Tapping it opens the setlist.
class PinnedSetlistCard extends ConsumerWidget {
  const PinnedSetlistCard({super.key, required this.setlistId});

  final int setlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = setlistDetailProvider(setlistId);

    // A setlist deleted elsewhere answers 404: drop the pin silently. Any
    // other failure (network, 500) keeps it and offers a retry.
    ref.listen(provider, (_, next) {
      final error = next.error;
      if (error is DioException && error.response?.statusCode == 404) {
        ref.read(pinnedSetlistsProvider.notifier).unpin(setlistId);
      }
    });

    return ref.watch(provider).when(
          data: (setlist) => _LoadedCard(
            setlist: setlist,
            onOpen: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SetlistDetailScreen(setlistId: setlistId)),
              );
              // Songs or keys may have changed inside the setlist.
              ref.invalidate(provider);
            },
            onUnpin: () => ref.read(pinnedSetlistsProvider.notifier).unpin(setlistId),
          ),
          loading: () => const ArcaCard(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => ArcaCard(
            child: SizedBox(
              height: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined, color: context.arca.textSecondary),
                  const SizedBox(height: 8),
                  const Text('No se pudo cargar'),
                  TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

class _LoadedCard extends StatelessWidget {
  const _LoadedCard({required this.setlist, required this.onOpen, required this.onUnpin});

  final Setlist setlist;
  final VoidCallback onOpen;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = setlist.serviceDate;
    final hasName = setlist.name?.isNotEmpty == true;
    final count = setlist.songs.length;

    return ArcaCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${weekdayName(date)} · ${shortDate(date)}'.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                icon: Icon(Icons.more_horiz, color: context.arca.textSecondary),
                onSelected: (_) => onUnpin(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'unpin', child: Text('Quitar de fijados')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? setlist.name! : weekdayName(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                for (final song in setlist.songs.take(_previewSongs))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      song.key.isEmpty ? song.songTitle : '${song.songTitle} · ${song.key}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  count == 1 ? '1 canción' : '$count canciones',
                  style: text.bodySmall?.copyWith(color: context.arca.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
