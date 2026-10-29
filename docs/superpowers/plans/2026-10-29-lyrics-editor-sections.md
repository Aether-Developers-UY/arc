# Editor de letra por secciones: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el editor palabra por palabra del paso 2 por secciones con un campo de texto grande cada una (modo Letra) y por palabras tocables para poner acordes (modo Acordes).

**Architecture:** El modelo `EditableSection → EditableLine → EditableWord` se mantiene. Encima se agregan dos funciones puras:
- `sectionText` convierte una sección en el texto plano del campo.
- `applyText` convierte el texto editado en una sección y reubica los acordes alineando líneas y palabras.

El widget del editor se reescribe con una tarjeta por sección y dos modos. El modo vive en `SongEditorScreen`, para que sobreviva a ir y volver del paso 1. Se sigue guardando ChordPro. El lector suma `intro`/`interlude` y la vista de la canción muestra las etiquetas en castellano.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_test. Sin dependencias nuevas, sin backend.

**Spec:** `docs/superpowers/specs/2026-10-29-lyrics-editor-sections-design.md`

## Global Constraints

- Etiquetas de sección (clave ChordPro → nombre):
  - `intro` → Intro
  - `verse` → Verso
  - `chorus` → Coro
  - `bridge` → Puente
  - `interlude` → Interludio
  - `tag` → Otro (solo lectura de canciones viejas, no se ofrece al agregar)
  - desconocida o null → Sección
- Orden del menú "+ Sección": Intro, Verso, Coro, Puente, Interludio.
- Secciones de solo acordes: `intro` e `interlude`.
- Textos de interfaz (castellano rioplatense, voseo), copiados tal cual:
  - modos: `Letra`, `Acordes`;
  - ayuda de Intro e Interludio: `Acordes separados por espacios, ej.: G D Em C`;
  - ayuda del campo de letra: `Escribí o pegá la letra`;
  - confirmación al quitar: título `¿Quitar este <Nombre>?` y cuerpo `Se pierde su letra y sus acordes.`, con los botones `Cancelar` y `Quitar`;
  - sección sin acordes: `Tocá una palabra para ponerle acorde`;
  - sección vacía en modo Acordes: `Sin letra todavía. Escribila en el modo Letra.`;
  - Intro o Interludio vacíos en modo Acordes: `Sin acordes todavía. Escribilos en el modo Letra.`;
  - tooltips: `Subir sección`, `Bajar sección`, `Quitar sección`.
- Línea de solo acordes serializada como `[G]  [D]  [Em]  [C]` (dos espacios entre acordes).
- Commits y push solo a `origin/working`.

## Review Focus

1. **Pegar una letra con espacios dobles, tabs o espacios al final de un renglón.** Las palabras se separan por cualquier espacio en blanco y no se crean palabras vacías. → test en Task 2.
2. **Escribir en una línea que tiene un acorde a mitad de palabra (`salv[G]ó`) sin tocar esa palabra.** El acorde a mitad de palabra se conserva. → test en Task 2.
3. **Borrar todo el texto de una sección y volver a escribirlo.** No hay crash. La sección vacía tiene una línea vacía, y lo reescrito no tiene acordes. → test en Task 2.
4. **Pasar al modo Acordes con una sección cuyo texto tiene líneas en blanco intermedias.** Las líneas en blanco se ven como separación y no son tocables. → test en Task 3.
5. **Escribir rápido en el campo.** El cursor no salta al final ni se pierde el foco en cada tecla: el controller es estable por id de sección y no se reescribe desde el modelo mientras se escribe. → test en Task 3.

---

### Task 1: Nombres de sección, Intro e Interludio en el lector y etiquetas en castellano en la vista

**Files:**
- Create: `arc_app/lib/core/chordpro/section_names.dart`
- Modify: `arc_app/lib/core/chordpro/chordpro_parser.dart` (`_sectionDirectiveNames`)
- Modify: `arc_app/lib/features/songs/song_detail_screen.dart` (`_Lyrics`, `_ChordLine`)
- Test: `arc_app/test/core/chordpro/chordpro_parser_test.dart`, `arc_app/test/core/chordpro/section_names_test.dart`, `arc_app/test/features/songs/song_detail_lyrics_test.dart`

**Interfaces:**
- Produces, en `section_names.dart`:
  - `const addableSectionLabels = ['intro', 'verse', 'chorus', 'bridge', 'interlude'];`
  - `String sectionName(String? label)`: el nombre en castellano, o `'Sección'` si la etiqueta es null o desconocida.
  - `bool isChordOnlySection(String? label)`: true para `intro` e `interlude`.

