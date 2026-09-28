import 'package:flutter/material.dart';

import '../../../core/theme/arca_theme.dart';
import '../../../core/theme/arca_tokens.dart';
import 'chord_picker_sheet.dart';
import 'editable_document.dart';

class _SectionType {
  const _SectionType(this.label, this.name);
  final String label;
  final String name;
}

const _sectionTypes = [
  _SectionType('verse', 'Verso'),
  _SectionType('chorus', 'Coro'),
  _SectionType('bridge', 'Puente'),
  _SectionType('tag', 'Otro'),
];

String _sectionName(String? label) {
  for (final type in _sectionTypes) {
    if (type.label == label) return type.name;
  }
  return 'Sección';
}

/// Visual editor for a song's lyrics and chords. Owns no network/save
/// logic — [sections] is the current value and [onChanged] is called with
/// a new list whenever the user edits anything, like a controlled form
/// field.
class SongLyricsEditor extends StatelessWidget {
  const SongLyricsEditor({super.key, required this.sections, required this.onChanged});

  final List<EditableSection> sections;
  final ValueChanged<List<EditableSection>> onChanged;

  void _updateSection(int index, EditableSection updated) {
    final next = List<EditableSection>.from(sections);
    next[index] = updated;
    onChanged(next);
  }

  void _removeSection(int index) {
    final next = List<EditableSection>.from(sections)..removeAt(index);
    onChanged(next);
  }

  Future<void> _addSection(BuildContext context) async {
    final label = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in _sectionTypes)
              ListTile(
                title: Text(type.name),
                onTap: () => Navigator.of(context).pop(type.label),
              ),
          ],
        ),
      ),
    );
    if (label == null) return;
    onChanged([...sections, EditableSection(label: label)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++)
          _SectionBlock(
            // Keyed by the section's stable id (not object identity — a
            // new EditableSection instance is built on every edit — and
            // not list position, which shifts when a section is removed).
            key: ValueKey(sections[i].id),
            section: sections[i],
            onChanged: (updated) => _updateSection(i, updated),
            onRemove: sections.length > 1 ? () => _removeSection(i) : null,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addSection(context),
          icon: const Icon(Icons.add),
          label: const Text('Sección'),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({super.key, required this.section, required this.onChanged, this.onRemove});

  final EditableSection section;
  final ValueChanged<EditableSection> onChanged;
  final VoidCallback? onRemove;

  void _updateLine(int index, EditableLine updated) {
    final lines = List<EditableLine>.from(section.lines);
    lines[index] = updated;
    onChanged(EditableSection(id: section.id, label: section.label, lines: lines));
  }

  void _addLine() {
    onChanged(EditableSection(
      id: section.id,
      label: section.label,
      lines: [...section.lines, EditableLine()],
    ));
  }

  void _removeLine(int index) {
    final lines = List<EditableLine>.from(section.lines)..removeAt(index);
    if (lines.isEmpty) lines.add(EditableLine());
    onChanged(EditableSection(id: section.id, label: section.label, lines: lines));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _sectionName(section.label).toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Quitar sección',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
            ],
          ),
          for (var i = 0; i < section.lines.length; i++)
            if (section.lines[i].rawDirective != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  section.lines[i].rawDirective!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.arca.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              )
            else
              _LineEditor(
                // Keyed by the line's stable id, not its list position —
                // removing a line/section shifts the positions of the ones
                // after it, and without this key Flutter would reuse
                // another line's State (and its TextEditingControllers) by
                // slot, silently showing stale text. Not object identity
                // either: a new EditableLine instance is built on every
                // edit (see editable_document.dart), so keying by the
                // object itself would force a full remount — losing focus
                // and cursor position — on every keystroke.
                key: ValueKey(section.lines[i].id),
                line: section.lines[i],
                onChanged: (updated) => _updateLine(i, updated),
                onRemove: section.lines.length > 1 ? () => _removeLine(i) : null,
              ),
          TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Línea'),
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends StatefulWidget {
  const _LineEditor({super.key, required this.line, required this.onChanged, this.onRemove});

  final EditableLine line;
  final ValueChanged<EditableLine> onChanged;
  final VoidCallback? onRemove;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late List<TextEditingController> _controllers = [
    for (final word in widget.line.words) TextEditingController(text: word.text),
  ];

  @override
  void didUpdateWidget(covariant _LineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild controllers when the word count changed (add/remove
    // word or line) — never on every keystroke, or typing would lose
    // cursor position and focus.
    if (widget.line.words.length != _controllers.length) {
      for (final controller in _controllers) {
        controller.dispose();
      }
      _controllers = [
        for (final word in widget.line.words) TextEditingController(text: word.text),
      ];
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateWord(int index, EditableWord word) {
    final words = List<EditableWord>.from(widget.line.words);
    words[index] = word;
    widget.onChanged(EditableLine(id: widget.line.id, words: words));
  }

  void _setWordText(int index, String text) {
    final current = widget.line.words[index];
    _updateWord(index, EditableWord(text: text, chord: current.chord));
  }

  Future<void> _editChord(int index) async {
    final current = widget.line.words[index];
    final result = await showChordPicker(context, initialChord: current.chord);
    if (result == null) return;
    _updateWord(
      index,
      EditableWord(text: current.text, chord: result.removed ? null : result.chord),
    );
  }

  void _addWord() {
    widget.onChanged(EditableLine(
      id: widget.line.id,
      words: [...widget.line.words, EditableWord(text: '')],
    ));
  }

  void _removeWord(int index) {
    final words = List<EditableWord>.from(widget.line.words)..removeAt(index);
    if (words.isEmpty) words.add(EditableWord(text: ''));
    widget.onChanged(EditableLine(id: widget.line.id, words: words));
  }

  @override
  Widget build(BuildContext context) {
    final chordStyle = ArcaTheme.mono(
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.arca.chord),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 4,
              children: [
                for (var i = 0; i < widget.line.words.length; i++)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _editChord(i),
                        onLongPress: widget.line.words[i].text.isEmpty
                            ? () => _removeWord(i)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            widget.line.words[i].chord ?? '+',
                            style: widget.line.words[i].chord != null
                                ? chordStyle
                                : chordStyle.copyWith(color: context.arca.textSecondary),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _controllers[i],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'palabra',
                          ),
                          onChanged: (value) => _setWordText(i, value),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Agregar palabra',
            icon: const Icon(Icons.add, size: 16),
            onPressed: _addWord,
          ),
          if (widget.onRemove != null)
            IconButton(
              tooltip: 'Quitar línea',
              icon: const Icon(Icons.close, size: 16),
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}
