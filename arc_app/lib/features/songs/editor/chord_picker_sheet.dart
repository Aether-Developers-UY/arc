import 'package:flutter/material.dart';

import '../../../core/theme/arca_theme.dart';
import '../../../core/theme/arca_tokens.dart';
import 'chord_builder.dart';

/// Result of the chord picker: [chord] is the chosen chord text (only
/// meaningful when [removed] is false). [removed] is true when the user
/// asked to remove the chord that was attached to a word (only offered
/// when editing an existing chord, never when inserting a new one).
class ChordSelection {
  const ChordSelection.set(this.chord) : removed = false;
  const ChordSelection.removed()
      : chord = null,
        removed = true;

  final String? chord;
  final bool removed;
}

/// Opens the chord picker as a bottom sheet. Pass [initialChord] when
/// editing a chord that's already attached to a word (pre-fills the
/// picker and shows a "Quitar acorde" button); pass null when inserting a
/// brand new chord. Returns null if the user dismissed the sheet without
/// choosing anything.
Future<ChordSelection?> showChordPicker(
  BuildContext context, {
  String? initialChord,
}) {
  return showModalBottomSheet<ChordSelection>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ChordPickerSheet(initialChord: initialChord),
  );
}

class _ChordPickerSheet extends StatefulWidget {
  const _ChordPickerSheet({this.initialChord});

  final String? initialChord;

  @override
  State<_ChordPickerSheet> createState() => _ChordPickerSheetState();
}

class _ChordPickerSheetState extends State<_ChordPickerSheet> {
  String? _root;
  String _type = '';
  bool _hasBass = false;
  String? _bass;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialChord;
    if (initial == null || initial.isEmpty) return;

    final slashIndex = initial.indexOf('/');
    final rootAndType = slashIndex == -1 ? initial : initial.substring(0, slashIndex);
    if (slashIndex != -1) {
      _hasBass = true;
      _bass = initial.substring(slashIndex + 1);
    }

    // Prefer the longest matching root, so "C#" wins over "C".
    String? matchedRoot;
    for (final candidate in chordRoots) {
      if (rootAndType.startsWith(candidate) &&
          (matchedRoot == null || candidate.length > matchedRoot.length)) {
        matchedRoot = candidate;
      }
    }
    if (matchedRoot == null) return;

    _root = matchedRoot;
    final suffix = rootAndType.substring(matchedRoot.length);
    _type = chordTypes.contains(suffix) ? suffix : '';
  }

  String get _preview {
    final root = _root;
    if (root == null) return '—';
    return buildChord(root: root, type: _type, bass: _hasBass ? _bass : null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _preview,
              style: ArcaTheme.mono(
                Theme.of(context).textTheme.headlineSmall!.copyWith(
                      color: context.arca.chord,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nota', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _NoteGrid(selected: _root, onSelect: (r) => setState(() => _root = r)),
            const SizedBox(height: 16),
            Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in chordTypes)
                  ChoiceChip(
                    label: Text(type.isEmpty ? 'Mayor' : type),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Acorde con bajo distinto'),
              value: _hasBass,
              onChanged: (value) => setState(() {
                _hasBass = value;
                if (!value) _bass = null;
              }),
            ),
            if (_hasBass) ...[
              const SizedBox(height: 8),
              _NoteGrid(selected: _bass, onSelect: (r) => setState(() => _bass = r)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.initialChord != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const ChordSelection.removed()),
                    child: const Text('Quitar acorde'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _root == null
                      ? null
                      : () => Navigator.of(context).pop(ChordSelection.set(_preview)),
                  child: Text(widget.initialChord != null ? 'Guardar cambios' : 'Insertar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteGrid extends StatelessWidget {
  const _NoteGrid({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final root in chordRoots)
          ChoiceChip(
            label: Text(
              root,
              style: ArcaTheme.mono(const TextStyle(fontWeight: FontWeight.w700)),
            ),
            selected: selected == root,
            onSelected: (_) => onSelect(root),
          ),
      ],
    );
  }
}
