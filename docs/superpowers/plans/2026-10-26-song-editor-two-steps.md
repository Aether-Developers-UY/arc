# Song Editor Two Steps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the song create/edit form into two full screens inside `SongEditorScreen` — step 1 metadata, step 2 lyrics + indications — with nothing persisted until "Guardar" on step 2.

**Architecture:** `SongEditorScreen` stays the single owner of all state (controllers, `_lyricsSections`, saving/error flags) and gains an `int _step`. Each step's UI moves into a stateless, controlled widget under `lib/features/songs/editor/`. The save logic, `SongLyricsEditor`, and the backend are untouched.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Riverpod 3.x, `flutter_test` widget tests, existing Arca theme (`ArcaTheme`, `context.arca`).

**Spec:** `docs/superpowers/specs/2026-09-29-song-editor-two-steps-design.md`

## Global Constraints

- Work in `C:\wamp64\www\arc\arc_app`, branch `working`; commit locally, push only in the last task.
- The bash tool may not find `flutter`; use the PowerShell tool for `flutter analyze` / `flutter test`.
- Baseline before this plan: `flutter analyze` shows exactly 2 pre-existing `info` items (`onReorder` deprecation in `setlist_detail_screen.dart`, `use_null_aware_elements` in `setlist_repository.dart`); 34 tests pass. No new analyzer issues.
- UI copy is Spanish, voseo, sentence case. Button labels: "Siguiente", "Atrás", "Guardar". Step indicator: "Paso 1 de 2" / "Paso 2 de 2". AppBar titles stay "Nueva canción" / "Editar canción".
- Widget tests must set `ArcaTheme.useGoogleFonts = false` in `setUp` (no network in tests) and wrap widgets in `MaterialApp(theme: ArcaTheme.light(), ...)`.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

- Non-numeric tempo (step 1 field) — must be reported on step 1 when pressing "Siguiente", not first discovered on step 2 where the tempo field is not visible. Pinned in Task 2.
- Title or key that is only whitespace — treated as empty; "Siguiente" must not advance. Pinned in Task 2.
- Going back from step 2 then forward again — typed title and lyrics must survive both directions. Pinned in Task 2.
- A validation error shown on step 1 must not still be showing after moving to step 2 and back (and a save error must not leak onto step 1). Pinned in Task 2.
- System/browser back on step 2 — returns to step 1, does not close the editor and lose the lyrics. Pinned in Task 2.

---

### Task 1: Step widgets

**Files:**
- Create: `lib/features/songs/editor/song_metadata_step.dart`
- Create: `lib/features/songs/editor/song_lyrics_step.dart`
- Test: `test/features/songs/editor/song_steps_test.dart`

**Interfaces:**
- Consumes: `SongLyricsEditor({required List<EditableSection> sections, required ValueChanged<List<EditableSection>> onChanged})` from `editor/song_lyrics_editor.dart`; `EditableSection` from `editor/editable_document.dart`.
- Produces:
  - `SongMetadataStep({required TextEditingController titleController, required TextEditingController artistController, required TextEditingController keyController, required TextEditingController tempoController, required TextEditingController timeSignatureController, required String? errorMessage, required VoidCallback onNext})` — a `StatelessWidget`.
  - `SongLyricsStep({required List<EditableSection> sections, required ValueChanged<List<EditableSection>> onSectionsChanged, required TextEditingController notesController, required bool isSaving, required String? errorMessage, required VoidCallback onBack, required VoidCallback onSave})` — a `StatelessWidget`.

