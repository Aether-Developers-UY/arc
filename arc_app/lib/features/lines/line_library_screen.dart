import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/content_frame.dart';
import '../../core/widgets/page_header.dart';
import 'line.dart';
import 'line_card.dart';
import 'line_editor_screen.dart';
import 'line_repository.dart';

/// The library of lines: songs played back to back, ready to drop into
/// the line block of a setlist.
class LineLibraryScreen extends ConsumerWidget {
  const LineLibraryScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, [Line? line]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LineEditorScreen(line: line)),
    );
    if (changed == true) ref.invalidate(lineListProvider);
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
              onPressed: () => _openEditor(context, ref),
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
                          onTap: () => _openEditor(context, ref, lines[index]),
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
