# Editor de letra por secciones: diseño

## Objetivo

Hoy, en el paso 2 del editor de canciones, cada palabra es un campo aparte que se agrega con "+". Para poner acordes sirve, pero escribir o pegar una letra así es lentísimo.

Con este cambio, la letra se escribe en **un campo de texto grande por sección**. Los acordes se ponen en un segundo modo, **tocando la palabra**. Eso abre el mismo selector de acordes que existe hoy.

## Alcance

**Incluye**
- Secciones explícitas: **Intro, Verso, Coro, Puente, Interludio**. Cada una es un campo de texto grande.
- Dos modos en el paso 2: **Letra** (escribir) y **Acordes** (tocar palabras para ponerles acorde).
- Intro e Interludio son secciones **de solo acordes**: su campo se completa con acordes, por ejemplo `G  D  Em  C`.
- Los acordes se mantienen en sus palabras cuando se corrige la letra después de haberlos puesto.
- Agregar, quitar y mover (subir/bajar) secciones. Se pueden repetir, por ejemplo dos Versos.
- Las etiquetas de sección se muestran en castellano en la vista de la canción. Hoy salen "VERSE" y "CHORUS".

**No incluye (más adelante)**
- Acordes a mitad de palabra o sueltos al final de una línea con letra.
- Detectar acordes al pegar letra "con acordes arriba" de una web.
- Cambios en el backend. El contenido se sigue guardando como texto ChordPro en `songs.content`.

## Comportamiento

### Modos
- Arriba del paso 2 hay un selector **Letra | Acordes**, con el mismo estilo de `SegmentedButton` que el selector de vista.
- **Canción nueva**: arranca en *Letra*, con una sección *Verso* vacía.
- **Editar una canción existente con contenido**: arranca en *Acordes*.
- Se puede cambiar de modo en cualquier momento. *Guardar* funciona desde los dos.

### Modo Letra
- Cada sección es una tarjeta con:
  - un encabezado con el nombre (VERSO, CORO…);
  - los botones ↑ y ↓ para moverla, deshabilitados en los extremos;
  - el botón ✕ para quitarla.
- Debajo del encabezado está el **campo multilínea**. Cada renglón es una línea de la canción. Las líneas en blanco dentro de una sección se respetan.
- En Intro e Interludio, el campo tiene la ayuda *"Acordes separados por espacios, ej.: G D Em C"*.
- Al final hay un botón **"+ Sección"** que despliega Intro, Verso, Coro, Puente e Interludio. La sección nueva se agrega al final y recibe el foco.
- Quitar una sección con contenido pide confirmación: *"¿Quitar este Coro? Se pierde su letra y sus acordes."*. Si está vacía, se quita directamente.

### Modo Acordes
- Cada sección muestra su letra como texto, con la misma tipografía que la vista de la canción. Cada palabra se puede tocar.
- **Tocar una palabra** abre el selector de acordes (`showChordPicker`).
  - Si la palabra ya tiene acorde, el selector viene precargado con "Quitar acorde".
  - El acorde se muestra arriba de la palabra, en el color de acordes.
- Para indicar qué se puede tocar:
  - las palabras sin acorde muestran un "+" tenue arriba en hover (web);
  - las secciones sin ningún acorde muestran una ayuda: *"Tocá una palabra para ponerle acorde"*.
- **Intro e Interludio** se ven como una fila de acordes. Se editan en el modo Letra.
- Si una sección está vacía, se muestra *"Sin letra todavía. Escribila en el modo Letra."*.

### Acordes que se mantienen al corregir la letra
Al editar el texto de una sección que ya tiene acordes, cada acorde sigue a su palabra:

1. **Líneas.** Se comparan las líneas viejas y nuevas de la sección (subsecuencia común más larga sobre el texto de cada línea).
   - Una línea igual conserva sus acordes tal cual.
   - Las líneas que no coinciden se emparejan en orden dentro de cada tramo modificado: una línea corregida queda emparejada con la vieja que estaba en su lugar.
2. **Palabras.** Dentro de cada par de líneas se hace lo mismo con las palabras.
   - Cada palabra que sigue presente conserva su acorde.
   - Una palabra modificada en el mismo lugar ("gracía" → "gracia") hereda el acorde de la palabra que reemplaza.
   - Una palabra borrada pierde su acorde.
3. Una línea completamente nueva no tiene acordes.

La recomparación se hace en cada cambio del campo, partiendo siempre de la última versión con acordes. Así cambiar de modo no pierde nada.

## Formato guardado (ChordPro)

- Cada sección se escribe con su directiva: `{intro}`, `{verse}`, `{chorus}`, `{bridge}`, `{interlude}`.
  - El lector (`ChordProParser`) suma `intro` e `interlude` a las directivas de sección.
  - `tag` se sigue leyendo para canciones viejas y se muestra como "Otro". No se ofrece para secciones nuevas.
- Línea con letra: igual que hoy, por ejemplo `[G]Sublime [C]gracia del Señor`.
- Línea de solo acordes (Intro e Interludio): `[G]  [D]  [Em]  [C]`. Cada acorde queda como un segmento sin letra y la vista de la canción los muestra en fila, transponibles como cualquier acorde.
- Las directivas que el editor no entiende (`{title: …}`, `{key: …}`) se conservan sin mostrarse, igual que hoy.
- Canciones existentes:
  - el contenido antes de la primera directiva de sección se abre como una sección *Verso*;
  - un acorde a mitad de palabra (`salv[G]ó`) se conserva mientras esa palabra no se edite.

## Vista de la canción

- Etiquetas en castellano: INTRO, VERSO, CORO, PUENTE, INTERLUDIO, OTRO.
- Las líneas de solo acordes se ven como una fila de acordes con separación.

## Arquitectura (app Flutter)

- `editable_document.dart`
  - Se mantiene el modelo `EditableSection` → `EditableLine` → `EditableWord`.
  - Se agregan dos funciones puras:
    - `sectionText(section)`: la letra sin acordes, para el campo;
    - `applyText(section, newText)`: devuelve una sección nueva con los acordes reubicados según el algoritmo de arriba.
  - Para Intro e Interludio, el texto son los acordes, y `applyText` arma una línea de solo acordes por renglón.
- `song_lyrics_editor.dart` se reescribe con `_SectionCard`. Esta tarjeta tiene un modo Letra (con su `TextEditingController` estable por id de sección) y un modo Acordes (palabras tocables). El selector de modo vive en `SongLyricsStep`.
- `chordpro_parser.dart`: se agregan `intro` e `interlude` a las directivas de sección.
- `song_detail_screen.dart`:
  - las etiquetas se muestran en castellano, con un mapa compartido de nombres de sección;
  - la fila de solo acordes se muestra con separación.
- No se agregan dependencias.

## Pruebas

- Unitarias de `applyText`:
  - corregir una palabra;
  - insertar o borrar palabras antes de un acorde;
  - insertar una línea arriba;
  - borrar una línea;
  - pegar todo de nuevo idéntico;
  - Intro de solo acordes.
- Ida y vuelta ChordPro → editor → ChordPro sin cambios para canciones existentes, incluidos un acorde a mitad de palabra y directivas `{title:}`.
- De widget:
  - escribir en Letra, pasar a Acordes, tocar una palabra, elegir un acorde y guardar produce el ChordPro esperado;
  - agregar, mover y quitar secciones, con la confirmación;
  - las etiquetas de la vista de la canción salen en castellano.
