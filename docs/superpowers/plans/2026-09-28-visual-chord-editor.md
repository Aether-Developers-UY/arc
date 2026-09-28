# Visual Chord Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the free-text ChordPro field in the song editor with a visual editor — section blocks, per-word chord chips, and a chord-builder bottom sheet — per `docs/superpowers/specs/2026-09-28-visual-chord-editor-design.md`, and show the renamed "Indicaciones" field on the song detail screen.

**Architecture:** A new `lib/features/songs/editor/` module holds a pure-Dart editable document model (`EditableSection`/`EditableLine`/`EditableWord`) with lossless-enough conversions to and from the ChordPro text `ChordProParser` already understands, a pure `buildChord()` helper, a chord-picker bottom sheet, and the `SongLyricsEditor` widget tree. `SongEditorScreen` swaps its content `TextField` for `SongLyricsEditor`, converting to/from ChordPro text only at load and save. No backend or model changes — `Song.content` stays ChordPro text, `Song.notes` stays the same field, only its label changes.

**Tech Stack:** Flutter 3.44 / Dart 3.12, existing `ChordProParser` (`lib/core/chordpro/chordpro_parser.dart`), existing Arca theme (`context.arca`, `ArcaTheme.mono`).

**Conventions for every task:**
- Work in `C:\wamp64\www\arc\arc_app`, branch `working`, commit locally, do not push (final task pushes).
- The bash tool may not find `flutter`; use the PowerShell tool (`flutter analyze`, `flutter test`) if so.
- Baseline before this plan: `flutter analyze` shows exactly 2 pre-existing `info` items (an `onReorder` deprecation in `setlist_detail_screen.dart`, a `use_null_aware_elements` in `setlist_repository.dart`); `flutter test` passes 23 tests. Do not introduce new analyzer issues.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

---

## File Structure

**Create**
- `lib/features/songs/editor/editable_document.dart` — `EditableWord`, `EditableLine`, `EditableSection`, `parseToEditable()`, `editableToChordPro()`
- `lib/features/songs/editor/chord_builder.dart` — `chordRoots`, `chordTypes`, `buildChord()`
- `lib/features/songs/editor/chord_picker_sheet.dart` — `ChordSelection`, `showChordPicker()`
- `lib/features/songs/editor/song_lyrics_editor.dart` — `SongLyricsEditor` widget tree
- `test/features/songs/editor/editable_document_test.dart`
- `test/features/songs/editor/chord_builder_test.dart`

**Modify**
- `lib/features/songs/song_editor_screen.dart` — replace the content `TextField` with `SongLyricsEditor`; rename the "Notas" field label to "Indicaciones"
- `lib/features/songs/song_detail_screen.dart` — show an "Indicaciones" card when `song.notes` is non-empty

---

## Task 1: Editable document model and ChordPro conversion (TDD)

**Files:**
- Create: `lib/features/songs/editor/editable_document.dart`
- Test: `test/features/songs/editor/editable_document_test.dart`

This is the highest-risk logic in the feature — it must convert existing songs' ChordPro text into the editable structure and back without losing or scrambling chords, so it's built test-first.

- [ ] **Step 1: Write the failing tests**

Create `test/features/songs/editor/editable_document_test.dart`:

