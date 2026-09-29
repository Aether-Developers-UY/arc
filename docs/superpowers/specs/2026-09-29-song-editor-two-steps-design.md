# Editor de canción en dos pasos — Diseño

Divide el editor de canción (crear y editar) en dos pantallas: metadatos (título, artista, tonalidad, tempo, compás) y letra (editor visual de acordes + Indicaciones), en vez de un único formulario largo.

## Alcance

- Aplica tanto a crear una canción nueva como a editar una existente.
- Reorganiza la UI de `SongEditorScreen`; no cambia el modelo de datos, el backend, ni la lógica de guardado (`editableToChordPro`, `SongRepository.create`/`update`).
- No introduce guardado parcial: nada se persiste en el servidor hasta tocar "Guardar" en el paso 2.

Fuera de alcance: cualquier cambio al editor visual de acordes en sí (`SongLyricsEditor`), al modelo `EditableSection`/`EditableLine`/`EditableWord`, o al backend.

## Estructura de archivos

- `lib/features/songs/song_editor_screen.dart` — sigue siendo el contenedor: dueño único de todo el estado (controllers de metadatos, `_lyricsSections`, `_notesController`, `_isSaving`, `_errorMessage`) más un nuevo `int _step` (0 o 1). Decide qué paso renderizar y maneja la navegación entre ellos.
- `lib/features/songs/editor/song_metadata_step.dart` (nuevo) — widget sin estado propio: recibe los controllers de título/artista/tonalidad/tempo/compás y un callback `onNext`, y renderiza esos campos + botón "Siguiente".
- `lib/features/songs/editor/song_lyrics_step.dart` (nuevo) — widget sin estado propio: recibe `sections`/`onSectionsChanged` (para `SongLyricsEditor`), el controller de Indicaciones, `isSaving`, `errorMessage`, y callbacks `onBack`/`onSave`, y renderiza el editor de letra + Indicaciones + botones "Atrás"/"Guardar".

Ningún paso duplica estado: son widgets controlados, igual patrón que ya usa `SongLyricsEditor` con `sections`/`onChanged`.

## Navegación

- `SongEditorScreen` mantiene `int _step = 0`. El `AppBar` muestra el título actual ("Nueva canción"/"Editar canción") y, debajo, "Paso 1 de 2" o "Paso 2 de 2".
- **Paso 1 → 2**: botón "Siguiente" al pie del paso 1. Antes de avanzar, valida que título y tonalidad no estén vacíos (recortando espacios); si falta alguno, muestra un mensaje de error en el paso 1 (mismo estilo visual que el error de guardado existente) y no avanza.
- **Paso 2 → 1**: botón "Atrás" al pie del paso 2, vuelve a `_step = 0` sin descartar nada de lo escrito en ningún paso (los controllers y `_lyricsSections` no se reinician, solo cambia qué widget se muestra).
- El gesto/botón de retroceso del sistema en el paso 2 también ejecuta "volver al paso 1" (interceptado con `PopScope`) en vez de cerrar el editor completo; en el paso 1, el retroceso del sistema cierra el editor como hoy.
- Guardar (paso 2) permanece sin cambios: llama a `_save()`, que construye el `Song` y llama a `SongRepository.create`/`update` exactamente igual que la implementación actual.

## Editar una canción existente

Ambos pasos arrancan prellenados con los datos actuales de la canción (mismos controllers/inicialización que ya existen hoy — `_titleController`, `_lyricsSections` vía `parseToEditable`, etc.). El usuario entra al paso 1 y puede tocar "Siguiente" sin modificar nada si solo quiere cambiar la letra.

## Manejo de errores

- Error de validación al intentar avanzar del paso 1 (título o tonalidad vacíos): se muestra en el paso 1, mismo estilo (`Text` en color de error) que ya usa el formulario actual para errores de guardado.
- Error de guardado (fallo del servidor al tocar "Guardar"): se sigue mostrando en el paso 2, mismo mecanismo (`_errorMessage`, extraído del 422 vía `_messageFor`) que existe hoy.
- Cambiar de paso nunca borra `_errorMessage` del otro paso de forma inesperada: al entrar a un paso, se limpia solo el error de *ese* paso (la validación del paso 1 no debe seguir mostrándose al volver desde el paso 2, y viceversa).

## Testing

- No se agregan tests unitarios nuevos: es una reorganización de UI sobre lógica ya cubierta (`editableToChordPro`/`parseToEditable` tienen sus tests en `editable_document_test.dart`, sin cambios).
- Verificación: `flutter analyze` limpio y prueba manual en el navegador — crear una canción completa paso a paso, editar una existente entrando directo al paso 2, ida y vuelta entre pasos sin perder datos escritos, e intentar avanzar del paso 1 sin título para confirmar el mensaje de validación.
