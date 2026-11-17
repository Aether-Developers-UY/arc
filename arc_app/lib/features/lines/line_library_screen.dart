import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/content_frame.dart';
import '../../core/widgets/page_header.dart';
import 'line.dart';
import 'line_card.dart';
import 'line_detail_screen.dart';
import 'line_editor_screen.dart';
import 'line_repository.dart';

/// The library of lines: songs played back to back, ready to drop into
/// the line block of a setlist.
class LineLibraryScreen extends ConsumerWidget {
  const LineLibraryScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final change = await Navigator.of(context).push<LineChange>(
      MaterialPageRoute(builder: (_) => const LineEditorScreen()),
    );
    if (change != null) ref.invalidate(lineListProvider);
  }

  /// The line may be edited, deleted or get files from its view.
  Future<void> _open(BuildContext context, WidgetRef ref, Line line) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LineDetailScreen(line: line)),
    );
    ref.invalidate(lineListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(lineListProvider);
    return ContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Líneas',
            subtitle: 'Canciones enganchadas, listas para el culto',
            trailing: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nueva línea'),
              onPressed: () => _create(context, ref),
            ),
          ),
          Expanded(
            child: lines.when(
              data: (lines) => lines.isEmpty
                  ? const LinesEmptyState(
                      message: 'Todavía no hay líneas. Armá la primera con «Nueva línea».',
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(lineListProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => LineCard(
                          line: lines[index],
                          onTap: () => _open(context, ref, lines[index]),
                        ),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => LinesEmptyState(
                message: 'No se pudieron cargar las líneas. Deslizá hacia abajo para reintentar.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