```dart
import 'package:arc_app/core/chordpro/chordpro_parser.dart';
import 'package:arc_app/features/songs/editor/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseToEditable / editableToChordPro round trip', () {
    test('round-trips chords, words, and section labels', () {
      const original = '{verse}\n'
          '[G]Cantaré de tu [D]amor\n'
          '[Em]Por siempre [C]Señor\n'
          '{chorus}\n'
          '[C]Gracia [G]sublime\n'
          '[D]qué dulce es\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);
      final reparsed = ChordProParser.parse(serialized);

      final labelledLines = reparsed.lines.where((l) => l.sectionLabel != null).toList();
      expect(labelledLines.map((l) => l.sectionLabel), ['verse', 'chorus']);

      final lyricLines = reparsed.lines.where((l) => l.segments.isNotEmpty).toList();
      expect(lyricLines, hasLength(4));
      expect(lyricLines[0].segments.map((s) => s.chord), ['G', 'D']);
      expect(lyricLines[0].segments.map((s) => s.text.trim()), ['Cantaré de tu', 'amor']);
      expect(lyricLines[1].segments.map((s) => s.chord), ['Em', 'C']);
      expect(lyricLines[2].segments.map((s) => s.chord), ['C', 'G']);
      expect(lyricLines[3].segments.map((s) => s.chord), ['D']);
      expect(lyricLines[3].segments.map((s) => s.text.trim()), ['qué dulce es']);
    });

    test('keeps consecutive chords with no lyric between them attached correctly', () {
      const original = '{verse}\n[G][D]Instrumental\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);
      final reparsed = ChordProParser.parse(serialized);

      final lyricLine = reparsed.lines.firstWhere((l) => l.segments.isNotEmpty);
      expect(lyricLine.segments.map((s) => s.chord), ['G', 'D']);
      expect(lyricLine.segments.last.text, 'Instrumental');
    });

    test('parsing blank content never crashes and returns at least one section', () {
      final sections = parseToEditable('');
      expect(sections, isNotEmpty);
      expect(sections.single.lines, isNotEmpty);
    });

    test('a line with no chords round-trips as plain text', () {
      const original = '{verse}\nSolo letra sin acordes\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);
      final reparsed = ChordProParser.parse(serialized);

      final lyricLine = reparsed.lines.firstWhere((l) => l.segments.isNotEmpty);
      expect(lyricLine.segments.every((s) => s.chord == null), isTrue);
      expect(lyricLine.segments.map((s) => s.text).join(' ').trim(), 'Solo letra sin acordes');
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter test test/features/songs/editor/editable_document_test.dart
```

Expected: FAIL — `editable_document.dart` does not exist (compile error).

- [ ] **Step 3: Implement the model and conversions**

Create `lib/features/songs/editor/editable_document.dart`:

```dart
import '../../../core/chordpro/chordpro_parser.dart';

/// One word of lyric text, with an optional chord attached to it — the
/// chord that appears just before this word, ChordPro-style.
class EditableWord {
  EditableWord({required this.text, this.chord});

  String text;
  String? chord;
}

/// One line of lyrics: a sequence of words, each optionally carrying a
/// chord. A brand new line always has exactly one empty word, so there is
/// always something to tap or type into.
class EditableLine {
  EditableLine({List<EditableWord>? words}) : words = words ?? [EditableWord(text: '')];

  List<EditableWord> words;
}

/// A section of the song (a verse, chorus, bridge, or an untitled block),
/// with its own lines. A brand new section always has one empty line.
class EditableSection {
  EditableSection({this.label, List<EditableLine>? lines})
      : lines = lines ?? [EditableLine()];

  /// One of 'verse', 'chorus', 'bridge', 'tag', or null for an untitled
  /// block (used so content the parser couldn't confidently place under a
  /// section heading is still shown, never silently dropped).
  String? label;
  List<EditableLine> lines;
}

/// Converts ChordPro text (as already understood by [ChordProParser]) into
/// the editable structure the visual editor works on.
List<EditableSection> parseToEditable(String content) {
  final document = ChordProParser.parse(content);
  final sections = <EditableSection>[];
  EditableSection? current;

  EditableSection ensureCurrent() {
    if (current == null) {
      current = EditableSection(lines: []);
      sections.add(current!);
    }
    return current!;
  }

  for (final line in document.lines) {
    if (line.sectionLabel != null && line.segments.isEmpty) {
      current = EditableSection(label: line.sectionLabel, lines: []);
      sections.add(current!);
      continue;
    }
    final section = ensureCurrent();
    if (line.segments.isEmpty) {
      // A blank line inside a section — keep it so it round-trips.
      section.lines.add(EditableLine(words: [EditableWord(text: '')]));
      continue;
    }
    section.lines.add(_segmentsToLine(line.segments));
  }

  if (sections.isEmpty) {
    sections.add(EditableSection());
  }
  for (final section in sections) {
    if (section.lines.isEmpty) {
      section.lines.add(EditableLine());
    }
  }
  return sections;
}

EditableLine _segmentsToLine(List<ChordProSegment> segments) {
  final words = <EditableWord>[];
  for (final segment in segments) {
    final parts = segment.text.split(' ');
    for (var i = 0; i < parts.length; i++) {
      words.add(EditableWord(text: parts[i], chord: i == 0 ? segment.chord : null));
    }
  }
  if (words.isEmpty) {
    words.add(EditableWord(text: ''));
  }
  return EditableLine(words: words);
}

/// Converts the editable structure back into ChordPro text, ready to save
/// as a [Song]'s `content`.
String editableToChordPro(List<EditableSection> sections) {
  final buffer = StringBuffer();
  for (var s = 0; s < sections.length; s++) {
    final section = sections[s];
    if (section.label != null) {
      buffer.writeln('{${section.label}}');
    }
    for (final line in section.lines) {
      buffer.writeln(_lineToChordProText(line));
    }
    if (s < sections.length - 1) {
      buffer.writeln();
    }
  }
  return buffer.toString().trimRight();
}

String _lineToChordProText(EditableLine line) {
  final buffer = StringBuffer();
  for (var i = 0; i < line.words.length; i++) {
    final word = line.words[i];
    if (word.chord != null) {
      buffer.write('[${word.chord}]');
    }
    buffer.write(word.text);
    final isLast = i == line.words.length - 1;
    if (!isLast && word.text.isNotEmpty) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```powershell
