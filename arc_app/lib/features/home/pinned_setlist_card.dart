import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../annexes/active_annex_provider.dart';
import '../auth/auth_provider.dart';
import '../setlists/setlist_block.dart';
import '../setlists/setlist_detail_screen.dart';
import 'pinned_setlists_provider.dart';
import 'setlist_detail_provider.dart';

/// One setlist pinned to Inicio: loads its detail and shows it as a
/// [SetlistBlock] with an unpin menu. Tapping it opens the setlist.
class PinnedSetlistCard extends ConsumerWidget {
  const PinnedSetlistCard({super.key, required this.setlistId});

  final int setlistId;

  /// A 404 also comes back when the user is no longer in the annex (they
  /// left it on another device). Reload the profile first: if the active
  /// annex changes, the setlist still exists and its pin stays for when
  /// they come back.
  Future<void> _dropIfDeleted(ProviderContainer container) async {
    final annex = container.read(activeAnnexProvider);
    final pins = container.read(pinnedSetlistsProvider.notifier);
    try {
      await container.read(authProvider.notifier).refreshUser();
    } catch (_) {
      return;
    }
    if (container.read(activeAnnexProvider) == annex) await pins.unpin(setlistId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = setlistDetailProvider(setlistId);

    // A setlist deleted elsewhere answers 404: drop the pin silently. Any
    // other failure (network, 500) keeps it and offers a retry.
    ref.listen(provider, (_, next) {
      final error = next.error;
      if (error is DioException && error.response?.statusCode == 404) {
        _dropIfDeleted(ProviderScope.containerOf(context, listen: false));
      }
    });

    return ref.watch(provider).when(
          data: (setlist) => SetlistBlock(
            setlist: setlist,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SetlistDetailScreen(setlistId: setlistId)),
              );
              // Songs or keys may have changed inside the setlist.
              ref.invalidate(provider);
            },
            menu: PopupMenuButton<String>(
              tooltip: 'Opciones',
              icon: Icon(Icons.more_horiz, color: context.arca.textSecondary),
              onSelected: (_) => ref.read(pinnedSetlistsProvider.notifier).unpin(setlistId),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'unpin', child: Text('Quitar de fijados')),
              ],
            ),
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