- [ ] **Step 1: Tests que fallan**
  - `section_names_test.dart`:
    - `sectionName('interlude') == 'Interludio'`;
    - `sectionName('tag') == 'Otro'`;
    - `sectionName(null) == 'Sección'`;
    - `isChordOnlySection('intro')` es true y `isChordOnlySection('verse')` es false.
  - `chordpro_parser_test.dart`, test `'{intro} and {interlude} are section headings'`: al parsear `"{intro}\n[G]  [D]\n{interlude}"`, `lines[0].sectionLabel == 'intro'` y `lines[2].sectionLabel == 'interlude'`.
  - `song_detail_lyrics_test.dart`: arma `SongDetailScreen(song: …)` con `content: '{verse}\n[G]Hola\n{chorus}\nCoro\n{intro}\n[G]  [D]'` (copiar el armado de `song_detail_delete_test.dart`).
    - `'section headings show in Spanish'`: se ven `VERSO`, `CORO` e `INTRO`, y no `VERSE` ni `CHORUS`.
    - `'a chords-only line shows each chord'`: se ven `find.text('G')` y `find.text('D')`, y no hay excepción.
- [ ] **Step 2:** Correr `flutter test test/core/chordpro test/features/songs/song_detail_lyrics_test.dart`. Esperado: FAIL.
- [ ] **Step 3: Implementar**
  - Crear `section_names.dart`.
  - Sumar `'intro', 'interlude'` a `_sectionDirectiveNames`.
  - En `_Lyrics`, usar `sectionName(line.sectionLabel).toUpperCase()`.
  - En `_ChordLine`, cuando todos los segmentos tienen `text.trim().isEmpty`, mostrar solo los acordes en un `Wrap(spacing: 16)`, sin la fila de letra.