flutter test test/features/songs/editor/editable_document_test.dart
```

Expected: PASS (4 tests). If the "round-trips chords, words, and section labels" or "consecutive chords" tests fail, trace `_lineToChordProText` by hand against the failing input — the space-insertion rule (only add a separating space after a *non-empty* word's text) is what keeps spacing correct when a segment's text is empty (back-to-back chords) or ends in a space (the common case before the next chord). Fix the rule, don't loosen the test.

- [ ] **Step 5: Commit**

```powershell
cd "C:\wamp64\www\arc"
git add arc_app/lib/features/songs/editor/editable_document.dart arc_app/test/features/songs/editor/editable_document_test.dart
git commit -m "Add editable lyrics document model with ChordPro round-trip

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Chord builder (TDD)

**Files:**
- Create: `lib/features/songs/editor/chord_builder.dart`
- Test: `test/features/songs/editor/chord_builder_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/songs/editor/chord_builder_test.dart`:

```dart
import 'package:arc_app/features/songs/editor/chord_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildChord', () {
    test('builds a plain major chord with no suffix', () {
      expect(buildChord(root: 'G'), 'G');
    });

    test('builds a chord with a quality suffix', () {
      expect(buildChord(root: 'D', type: 'm7'), 'Dm7');
    });

    test('builds a slash chord when a bass note is given', () {
      expect(buildChord(root: 'D', bass: 'F#'), 'D/F#');
      expect(buildChord(root: 'D', type: 'm', bass: 'F'), 'Dm/F');
    });

    test('ignores an empty bass string the same as no bass', () {
      expect(buildChord(root: 'C', bass: ''), 'C');
    });
  });

  test('chordRoots has exactly the 12 chromatic notes, sharps preferred', () {
    expect(chordRoots, [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/features/songs/editor/chord_builder_test.dart
```

Expected: FAIL — `chord_builder.dart` does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/songs/editor/chord_builder.dart`:

```dart
/// Chromatic root notes, sharps preferred — matches the app's transposer
/// default (see lib/core/chordpro/transposer.dart).
const chordRoots = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Chord qualities offered in the picker. The empty string means "major"
/// (no suffix).
const chordTypes = ['', 'm', '7', 'm7', 'sus2', 'sus4', 'maj7', 'dim', 'aug', '6', '9'];

