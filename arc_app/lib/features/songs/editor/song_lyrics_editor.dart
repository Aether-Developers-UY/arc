import 'package:flutter/material.dart';

import '../../../core/chordpro/section_names.dart';
import '../../../core/theme/arca_theme.dart';
import '../../../core/theme/arca_tokens.dart';
import '../../../core/widgets/arca_card.dart';
import 'chord_picker_sheet.dart';
import 'editable_document.dart';

/// Letra: each section is a big text field. Acordes: the lyrics are shown
/// as words you tap to put a chord on.
enum LyricsMode { lyrics, chords }

/// Visual editor for a song's sections. Owns no network/save logic —
/// [sections] is the current value and [onChanged] is called with a new
/// list whenever the user edits anything, like a controlled form field.
class SongLyricsEditor extends StatefulWidget {
  const SongLyricsEditor({
    super.key,
    required this.sections,
    required this.onChanged,
    required this.mode,
  });

  final List<EditableSection> sections;
  final ValueChanged<List<EditableSection>> onChanged;
  final LyricsMode mode;

  @override
  State<SongLyricsEditor> createState() => _SongLyricsEditorState();
}

class _SongLyricsEditorState extends State<SongLyricsEditor> {
  /// The section added last, whose field takes the focus.
  int? _addedId;

  List<EditableSection> get _sections => widget.sections;

  void _update(int index, EditableSection updated) {
    widget.onChanged(List.of(_sections)..[index] = updated);
  }

  void _move(int index, int delta) {
    final next = List.of(_sections);
    final section = next.removeAt(index);
    next.insert(index + delta, section);
    widget.onChanged(next);
  }

  Future<void> _add() async {
    final label = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in addableSectionLabels)
              ListTile(
                title: Text(sectionName(label)),
                onTap: () => Navigator.of(context).pop(label),
              ),
          ],
        ),
      ),
    );
    if (label == null) return;
    final section = EditableSection(label: label);
    setState(() => _addedId = section.id);
    widget.onChanged([..._sections, section]);
  }

  @override
  Widget build(BuildContext context) {
    final count = _sections.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < count; i++)
          _SectionCard(
            // Keyed by the section's stable id: a new EditableSection is
            // built on every edit, and positions shift when moving.
            key: ValueKey(_sections[i].id),
            section: _sections[i],
            mode: widget.mode,
            autofocus: _sections[i].id == _addedId,
            onChanged: (updated) => _update(i, updated),
            onMoveUp: i > 0 ? () => _move(i, -1) : null,
            onMoveDown: i < count - 1 ? () => _move(i, 1) : null,
            onRemove: count > 1
                ? () => widget.onChanged(List.of(_sections)..removeAt(i))
                : null,
          ),
        if (widget.mode == LyricsMode.lyrics)
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Sección'),
          ),
      ],
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.mode,
    required this.autofocus,
    required this.onChanged,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final EditableSection section;
  final LyricsMode mode;
  final bool autofocus;
  final ValueChanged<EditableSection> onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  // Created once and never rewritten while typing, so the cursor and the
  // focus stay put; resynced only when coming back to the Letra mode.
  late final _controller = TextEditingController(text: sectionText(widget.section));

  EditableSection get _section => widget.section;
  bool get _chordOnly => isChordOnlySection(_section.label);

  @override
  void didUpdateWidget(covariant _SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == LyricsMode.lyrics && oldWidget.mode != LyricsMode.lyrics) {
      _controller.text = sectionText(_section);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove() async {
    if (sectionText(_section).trim().isEmpty) {
      widget.onRemove!();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Quitar este ${sectionName(_section.label)}?'),
        content: const Text('Se pierde su letra y sus acordes.'),
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
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onRemove!();
  }

  Future<void> _editChord(int lineIndex, int wordIndex) async {
    final line = _section.lines[lineIndex];
    final word = line.words[wordIndex];
    final result = await showChordPicker(context, initialChord: word.chord);
    if (result == null) return;
    final words = List.of(line.words)
      ..[wordIndex] = EditableWord(
        text: word.text,
        chord: result.removed ? null : result.chord,
        spaceAfter: word.spaceAfter,
      );
    final lines = List.of(_section.lines)
      ..[lineIndex] = EditableLine(id: line.id, words: words);
    widget.onChanged(EditableSection(id: _section.id, label: _section.label, lines: lines));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ArcaCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sectionName(_section.label).toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Subir sección',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: widget.onMoveUp,
                ),
                IconButton(
                  tooltip: 'Bajar sección',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: widget.onMoveDown,
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: 'Quitar sección',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _confirmRemove,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: widget.mode == LyricsMode.lyrics ? _buildField() : _buildChords(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField() {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      minLines: 3,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: _chordOnly ? ArcaTheme.mono(const TextStyle(fontWeight: FontWeight.w700)) : null,
      decoration: InputDecoration(
        hintText: _chordOnly
            ? 'Acordes separados por espacios, ej.: G D Em C'
            : 'Escribí o pegá la letra',
      ),
      onChanged: (text) => widget.onChanged(applyText(_section, text)),
    );
  }

  Widget _buildChords(BuildContext context) {
    final secondary = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.arca.textSecondary,
        );
    if (sectionText(_section).trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _chordOnly
              ? 'Sin acordes todavía. Escribilos en el modo Letra.'
              : 'Sin letra todavía. Escribila en el modo Letra.',
          style: secondary,
        ),
      );
    }

    final chordStyle = ArcaTheme.mono(
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.arca.chord),
    );
    final hasChords = _section.lines.any((l) => l.words.any((w) => w.chord != null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_chordOnly && !hasChords)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Tocá una palabra para ponerle acorde', style: secondary),
          ),
        for (var l = 0; l < _section.lines.length; l++)
          if (_section.lines[l].rawDirective != null)
            const SizedBox.shrink()
          else if (_section.lines[l].isChordOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 16,
                children: [
                  for (final word in _section.lines[l].words)
                    if (word.chord != null) Text(word.chord!, style: chordStyle),
                ],
              ),
            )
          else if (_section.lines[l].words.every((w) => w.text.isEmpty && w.chord == null))
            const SizedBox(height: 14)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                runSpacing: 4,
                children: [
                  for (var w = 0; w < _section.lines[l].words.length; w++)
                    if (_section.lines[l].words[w].text.isNotEmpty ||
                        _section.lines[l].words[w].chord != null)
                      Padding(
                        // A word glued to the next one (a mid-word chord)
                        // keeps no gap, so "salv" + "ó" still reads "salvó".
                        padding: EdgeInsets.only(
                          right: _section.lines[l].words[w].spaceAfter ? 6 : 0,
                        ),
                        child: LyricWord(
                          word: _section.lines[l].words[w],
                          onTap: () => _editChord(l, w),
                        ),
                      ),
                ],
              ),
            ),
      ],
    );
  }
}

/// One tappable word in the Acordes mode: its chord above (or a faint "+"
/// on hover when it has none), the word below.
class LyricWord extends StatefulWidget {
  const LyricWord({super.key, required this.word, required this.onTap});

  final EditableWord word;
  final VoidCallback onTap;

  @override
  State<LyricWord> createState() => _LyricWordState();
}

class _LyricWordState extends State<LyricWord> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final chordStyle = ArcaTheme.mono(
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.arca.chord),
    );
    final chord = widget.word.chord;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chord ?? (_hovered ? '+' : ' '),
              style: chord != null
                  ? chordStyle
                  : chordStyle.copyWith(color: context.arca.textSecondary),
            ),
            Text(widget.word.text, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
