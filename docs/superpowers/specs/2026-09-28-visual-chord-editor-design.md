# Editor visual de acordes — Diseño

Reemplaza el editor de texto libre (ChordPro escrito a mano) por un editor visual: el usuario escribe la letra como texto normal y agrega acordes tocando un punto entre palabras, armando el acorde por partes (nota → tipo → bajo) en vez de escribir corchetes. De paso, el campo "Notas" pasa a llamarse "Indicaciones" y se muestra en la vista de la canción.

## Alcance

- Editor visual de letra + acordes, en reemplazo total del campo de texto ChordPro libre en `SongEditorScreen`.
- Estructura por bloques de sección (Verso, Coro, Puente, Otro), con botón para agregar sección.
- Inserción de acordes por selector de 3 pasos (nota, tipo opcional, bajo opcional), sin escritura de texto libre.
- Edición y borrado de un acorde ya insertado.
- Renombrar "Notas" a "Indicaciones" en el editor, y mostrarlo en `SongDetailScreen` cuando tiene contenido.

Fuera de alcance: cambios al modelo de datos del backend (`Song.content` sigue siendo ChordPro), cambios al parser/transpositor existentes (se reutilizan tal cual), un modo "texto libre" alternativo (se descartó explícitamente).

## Representación interna

El editor trabaja sobre una estructura en memoria equivalente a `ChordProDocument` (ya existente en `lib/core/chordpro/chordpro_parser.dart`):

```
List<EditableSection>
  EditableSection: { label: String? ('verse'|'chorus'|'bridge'|'tag'|null), lines: List<EditableLine> }
  EditableLine: List<EditableSegment>
  EditableSegment: { chord: String?, text: String }
```

- **Al abrir el editor** (crear o editar): si `existingSong` no es nulo, su `content` se parsea con `ChordProParser.parse()` y se convierte a esta estructura, agrupando líneas consecutivas bajo la última directiva de sección vista (replicando cómo `SongDetailScreen` ya interpreta `sectionLabel`). Si es una canción nueva, arranca con una sola `EditableSection` de tipo `verse` y una línea vacía.
- **Al guardar**: la estructura se serializa de vuelta a texto ChordPro (directivas `{verse}`/`{chorus}`/`{bridge}`/`{tag}` seguidas de líneas con acordes en `[Nota]texto`) y se envía en `content` al mismo `SongRepository.create`/`update` que ya existe. No cambia el contrato con el backend.

## Pantalla

`SongEditorScreen` mantiene los campos de metadatos que ya tiene (título, artista, tonalidad, tempo, compás) sin cambios, y agrega:

1. **Campo "Indicaciones"** (antes "Notas"), mismo lugar en el formulario.
2. **Editor de letra**, reemplazando el `TextField` multilínea actual, con esta estructura:
   - Por cada `EditableSection`: una etiqueta con el tipo de sección + botón "quitar sección", y debajo sus líneas de letra como campos de texto editables (una línea = un `TextField` de una sola línea, para poder detectar la posición del toque).
   - Los acordes de una línea se muestran como etiquetas doradas (mismo estilo `KeyBadge`/color de acorde que ya usa `SongDetailScreen`) ancladas sobre la posición del texto donde fueron insertados, igual que se ven ya en la vista de lectura.
   - Tocar un punto entre palabras (o al principio/final) donde no hay acorde abre el selector de inserción. Tocar una etiqueta de acorde existente abre el mismo selector, prellenado, con un botón "Quitar acorde" además de "Guardar cambios".
   - Al final de cada sección, botón "**+ Acorde**" no hace falta (se inserta tocando la letra); al final del bloque, botón "**+ Sección**" que pide el tipo (Verso/Coro/Puente/Otro) y agrega una `EditableSection` nueva con una línea vacía.
   - Cada línea tiene un botón menor para agregar una línea nueva debajo dentro de la misma sección, y para borrar la línea.

## Selector de acorde (bottom sheet)

Se abre como hoja inferior con:
- Vista previa grande del acorde armado hasta el momento (ej. "D", "Dm7", "D/F#").
- Fila de 12 botones de nota: C, C#, D, D#, E, F, F#, G, G#, A, A#, B.
- Fila de chips de tipo (opcional, ninguno seleccionado = mayor): m, 7, m7, sus2, sus4, maj7, dim, aug, 6, 9.
- Toggle "Acorde con bajo distinto"; si está activo, aparece una segunda fila de 12 notas para el bajo, y la vista previa agrega `/Nota`.
- Botón "Insertar" (o "Guardar cambios" si se está editando uno existente), deshabilitado hasta que se eligió al menos una nota. Si se está editando, botón adicional "Quitar acorde".

No hay campo de texto libre en ningún punto de este selector — el acorde siempre se arma por selección.

## Vista de canción: mostrar Indicaciones

En `SongDetailScreen`, debajo del bloque de metadatos (artista · tempo · compás) y antes de la letra, si `song.notes` no está vacío se muestra un bloque con encabezado "Indicaciones" y el texto tal cual. Si está vacío, no se muestra nada (sin cambios respecto al comportamiento actual de no mostrarlo).

## Manejo de errores

- Mismo patrón que el resto de la app: mensaje limpio extraído del 422 del backend al guardar, sin exponer excepciones crudas.
- El selector de acorde no puede producir un acorde mal formado porque no acepta texto libre; "Insertar"/"Guardar cambios" quedan deshabilitados sin una nota elegida.
- Si al parsear una canción existente aparece contenido que el editor visual no puede representar fielmente (por ejemplo, una directiva desconocida o texto fuera de una sección), esas líneas se conservan como una sección "Otro" sin perder el contenido original, en vez de descartarlas silenciosamente.

## Testing

- Lógica de conversión estructura-editable ↔ ChordPro: tests unitarios Dart cubriendo ida y vuelta (parse → estructura → serializar → debe coincidir en contenido musical, aunque el formato de texto exacto —espacios, saltos de línea— pueda normalizarse).
- Construcción del acorde por partes (nota + tipo + bajo → string final tipo "Dm7/F#"): tests unitarios de la función de armado, reutilizando el mismo vocabulario de tipos que ya reconoce `transposeChord`.
- Resto de la pantalla: verificación manual + `flutter analyze` limpio, mismo nivel que el resto del editor de canciones.