- [ ] **Step 4:** Correr el mismo comando. Esperado: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add arc_app/lib/core/chordpro arc_app/lib/features/songs/song_detail_screen.dart arc_app/test/core/chordpro arc_app/test/features/songs/song_detail_lyrics_test.dart
  git commit -m "feat(canciones): secciones Intro e Interludio y etiquetas en castellano"
  ```

### Task 2: `sectionText` / `applyText` y líneas de solo acordes en el modelo

**Files:**
- Modify: `arc_app/lib/features/songs/editor/editable_document.dart`
- Test: `arc_app/test/features/songs/editor/editable_document_test.dart` (grupos nuevos)

**Interfaces:**
- Consumes: `isChordOnlySection` (Task 1).
- Produces, en `editable_document.dart`:
  - `bool get isChordOnly` en `EditableLine`: true si tiene al menos una palabra con acorde y todas sus palabras tienen texto vacío.
  - `String sectionText(EditableSection section)`: las líneas unidas con `\n`. Omite las `rawDirective`.
    - Una línea normal se escribe con sus palabras sin acordes, agregando `' '` solo después de las palabras con `spaceAfter` que no son la última.
    - En una sección de solo acordes, cada línea se escribe como sus acordes unidos con `'  '`.
  - `EditableSection applyText(EditableSection section, String text)`: devuelve una sección nueva.
    - Conserva el mismo `id` y `label`.
    - Las líneas `rawDirective` van primero, en su orden original.
    - Conserva el `id` de cada línea emparejada.
    - Texto vacío produce una línea `EditableLine()`.

- [ ] **Step 1: Tests que fallan** (grupo `'applyText keeps chords on their words'`)

  Todas las secciones de prueba se arman con `parseToEditable` y se verifican con `editableToChordPro([applyText(s, …)])`.

  | Contenido original | Texto aplicado | Esperado |
  |---|---|---|
  | `{verse}\n[G]Sublime [C]gracía del Señor` | `Sublime gracia del Señor` | `{verse}\n[G]Sublime [C]gracia del Señor` |
  | `{verse}\n[G]Sublime [C]gracia` | `Oh Sublime gracia` | `{verse}\nOh [G]Sublime [C]gracia` |
  | `{verse}\n[G]Uno\n[D]Dos` | `Nueva\nUno\nDos` | `{verse}\nNueva\n[G]Uno\n[D]Dos` |
  | `{verse}\n[G]Uno\n[D]Dos` | `Dos` | `{verse}\n[D]Dos` |
  | `{verse}\n[G]Sublime [C]gracia` | `Sublime` | `{verse}\n[G]Sublime` |
  | `{verse}\nque a un infeliz salv[G]ó` | `que a un pobre infeliz salvó` | `{verse}\nque a un pobre infeliz salv[G]ó` |
  | `{verse}\n[G]Uno` | `` y después `Uno` | `{verse}\nUno`, sin excepción |
  | `{verse}\n[G]Hola` | `Hola   mundo\t ` | `{verse}\n[G]Hola mundo` |
  | `{verse}\n[G]Uno\n\n[D]Dos` | sin cambios | idéntico (la línea en blanco se mantiene) |

  - Columna "Esperado": la columna 2 es por posición (palabra reemplazada en su lugar); la 6, `salv[G]ó`, es Review Focus 2; la 7, borrar todo y reescribir, es Review Focus 3; la 8, espacios y tabs, es Review Focus 1.
  - `'applyText preserves {title:} directives'`: con `{verse}\n{title: X}\n[G]Uno` y el texto `Uno`, el resultado es `{verse}\n{title: X}\n[G]Uno`.
  - Grupo `'untitled leading content'` (spec: lo que no tiene sección se abre como Verso):
    - con `parseToEditable('Hola\n{chorus}\nCoro')`, la primera sección tiene `label == 'verse'`;
    - con `parseToEditable('{title: X}\n{verse}\nUno')` hay una sola sección, `verse`, y su primera línea es la `rawDirective` `{title: X}`. Una sección inicial que solo tiene directivas se fusiona con la siguiente, que pasa a tenerlas al principio.
    - Actualizar las expectativas de los tests de ida y vuelta existentes que tengan contenido inicial sin sección: ahora se guarda con `{verse}` adelante.
  - Grupo `'chord-only sections'`:
    - `sectionText(parseToEditable('{intro}\n[G]  [D]  [Em]').first) == 'G  D  Em'`;
    - `editableToChordPro([applyText(EditableSection(label: 'intro'), 'G D\nEm  C')]) == '{intro}\n[G]  [D]\n[Em]  [C]'`;
    - hay ida y vuelta de `'{intro}\n[G]  [D]'` sin cambios.
- [ ] **Step 2:** Correr `flutter test test/features/songs/editor/editable_document_test.dart`. Esperado: FAIL por las funciones que no existen. Los tests de ida y vuelta existentes siguen en PASS.
- [ ] **Step 3: Implementar**
  - **Sección inicial sin etiqueta.** En `parseToEditable`, la sección inicial sin etiqueta pasa a ser `verse`. Si solo tiene `rawDirective`s y hay una sección siguiente, sus líneas se anteponen a esa sección y la inicial se descarta.
  - **Lectura.** En `parseToEditable`, una línea cuyos segmentos tienen todos texto vacío o solo espacios, y al menos un acorde, se convierte en palabras `EditableWord(text: '', chord: c)`.
  - **Escritura.** En `_lineToChordProText`, si `line.isChordOnly`, escribir `line.words.map((w) => '[${w.chord}]').join('  ')`.
  - **`applyText`.** Agrupar las palabras de cada línea vieja en *tokens*: una palabra más las siguientes mientras la anterior tenga `spaceAfter == false`. El texto de un token es el de sus palabras concatenado. La línea nueva se divide con `split(RegExp(r'\s+'))`, descartando vacíos. Alinear con este algoritmo, usado primero para las líneas (comparando texto) y después para los tokens:

  ```dart
  /// Pares (índiceViejo, índiceNuevo). Las coincidencias salen de la LCS;
  /// en cada tramo entre coincidencias, los elementos se emparejan en orden y
  /// los que sobran quedan con el otro lado en null.
  List<(int?, int?)> _align(List<String> a, List<String> b) {
    final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1]);
      }
    }
    final pairs = <(int?, int?)>[];
    var i = 0, j = 0;
    final gapA = <int>[], gapB = <int>[];
    void flush() {
      for (var k = 0; k < max(gapA.length, gapB.length); k++) {
        pairs.add((k < gapA.length ? gapA[k] : null, k < gapB.length ? gapB[k] : null));
      }
      gapA.clear();
      gapB.clear();
    }
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        flush();
        pairs.add((i++, j++));
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        gapA.add(i++);
      } else {
        gapB.add(j++);
      }
    }
    while (i < a.length) gapA.add(i++);
    while (j < b.length) gapB.add(j++);
    flush();
    return pairs;
  }
  ```

  Con los pares, para cada token nuevo:
  - **Idéntico:** reutiliza las `EditableWord` del token viejo, conservando acordes a mitad de palabra y `spaceAfter`.
  - **Emparejado pero distinto:** una sola palabra nueva con el primer acorde del token viejo.
  - **Sin pareja:** una palabra sin acorde.

  El token viejo sin pareja se descarta.

  En secciones de solo acordes, cada renglón se convierte en una línea de solo acordes, sin alineación.
- [ ] **Step 4:** Correr el mismo comando. Esperado: PASS, incluidos los tests viejos de ida y vuelta.
- [ ] **Step 5: Commit**
  ```bash
  git add arc_app/lib/features/songs/editor/editable_document.dart arc_app/test/features/songs/editor/editable_document_test.dart
  git commit -m "feat(editor): pasar la letra a texto y de vuelta conservando los acordes"
  ```

### Task 3: Editor por secciones con modos Letra y Acordes

**Files:**
- Rewrite: `arc_app/lib/features/songs/editor/song_lyrics_editor.dart` (se va `_LineEditor`)
- Test: `arc_app/test/features/songs/editor/song_lyrics_editor_test.dart` (nuevo)

**Interfaces:**
- Consumes:
  - `sectionText`, `applyText`, `EditableLine.isChordOnly` (Task 2);
  - `sectionName`, `addableSectionLabels`, `isChordOnlySection` (Task 1);
  - `showChordPicker(context, initialChord:)`, que ya existe.
- Produces:
  - `enum LyricsMode { lyrics, chords }`;
  - `SongLyricsEditor({required List<EditableSection> sections, required ValueChanged<List<EditableSection>> onChanged, required LyricsMode mode})`;
  - `LyricWord({required EditableWord word, required VoidCallback onTap})`: widget público para una palabra tocable en modo Acordes. Es público para que los tests lo encuentren.

- [ ] **Step 1: Tests que fallan** (pump con `StatefulBuilder` que guarda `sections` y las reenvía)
  - `'lyrics mode shows one text field per section with its name'`:
    - con secciones `verse` y `chorus`, se ven `find.text('VERSO')` y `find.text('CORO')`;
    - hay 2 `TextField`.
  - `'typing in a section updates the song keeping the cursor'` (Review Focus 5):
    - al escribir `'Hola mundo'` con `enterText`, `editableToChordPro(sections) == '{verse}\nHola mundo'`;
    - el controller conserva `selection.baseOffset == 10`.
  - `'+ Sección offers the five types and appends the chosen one'`: tocar `Sección` muestra `Intro`, `Verso`, `Coro`, `Puente` e `Interludio`; elegir `Coro` agrega una sección `chorus` al final.
  - `'sections move up and down'`: `Subir sección` sobre la segunda deja el orden `[chorus, verse]`.
  - `'removing a section with content asks first'`:
    - tocar `Quitar sección` en un Coro con letra muestra `¿Quitar este Coro?`;
    - `Cancelar` lo mantiene y `Quitar` lo saca;
    - en una sección vacía, quitar no muestra el diálogo.
  - `'intro field hints at chords'`: se ve `Acordes separados por espacios, ej.: G D Em C`.
  - `'chords mode: tapping a word opens the picker and sets the chord'`:
    - con `{verse}\nSublime gracia`, tocar `gracia`, después `G` en la grilla y después `Insertar` produce `{verse}\nSublime [G]gracia`;
    - antes de tocar, se ve `Tocá una palabra para ponerle acorde`.
  - `'chords mode: a word with a chord reopens the picker with Quitar acorde'`: con `[G]Hola`, tocar `Hola` y después `Quitar acorde` produce `{verse}\nHola`.
  - `'chords mode: blank lines are spacing, not words'` (Review Focus 4): con `{verse}\nUno\n\nDos`, no hay excepción y `find.byType(LyricWord)` encuentra exactamente 2.
  - `'chords mode: empty sections explain where to write'`:
    - un Verso vacío muestra `Sin letra todavía. Escribila en el modo Letra.`;
    - una Intro vacía muestra `Sin acordes todavía. Escribilos en el modo Letra.`.
- [ ] **Step 2:** Correr `flutter test test/features/songs/editor/song_lyrics_editor_test.dart`. Esperado: FAIL.
- [ ] **Step 3: Implementar**
  - **`_SectionCard`** (StatefulWidget, keyed por `section.id`):
    - Encabezado: nombre en mayúsculas en color primario y los `IconButton`s ↑ (`Icons.arrow_upward`), ↓ (`Icons.arrow_downward`) y ✕.
      - ↑ se deshabilita en la primera sección y ↓ en la última.
      - ✕ se oculta si queda una sola sección.
    - Modo Letra: `TextField` con `minLines: 3`, `maxLines: null`, `keyboardType: TextInputType.multiline`.
      - Controller creado en `initState` con `sectionText(section)` y nunca reasignado al teclear.
      - `onChanged: (t) => widget.onChanged(applyText(widget.section, t))`.
    - Al volver a modo Letra (`didUpdateWidget` con cambio de modo), se resincroniza `controller.text = sectionText(section)`.
  - **Modo Acordes:**
    - una línea normal es un `Wrap` de palabras;
    - cada palabra es un `LyricWord` (InkWell + MouseRegion) con el acorde arriba (estilo `ArcaTheme.mono`, color `context.arca.chord`) o, en hover, un `+` tenue;
    - una línea en blanco es un `SizedBox(height: 14)`;
    - una línea de solo acordes es un `Wrap(spacing: 16)` de acordes, no tocable.
  - **Al elegir en el picker:** se reemplaza la palabra en su línea y su sección, manteniendo los ids.
  - **"+ Sección":** usa un `OutlinedButton.icon` con el label `Sección` y una bottom sheet con `addableSectionLabels`.
- [ ] **Step 4:** Correr el mismo comando. Esperado: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add arc_app/lib/features/songs/editor/song_lyrics_editor.dart arc_app/test/features/songs/editor/song_lyrics_editor_test.dart
  git commit -m "feat(editor): secciones con campo de letra y modo para tocar palabras y poner acordes"
  ```

