import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_mode.dart';

/// The Bloques / Lista switch shown next to a library's search or header.
/// Reads and stores the choice under [prefsKey].
class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key, required this.prefsKey});

  final String prefsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider(prefsKey)).value ?? ViewMode.grid;
    return SegmentedButton<ViewMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: ViewMode.grid, icon: Icon(Icons.grid_view), tooltip: 'Bloques'),
        ButtonSegment(
          value: ViewMode.list,
          icon: Icon(Icons.view_agenda_outlined),
          tooltip: 'Lista',
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) =>
          ref.read(viewModeProvider(prefsKey).notifier).set(selection.first),
    );
  }
}