- [ ] **Step 1: Write the failing tests** in `test/features/songs/editor/song_steps_test.dart`, with a `pump` helper that wraps a widget in `MaterialApp(theme: ArcaTheme.light(), home: Scaffold(body: SingleChildScrollView(child: widget)))` and a `setUp` setting `ArcaTheme.useGoogleFonts = false`. Tests:
  - `metadata step renders its five fields and a Siguiente button`: find labels `Título *`, `Artista`, `Tonalidad *`, `Tempo (BPM)`, `Compás (ej: 4/4)` and `find.text('Siguiente')`.
  - `metadata step calls onNext when Siguiente is tapped`: counter goes 0 → 1.
  - `metadata step shows the error message when given one`: pass `errorMessage: 'Falta el título'`, `find.text('Falta el título')` finds one widget.
  - `lyrics step shows Atrás and Guardar and calls their callbacks`: tap each, both counters 1.
  - `lyrics step disables Guardar while saving`: with `isSaving: true`, the `FilledButton` has `onPressed == null`.
  - `lyrics step shows the error message and the Indicaciones field`: `find.text('Indicaciones')` (label) and the error text each found once.
  - Build `sections` as `[EditableSection(label: 'verse')]` and controllers with `TextEditingController()`.
- [ ] **Step 2: Run to verify they fail**
  Run: `flutter test test/features/songs/editor/song_steps_test.dart` — Expected: FAIL (the two files don't exist).
- [ ] **Step 3: Implement `SongMetadataStep` in `song_metadata_step.dart`.** Move the five `TextField`s verbatim from the current `SongEditorScreen.build` (same labels, same `Row` with key + tempo, same `keyboardType: TextInputType.number` on tempo, same spacing), then the error `Text` (color `Theme.of(context).colorScheme.error`, only when `errorMessage != null`), then a `FilledButton` labelled "Siguiente" wired to `onNext`.
- [ ] **Step 4: Implement `SongLyricsStep` in `song_lyrics_step.dart`.** Move the "Letra y acordes" `Text` (`titleSmall`), the `SongLyricsEditor`, and the Indicaciones `TextField` (`maxLines: 3`) verbatim from the current build; then the error `Text`; then a `Row` with an `OutlinedButton` "Atrás" (`onBack`) and an expanded `FilledButton` "Guardar" (`onSave`, `null` while `isSaving`, showing the existing 20×20 `CircularProgressIndicator(strokeWidth: 2)` instead of the label while saving).
- [ ] **Step 5: Run to verify they pass**
  Run: `flutter test test/features/songs/editor/song_steps_test.dart` — Expected: PASS (6 tests).
- [ ] **Step 6: Commit** `lib/features/songs/editor/song_metadata_step.dart`, `lib/features/songs/editor/song_lyrics_step.dart`, the test file — message `Add metadata and lyrics step widgets for the song editor`.

---

### Task 2: Two-step flow in SongEditorScreen

**Files:**
- Modify: `lib/features/songs/song_editor_screen.dart`
- Test: `test/features/songs/song_editor_screen_test.dart`

**Interfaces:**
- Consumes: `SongMetadataStep` and `SongLyricsStep` from Task 1 (signatures above); `Song`, `songRepositoryProvider` unchanged.
- Produces: `SongEditorScreen({Key? key, Song? existingSong})` — public API unchanged.

- [ ] **Step 1: Write the failing tests** in `test/features/songs/song_editor_screen_test.dart`. Helper `pumpEditor(tester, {Song? existingSong})` pumps `ProviderScope(child: MaterialApp(theme: ArcaTheme.light(), home: SongEditorScreen(existingSong: existingSong)))`; `setUp` sets `ArcaTheme.useGoogleFonts = false`. Tests (all use `find.text`/`find.widgetWithText`, `enterText`, `tap`, `pumpAndSettle`):
  - `starts on step 1 with the "Paso 1 de 2" indicator and no lyrics editor`.
  - `Siguiente with an empty title stays on step 1 and shows an error` (error text contains `título`).
  - `Siguiente with a whitespace-only title stays on step 1` (enter `'   '` in Título).
  - `Siguiente with a whitespace-only key stays on step 1` (clear Tonalidad — default `C` — then enter `'  '`).
  - `Siguiente with a non-numeric tempo stays on step 1 and shows a tempo error` (error text contains `tempo`).
  - `Siguiente with valid title advances to step 2` (indicator `Paso 2 de 2`, `find.text('Guardar')` found).
  - `Atrás returns to step 1 keeping the typed title` (type `Mi canción`, Siguiente, Atrás, `find.text('Mi canción')` found).
  - `the step 1 error is cleared after advancing and coming back` (trigger error with empty title, enter a title, Siguiente, Atrás, error text not found).
  - `system back on step 2 returns to step 1 instead of closing the editor` (advance, call `tester.binding.handlePopRoute()`, pump; `Paso 1 de 2` found and `SongEditorScreen` still present). The screen must be pushed from a host route for this to be meaningful: pump a `MaterialApp(home: Builder(... ElevatedButton → Navigator.push(SongEditorScreen())))` and tap it first.
  - `editing an existing song prefills both steps` (a `Song` with title `Sublime Gracia`, notes `Empezar solo con piano`, content `{verse}\n[G]Sublime`; step 1 shows the title; after Siguiente, the notes text is present in the Indicaciones field).
  - `editing a song with blank content starts step 2 with an empty verse section` (content `''`; after Siguiente, no exception and the lyrics editor shows `VERSO`).
- [ ] **Step 2: Run to verify they fail**
  Run: `flutter test test/features/songs/song_editor_screen_test.dart` — Expected: FAIL (no step indicator exists yet).
- [ ] **Step 3: Add step state to `_SongEditorScreenState`.** Add `int _step = 0`. Add `String? _validateMetadata()` returning a Spanish message or `null`: empty/whitespace title → `'Ingresá el título de la canción.'`; empty/whitespace key → `'Ingresá la tonalidad.'`; non-empty tempo that fails `int.tryParse` → `'El tempo debe ser un número (BPM).'` (checked in that order). Add `_goNext()`: `final error = _validateMetadata(); setState(() { _errorMessage = error; if (error == null) _step = 1; });`. Add `_goBack()`: `setState(() { _step = 0; _errorMessage = null; })`.
- [ ] **Step 4: Make `_save` reuse the validation.** Replace its inline tempo check with `_validateMetadata()`; if it returns an error, `setState(() { _step = 0; _errorMessage = error; })` and return. Keep the rest of `_save` (Song construction, create/update, `DioException` → `_messageFor`) exactly as is; the tempo for the `Song` is parsed with the same `rawTempo.isEmpty ? null : int.tryParse(rawTempo)`.
- [ ] **Step 5: Rewrite `build`.** `AppBar(title: Text(isEditing ? 'Editar canción' : 'Nueva canción'), bottom: PreferredSize(preferredSize: Size.fromHeight(24), child: Text('Paso ${_step + 1} de 2'))` styled with `context.arca.textSecondary`). Body: the existing `ContentFrame(maxWidth: 640, child: SingleChildScrollView(padding: vertical 16, ...))` containing `SongMetadataStep(... onNext: _goNext)` when `_step == 0`, else `SongLyricsStep(... onBack: _goBack, onSave: _save)`. Pass `_errorMessage` only to the step that is showing. Wrap the `Scaffold` in `PopScope(canPop: _step == 0, onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); })`. Remove the now-unused imports.
- [ ] **Step 6: Run to verify they pass**
  Run: `flutter test test/features/songs/song_editor_screen_test.dart` — Expected: PASS (11 tests).
- [ ] **Step 7: Full checks**
  Run: `flutter analyze` — Expected: only the 2 baseline infos. Run: `flutter test` — Expected: all pass (34 + 6 + 11 = 51).
- [ ] **Step 8: Commit** `lib/features/songs/song_editor_screen.dart` and the test file — message `Split the song editor into metadata and lyrics steps`.

---

### Task 3: Browser check and push

**Files:** none.

- [ ] **Step 1: Manual check** with backend on 4200 and `flutter run -d web-server --web-port 4201` (login `test@arc.local` / `password123`). Create a song through both steps; edit an existing song and go back and forth; confirm the step 1 validation messages and that the song only appears in the list after "Guardar".
- [ ] **Step 2: Push** — `git branch --show-current` prints `working`, then `git push origin working` — Expected: push succeeds.