### Task 4: Selector Letra | Acordes en el paso 2 y modo inicial

**Files:**
- Modify: `arc_app/lib/features/songs/editor/song_lyrics_step.dart`
- Modify: `arc_app/lib/features/songs/song_editor_screen.dart`
- Test: `arc_app/test/features/songs/editor/song_steps_test.dart`, `arc_app/test/features/songs/song_editor_screen_test.dart`

**Interfaces:**
- Consumes: `LyricsMode`, `SongLyricsEditor` (Task 3).
- Produces: `SongLyricsStep` suma `required LyricsMode mode` y `required ValueChanged<LyricsMode> onModeChanged`.

- [ ] **Step 1: Tests que fallan**
  - En `song_steps_test.dart`, actualizar el helper `lyricsStep` con `mode: LyricsMode.lyrics, onModeChanged: (_) {}`.
    - Test nuevo `'lyrics step shows the Letra | Acordes switch'`: se ven `Letra` y `Acordes`, y tocar `Acordes` llama `onModeChanged(LyricsMode.chords)`.
  - En `song_editor_screen_test.dart`:
    - `'a new song starts step 2 in Letra mode'`: hay un `TextField` en la sección VERSO.
    - `'an existing song starts step 2 in Acordes mode'`: con `sampleSong()`, cuyo contenido tiene letra, la letra se ve como texto tocable y no hay `TextField` de sección.
    - `'write lyrics, add a chord and save'`, de punta a punta:
      1. título `Mi canción`, Siguiente;
      2. escribir `Cantaré al Señor`;
      3. tocar `Acordes`, después `Señor`, `D` e `Insertar`;
      4. Guardar.

      El repositorio fake recibe `content == '{verse}\nCantaré al [D]Señor'`.
  - El test existente `'typed lyrics survive going back to step 1 and forward again'` debe seguir pasando sin cambios.
