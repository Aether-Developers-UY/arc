import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/content_frame.dart';
import 'line.dart';
import 'line_card.dart';
import 'line_repository.dart';

/// Picks a line from the library; pops with the chosen [Line].
class LinePickerScreen extends ConsumerWidget {
  const LinePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(lineListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir línea')),
      body: ContentFrame(
        maxWidth: 720,
        child: lines.when(
          data: (lines) => lines.isEmpty
              ? const LinesEmptyState(
                  message: 'Todavía no hay líneas. Creá la primera en la pestaña Líneas.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => LineCard(
                    line: lines[index],
                    onTap: () => Navigator.of(context).pop<Line>(lines[index]),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const LinesEmptyState(message: 'No se pudieron cargar las líneas.'),
        ),
      ),
    );
  }
}