/// Builds a chord symbol like "D", "Dm7", or "D/F#" from its parts. [root]
/// is expected to be one of [chordRoots]. [type] is one of [chordTypes]
/// ('' for major). [bass] is an optional root-note override for a slash
/// chord — pass null or '' for none.
String buildChord({required String root, String type = '', String? bass}) {
  final base = '$root$type';
  if (bass == null || bass.isEmpty) return base;
  return '$base/$bass';
}
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/features/songs/editor/chord_builder_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```powershell
cd "C:\wamp64\www\arc"
git add arc_app/lib/features/songs/editor/chord_builder.dart arc_app/test/features/songs/editor/chord_builder_test.dart
git commit -m "Add chord builder for the visual chord picker

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Chord picker bottom sheet

**Files:**
- Create: `lib/features/songs/editor/chord_picker_sheet.dart`

No dedicated widget test for this task — it's UI-only and verified via `flutter analyze` plus manual check once wired into the editor in Task 5, matching how other picker/sheet widgets in this app were built (e.g. `AddSongToSetlistScreen`).

- [ ] **Step 1: Implement the sheet**

Create `lib/features/songs/editor/chord_picker_sheet.dart`:

```dart
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
```

- [ ] **Step 2: Verify**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: only the 2 pre-existing infos, no new issues.

- [ ] **Step 3: Commit**

```powershell
cd "C:\wamp64\www\arc"
git add arc_app/lib/features/songs/editor/chord_picker_sheet.dart
git commit -m "Add chord picker bottom sheet

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Song lyrics editor widget

**Files:**
- Create: `lib/features/songs/editor/song_lyrics_editor.dart`

This widget renders the editable document as section blocks of word chips. Each word is a small text field with a tappable chord slot above it; tapping "+" between words is realized as tapping a word's own chord slot (attaching the chord to that word, i.e. "the chord before this word") — read `docs/superpowers/specs/2026-09-28-visual-chord-editor-design.md` if you want the full rationale, but this task's code is self-contained.

A `TextEditingController` is created **once per word** and only recreated when the word count in a line actually changes (add/remove word or line) — never on every keystroke — so typing doesn't lose cursor position or focus. This is the one subtle correctness requirement in this task; get it wrong and typing will stutter or lose focus every keystroke.

- [ ] **Step 1: Implement the widget**

Create `lib/features/songs/editor/song_lyrics_editor.dart`:

```dart
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
  const _SectionBlock({required this.section, required this.onChanged, this.onRemove});

  final EditableSection section;
  final ValueChanged<EditableSection> onChanged;
  final VoidCallback? onRemove;

  void _updateLine(int index, EditableLine updated) {
    final lines = List<EditableLine>.from(section.lines);
    lines[index] = updated;
    onChanged(EditableSection(label: section.label, lines: lines));
  }

  void _addLine() {
    onChanged(EditableSection(label: section.label, lines: [...section.lines, EditableLine()]));
  }

  void _removeLine(int index) {
    final lines = List<EditableLine>.from(section.lines)..removeAt(index);
    if (lines.isEmpty) lines.add(EditableLine());
    onChanged(EditableSection(label: section.label, lines: lines));
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
            _LineEditor(
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
  const _LineEditor({required this.line, required this.onChanged, this.onRemove});

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
    widget.onChanged(EditableLine(words: words));
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
    widget.onChanged(EditableLine(words: [...widget.line.words, EditableWord(text: '')]));
  }

  void _removeWord(int index) {
    final words = List<EditableWord>.from(widget.line.words)..removeAt(index);
    if (words.isEmpty) words.add(EditableWord(text: ''));
    widget.onChanged(EditableLine(words: words));
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
```