- [ ] **Step 2:** Correr `flutter test test/features/songs`. Esperado: FAIL.
- [ ] **Step 3: Implementar**
  - `SongLyricsStep`: arriba del editor, un `SegmentedButton<LyricsMode>` con `Letra` (`Icons.notes`) y `Acordes` (`Icons.music_note`). Se reemplaza el título "Letra y acordes".
  - `SongEditorScreen`: el estado `_lyricsMode` arranca en `LyricsMode.chords` si `existingSong?.content` no está en blanco, y en `LyricsMode.lyrics` si no.
- [ ] **Step 4:** Correr `flutter test` (suite completa) y `flutter analyze`. Esperado: todo PASS. Solo quedan los 2 infos preexistentes (`onReorder`, `use_null_aware_elements`).
- [ ] **Step 5: Commit y push**
  ```bash
  git add arc_app/lib/features/songs arc_app/test/features/songs
  git commit -m "feat(editor): selector Letra | Acordes en el paso 2"
  git push origin working
  ```

### Task 5: Verificación en el navegador

- [ ] Reiniciar el preview `arc-frontend` y entrar con `test@arc.local`.
- [ ] Crear una canción con Intro (`G D`), Verso y Coro, y ponerle acordes tocando palabras. Corregir una palabra en Letra y confirmar que el acorde sigue en Acordes. Guardar.
- [ ] En la vista de la canción, revisar que se ven INTRO, VERSO y CORO, la fila de acordes de la Intro, y que transponer cambia también los acordes de la Intro.
- [ ] Abrir una canción existente: arranca en Acordes y no se pierde nada al guardar sin cambios.
- [ ] Revisar en ancho de celular (375 px) que las tarjetas no desbordan.
