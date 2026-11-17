import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/external_link.dart';
import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import '../annexes/annex.dart';
import '../auth/auth_provider.dart';
import '../home/pinned_setlists_provider.dart';
import '../lines/line.dart';
import '../lines/line_picker_screen.dart';
import '../songs/song.dart';
import '../songs/song_detail_screen.dart';
import '../songs/song_list_provider.dart';
import 'add_song_to_setlist_screen.dart';
import 'setlist.dart';
import 'setlist_list_provider.dart';
import 'setlist_share.dart';
import 'stage_screen.dart';

enum _ShareAction { whatsApp, copy }

/// The songs of one block of the service; [section] null is «Otras
/// canciones», for songs added before the blocks existed.
class _Block {
  const _Block(this.section, this.songs);
  final SetlistSection? section;
  final List<SetlistSong> songs;
}

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final int setlistId;

  @override
  ConsumerState<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  Setlist? _setlist;
  bool _isLoading = true;
  String? _errorMessage;

  /// True while a reorder/remove/add mutation is in flight. Guards against
  /// overlapping mutations (e.g. dragging again before the previous reorder
  /// persisted, or removing a song mid-reorder) racing each other and
  /// leaving the UI in a state that matches neither request.
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final setlist = await ref.read(setlistRepositoryProvider).getOne(widget.setlistId);
      if (mounted) setState(() => _setlist = setlist);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo cargar el setlist.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Re-fetches the setlist from the server without toggling `_isLoading`
  /// (so it doesn't replace the list with a full-screen spinner) — used
  /// after a mutation to re-sync local state with the server, whether the
  /// mutation succeeded or failed.
  Future<void> _reloadSilently() async {
    try {
      final setlist = await ref.read(setlistRepositoryProvider).getOne(widget.setlistId);
      if (mounted) setState(() => _setlist = setlist);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo actualizar el setlist.');
    }
  }

  /// The blocks to show: the four of the service always, plus «Otras
  /// canciones» for songs added before the blocks existed.
  List<_Block> _blocksOf(Setlist setlist) => [
        for (final section in SetlistSection.values)
          _Block(section, [for (final s in setlist.songs) if (s.section == section) s]),
        if (setlist.songs.any((s) => s.section == null))
          _Block(null, [for (final s in setlist.songs) if (s.section == null) s]),
      ];

  /// A drag inside [block]: the other blocks keep their songs and order.
  Future<void> _onReorderInBlock(_Block block, int oldIndex, int newIndex) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;
    final moved = List<SetlistSong>.from(block.songs);
    if (newIndex > oldIndex) newIndex -= 1;
    moved.insert(newIndex, moved.removeAt(oldIndex));
    await _onReorder([
      for (final b in _blocksOf(setlist)) ...(b.section == block.section ? moved : b.songs),
    ]);
  }

  Future<void> _onReorder(List<SetlistSong> songs) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;

    // Optimistic: reorder locally immediately, persist in background.
    setState(() {
      _isMutating = true;
      _setlist = Setlist(
        id: setlist.id,
        serviceDate: setlist.serviceDate,
        name: setlist.name,
        songs: songs,
        annexId: setlist.annexId,
      );
    });

    try {
      await ref.read(setlistRepositoryProvider).reorder(
            setlistId: setlist.id,
            setlistSongIds: songs.map((s) => s.id).toList(),
          );
    } catch (_) {
      // Revert to the last known-good server state.
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo guardar el nuevo orden.');
      }
    } finally {
      // Re-sync after every persist attempt (success or failure), not just
      // on failure — this is what keeps local state matching the server
      // and clears the mutation guard so the next reorder/remove can run.
      await _reloadSilently();
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _removeSong(SetlistSong setlistSong) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;
    setState(() => _isMutating = true);
    try {
      await ref.read(setlistRepositoryProvider).removeSong(
            setlistId: setlist.id,
            setlistSongId: setlistSong.id,
          );
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo quitar la canción.');
    } finally {
      await _reloadSilently();
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _openAddSong(SetlistSection section) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSongToSetlistScreen(setlistId: setlist.id, section: section),
      ),
    );
    if (added == true) await _reloadSilently();
  }

  /// Picks a line from the library and puts its songs in the line block,
  /// after asking when that replaces songs already there.
  Future<void> _chooseLine(_Block block) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;
    final line = await Navigator.of(context).push<Line>(
      MaterialPageRoute(builder: (_) => const LinePickerScreen()),
    );
    if (line == null || !mounted) return;

    if (block.songs.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Reemplazar la línea?'),
          content: Text('Las canciones del bloque Línea se cambian por las de «${line.name}».'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    setState(() => _isMutating = true);
    try {
      final updated = await ref.read(setlistRepositoryProvider).useLine(
            setlistId: setlist.id,
            lineId: line.id,
          );
      if (mounted) setState(() => _setlist = updated);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo agregar la línea.');
      await _reloadSilently();
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Widget _buildBlock(BuildContext context, Setlist setlist, _Block block) {
    final text = Theme.of(context).textTheme;
    final section = block.section;
    final lineName = block.songs.map((s) => s.lineName).nonNulls.firstOrNull;
    final label = section == null
        ? 'Otras canciones'
        : section == SetlistSection.linea && lineName != null
            ? 'Línea · $lineName'
            : section.label;
    final empty = switch (section) {
      SetlistSection.inicio => 'Sin canción de inicio',
      SetlistSection.linea => 'Elegí una línea o agregá canciones sueltas.',
      SetlistSection.ofrenda => 'Sin canción de ofrenda',
      SetlistSection.santaCena => 'Sin santa cena',
      null => '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (section == SetlistSection.linea)
                TextButton.icon(
                  onPressed: _isMutating ? null : () => _chooseLine(block),
                  icon: const Icon(Icons.playlist_play),
                  label: Text(block.songs.isEmpty ? 'Elegir línea' : 'Cambiar línea'),
                ),
              if (section != null)
                IconButton(
                  tooltip: 'Agregar a ${section.label}',
                  icon: const Icon(Icons.add),
                  onPressed: _isMutating ? null : () => _openAddSong(section),
                ),
            ],
          ),
          if (block.songs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(empty, style: text.bodyMedium?.copyWith(color: context.arca.textSecondary)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: block.songs.length,
              onReorder: (oldIndex, newIndex) => _onReorderInBlock(block, oldIndex, newIndex),
              // Our own handle at the far left; the default one sits on the
              // right, over "Quitar".
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                final setlistSong = block.songs[index];
                return Padding(
                  key: ValueKey(setlistSong.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _songCard(context, setlistSong, index, setlist.songs.indexOf(setlistSong) + 1),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _songCard(BuildContext context, SetlistSong setlistSong, int indexInBlock, int number) {
    final text = Theme.of(context).textTheme;
    return ArcaCard(
      onTap: () => _openSong(setlistSong),
      padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: indexInBlock,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Tooltip(
                message: 'Arrastrar para reordenar',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Icon(Icons.drag_indicator, color: context.arca.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              '$number',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(setlistSong.songTitle, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (setlistSong.songArtist?.isNotEmpty == true)
                  Text(
                    setlistSong.songArtist!,
                    style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KeyBadge(setlistSong.key),
          IconButton(
            tooltip: 'Quitar del setlist',
            icon: const Icon(Icons.close),
            onPressed: _isMutating ? null : () => _removeSong(setlistSong),
          ),
        ],
      ),
    );
  }

  /// A setlist entry only carries title/artist/key for display in this
  /// list — not the full song (content, tempo, attachments). Navigate to a
  /// loader that fetches the real song before handing off to
  /// SongDetailScreen, passing this setlist's chosen key as the initial key.
  Future<void> _openSong(SetlistSong setlistSong) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SongFromSetlistLoader(
          songId: setlistSong.songId,
          initialKey: setlistSong.key,
        ),
      ),
    );
    // The song may have been edited or deleted meanwhile; a deleted song
    // also leaves this setlist, so re-sync before showing it again.
    if (mounted) await _reloadSilently();
  }

  Future<void> _confirmDelete(Setlist setlist, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar «$title»?'),
        content: const Text(
          'Las canciones siguen en la biblioteca; solo se borra este setlist. '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isMutating = true);
    try {
      await ref.read(setlistRepositoryProvider).delete(setlist.id);
      // Drop it from Inicio now instead of waiting for the pinned block's 404.
      await ref.read(pinnedSetlistsProvider.notifier).unpin(setlist.id);
      // The opener (Setlists list or Inicio) reloads when this route pops.
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el setlist.')),
      );
    }
  }

  /// The message, with the annex name when the user is in that annex.
  String _shareText(Setlist setlist) {
    final annexes = ref.read(authProvider).user?.annexes ?? const <Annex>[];
    final annex = annexes.where((a) => a.id == setlist.annexId).firstOrNull;
    return setlistShareText(setlist, annexName: annex?.name);
  }

  Future<void> _shareOnWhatsApp(Setlist setlist) async {
    final opened = await ref.read(openExternalProvider)(whatsAppUri(_shareText(setlist)));
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No se pudo abrir WhatsApp. Podés copiar el texto y pegarlo.'),
        action: SnackBarAction(label: 'Copiar', onPressed: () => _copyText(setlist)),
      ),
    );
  }

  Future<void> _copyText(Setlist setlist) async {
    await Clipboard.setData(ClipboardData(text: _shareText(setlist)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setlist copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final setlist = _setlist;
    final text = Theme.of(context).textTheme;
    final title = setlist == null
        ? ''
        : (setlist.name?.isNotEmpty == true ? setlist.name! : weekdayName(setlist.serviceDate));
    final subtitle = setlist == null
        ? ''
        : '${weekdayName(setlist.serviceDate)} · ${shortDate(setlist.serviceDate)}';

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (setlist != null && setlist.songs.isNotEmpty)
            PopupMenuButton<_ShareAction>(
              tooltip: 'Compartir',
              icon: const Icon(Icons.share_outlined),
              onSelected: (action) => switch (action) {
                _ShareAction.whatsApp => _shareOnWhatsApp(setlist),
                _ShareAction.copy => _copyText(setlist),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ShareAction.whatsApp,
                  child: ListTile(
                    leading: Icon(Icons.chat_outlined),
                    title: Text('Enviar por WhatsApp'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _ShareAction.copy,
                  child: ListTile(
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Copiar texto'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          if (setlist != null)
            IconButton(
              tooltip: 'Eliminar setlist',
              icon: const Icon(Icons.delete_outline),
              onPressed: _isMutating ? null : () => _confirmDelete(setlist, title),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : setlist == null
              ? Center(child: Text(_errorMessage ?? 'Setlist no encontrado.'))
              : ContentFrame(
                  maxWidth: 800,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.headlineMedium),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: text.bodyLarge?.copyWith(color: context.arca.textSecondary),
                            ),
                            if (setlist.songs.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StageScreen(setlist: setlist),
                                  ),
                                ),
                                icon: const Icon(Icons.slideshow_outlined),
                                label: const Text('Modo escenario'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 32),
                          children: [
                            for (final block in _blocksOf(setlist)) _buildBlock(context, setlist, block),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Fetches the full [Song] (content, tempo, attachments) for [songId] before
/// handing off to [SongDetailScreen], since a setlist entry only carries
/// enough data (title/artist/key) for display in the setlist list itself.
class _SongFromSetlistLoader extends ConsumerStatefulWidget {
  const _SongFromSetlistLoader({required this.songId, required this.initialKey});

  final int songId;
  final String initialKey;

  @override
  ConsumerState<_SongFromSetlistLoader> createState() => _SongFromSetlistLoaderState();
}

class _SongFromSetlistLoaderState extends ConsumerState<_SongFromSetlistLoader> {
  // Fetched once in initState (not inside build) so a widget rebuild for an
  // unrelated reason (theme/orientation change, hot reload) doesn't hand
  // FutureBuilder a new Future identity and re-trigger the network request.
  late final Future<Song> _songFuture =
      ref.read(songRepositoryProvider).getOne(widget.songId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Song>(
      future: _songFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('No se pudo cargar la canción.')),
          );
        }
        return SongDetailScreen(song: snapshot.data!, initialKey: widget.initialKey);
      },
    );
  }
}