`_removeWord` is currently unused (no button calls it yet — the design only asks for adding words and removing whole lines/sections). Either wire a small remove affordance per word (e.g. long-press on the chord slot, or a tiny "×" that appears only when a word's text is empty) or leave it unused and let `flutter analyze` tell you whether an unused-private-method lint fires; if it does, either use it (recommended: long-press the chord/word column to remove that word when its text is empty) or remove the method. Use your judgement — this is a minor UX nicety, not a spec requirement, so don't over-build it.

- [ ] **Step 2: Verify**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: only the 2 pre-existing infos, plus resolve the `_removeWord` situation per the note above so there are zero new issues.

- [ ] **Step 3: Commit**

```powershell
cd "C:\wamp64\www\arc"
git add arc_app/lib/features/songs/editor/song_lyrics_editor.dart
git commit -m "Add SongLyricsEditor widget with word-level chord chips

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Wire the visual editor into SongEditorScreen

**Files:**
- Modify: `lib/features/songs/song_editor_screen.dart`

Read the current file before editing — it was last touched in the Arca redesign (wrapped in `ContentFrame`). Replace the `_contentController`-backed `TextField` with `SongLyricsEditor` state, and rename the "Notas" label to "Indicaciones" (the underlying `notes` field name and `Song.notes` property do NOT change, only the visible label).

- [ ] **Step 1: Replace the file**

Replace the full contents of `lib/features/songs/song_editor_screen.dart` with:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/content_frame.dart';
import 'editor/editable_document.dart';
import 'editor/song_lyrics_editor.dart';
import 'song.dart';
import 'song_list_provider.dart';

class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.existingSong});

  /// Null when creating a new song, non-null when editing one.
  final Song? existingSong;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  late final _titleController = TextEditingController(text: widget.existingSong?.title);
  late final _artistController = TextEditingController(text: widget.existingSong?.artist);
  late final _keyController =
      TextEditingController(text: widget.existingSong?.originalKey ?? 'C');
  late final _tempoController =
      TextEditingController(text: widget.existingSong?.tempo?.toString());
  late final _timeSignatureController =
      TextEditingController(text: widget.existingSong?.timeSignature);
  late final _notesController = TextEditingController(text: widget.existingSong?.notes);

  late List<EditableSection> _lyricsSections = _initialSections();

  List<EditableSection> _initialSections() {
    final content = widget.existingSong?.content;
    if (content == null || content.trim().isEmpty) {
      return [EditableSection(label: 'verse')];
    }
    return parseToEditable(content);
  }

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _timeSignatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawTempo = _tempoController.text.trim();
    final tempo = rawTempo.isEmpty ? null : int.tryParse(rawTempo);
    if (rawTempo.isNotEmpty && tempo == null) {
      setState(() => _errorMessage = 'El tempo debe ser un número (BPM).');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final song = Song(
      id: widget.existingSong?.id ?? 0,
      title: _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
      originalKey: _keyController.text.trim(),
      tempo: tempo,
      timeSignature:
          _timeSignatureController.text.trim().isEmpty ? null : _timeSignatureController.text.trim(),
      content: editableToChordPro(_lyricsSections),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      attachments: widget.existingSong?.attachments ?? [],
    );

    try {
      final repository = ref.read(songRepositoryProvider);
      if (widget.existingSong == null) {
        await repository.create(song);
      } else {
        await repository.update(song);
      }
      await ref.read(songListProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo guardar la canción.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Extracts a clean, user-facing message from a failed save request.
  /// Laravel returns validation errors as `{"errors": {"field": ["msg"]}}`
  /// on a 422 — surface the first one instead of the raw exception text.
  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstFieldErrors = errors.values.first;
      if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
        return firstFieldErrors.first.toString();
      }
    }
    return 'No se pudo guardar la canción. Verificá tu conexión e intentá de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSong != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar canción' : 'Nueva canción')),
      body: ContentFrame(
        maxWidth: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _artistController,
                decoration: const InputDecoration(labelText: 'Artista'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(labelText: 'Tonalidad *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tempoController,
                      decoration: const InputDecoration(labelText: 'Tempo (BPM)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeSignatureController,
                decoration: const InputDecoration(labelText: 'Compás (ej: 4/4)'),
              ),
              const SizedBox(height: 20),
              Text('Letra y acordes', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SongLyricsEditor(
                sections: _lyricsSections,
                onChanged: (updated) => setState(() => _lyricsSections = updated),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Indicaciones'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all 32 tests pass (23 existing + 4 + 5 new from Tasks 1–2).

- [ ] **Step 3: Commit**

```powershell
cd "C:\wamp64\www\arc"
git add arc_app/lib/features/songs/song_editor_screen.dart
git commit -m "Replace free-text ChordPro field with the visual lyrics editor

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Show "Indicaciones" on the song detail screen

**Files:**
- Modify: `lib/features/songs/song_detail_screen.dart`

Read the current file before editing (it has `header`, `keyControls`, `lyrics`, `attachments` local variables built in `build()`, laid out differently for wide vs. narrow via `isWide(context)`). Add an `indications` variable, built only when `_song.notes` has content, and insert it into both layouts right after `header` and before `keyControls`.

- [ ] **Step 1: Add the indications builder**

In `_SongDetailScreenState`, add this getter near `_metaLine`:

```dart
  Widget? get _indicationsCard {
    final notes = _song.notes?.trim();
    if (notes == null || notes.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ArcaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INDICACIONES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 6),
            Text(notes),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: Insert it into both layouts**

In `build()`, add a local variable right after the existing `header` variable is defined:

```dart
    final indications = _indicationsCard;
```

Then, in the wide (`Row`) branch, inside the `Column` that currently reads `children: [header, keyControls, const SizedBox(height: 16), lyrics]`, change it to:

```dart
                        children: [
                          header,
                          if (indications != null) indications,
                          keyControls,
                          const SizedBox(height: 16),
                          lyrics,
                        ],
```

And in the narrow (`ListView`) branch, currently `children: [header, keyControls, const SizedBox(height: 16), lyrics, const SizedBox(height: 16), attachments]`, change it to:

```dart
                children: [
                  header,
                  if (indications != null) indications,
                  keyControls,
                  const SizedBox(height: 16),
                  lyrics,
                  const SizedBox(height: 16),
                  attachments,
                ],
```

(Adjust indentation to match the surrounding code — these snippets show the list contents, not exact column position, since the file's exact indentation may differ slightly from what's shown here.)

- [ ] **Step 3: Verify**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all 32 tests pass.

- [ ] **Step 4: Commit**

```powershell
cd "C:\wamp64\www\arc"
git add arc_app/lib/features/songs/song_detail_screen.dart
git commit -m "Show Indicaciones card on the song detail screen when present

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Manual verification and push

**Files:** none (verification + git)

- [ ] **Step 1: Full checks**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all 32 tests pass.

- [ ] **Step 2: Manual check in the browser**

Run the app (`flutter run -d web-server --web-port 4201`, Laravel backend on 4200, test user `test@arc.local` / `password123`) and check:
- Create a new song: confirm it starts with one "VERSO" section and one empty line.
- Type a few words into the line; confirm typing doesn't lose focus or jump the cursor.
- Tap the "+" chord slot above a word; confirm the picker opens, build a chord (e.g. root D, type m7, bass F#), confirm the preview reads "Dm7/F#", tap Insert, confirm the chord chip appears above that word in gold.
- Tap that chord chip again; confirm the picker reopens pre-filled with D / m7 / F# selected, and that "Quitar acorde" removes it.
- Add a second section (Coro), add a line, save the song, then open it in `SongDetailScreen` and confirm the chords render correctly transposed exactly as before this change.
- Edit an existing song (e.g. "Sublime Gracia") — confirm its existing chords load correctly as chips on the right words (not scrambled).
- Type something into "Indicaciones", save, and confirm it now appears in an "INDICACIONES" card on the detail screen; confirm it does NOT appear for a song with empty notes.

- [ ] **Step 3: Push**

```powershell
cd "C:\wamp64\www\arc"
git branch --show-current
git push origin working
```

Expected: branch is `working`; push succeeds.
