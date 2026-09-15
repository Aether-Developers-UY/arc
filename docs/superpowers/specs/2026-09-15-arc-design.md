# Arc — Diseño v1

App para el ministerio de alabanza de una iglesia, inspirada en OnSong: gestión de canciones con letra y acordes, transposición de tonalidad y archivos adjuntos por canción (pistas de audio, PDFs, etc.).

## Alcance v1

- Canciones con letra y acordes (formato ChordPro), transposición de tonalidad.
- Archivos adjuntos por canción (audio, PDF, otros).
- Login simple, un solo rol (todo el equipo de alabanza tiene los mismos permisos).
- Móvil (Android/iOS) + Web, mismo código Flutter.

Fuera de alcance v1 (backlog, ver sección Ideas):
setlists, modo escenario/autoscroll, pedal MIDI/Bluetooth, roles admin/músico, anotaciones personales, capo virtual, búsqueda por letra, compartir setlist.

## Arquitectura

- **Backend**: Laravel (PHP 8.3), API REST, MySQL/InnoDB, auth con Laravel Sanctum (tokens).
- **Frontend**: Flutter, compilado a móvil (Android/iOS) y Web desde un único código base. Estado con Riverpod o Provider.
- **Comunicación**: REST/JSON sobre HTTP. Sin websockets en v1.
- **Transposición de tonalidad**: se calcula en el cliente (Dart), no en el backend. El backend siempre persiste el ChordPro en su tonalidad original; el cliente transpone en memoria al vuelo. Esto evita latencia de red en una interacción que debe sentirse instantánea (slider de tonalidad) y permite seguir usando la app sin conexión en el atril.

## Modelo de datos

```
users:
  id, name, email, password, timestamps

songs:
  id, title, artist, original_key, tempo (nullable),
  time_signature (nullable), content (text, ChordPro),
  notes (text, nullable), created_by (FK users), timestamps

attachments:
  id, song_id (FK songs), type (enum: audio|pdf|other),
  original_name, file_path, mime_type, size, timestamps
```

- `content`: texto completo en formato ChordPro (acordes inline entre corchetes sobre la letra, directivas de sección tipo `{verse}` / `{chorus}`).
- `original_key`: tonalidad de origen de la canción. No se duplican canciones por tonalidad transportada.

## API (Laravel)

- `POST /login`, `POST /logout`
- `GET /songs` (listado, búsqueda por título/artista), `POST /songs`
- `GET /songs/{id}`, `PUT /songs/{id}`, `DELETE /songs/{id}`
- `POST /songs/{id}/attachments` (multipart/form-data)
- `DELETE /attachments/{id}`
- `GET /attachments/{id}/download`

Validaciones:
- Tamaño máximo de archivo: audio hasta 20MB, PDF hasta 10MB.
- Mimetypes permitidos según `type` (audio: mp3/wav/m4a; pdf: application/pdf; other: lista abierta pero acotada).
- Almacenamiento: disco local de Laravel (`storage/app/public`), migrable a S3 en el futuro sin cambiar el modelo.

## Flutter — pantallas clave

1. **Lista de canciones**: buscador por título/artista, orden alfabético por defecto.
2. **Detalle de canción**: letra+acordes renderizados desde ChordPro; selector de tonalidad que transpone en vivo (client-side); lista de adjuntos con reproductor de audio inline y visor/descarga de PDF.
3. **Editor de canción**: campo de texto ChordPro (con resaltado simple de acordes) + metadatos (título, artista, tonalidad original, tempo, time signature, notas); selector de archivos para adjuntar.
4. **Login**: pantalla simple usuario/contraseña.

### Parser/transpositor ChordPro
Paquete Dart propio (sin dependencias externas pesadas):
- Parsea el texto ChordPro en tokens de texto + acordes + directivas de sección.
- Tabla de transposición cromática (maneja enarmónicos: sostenidos vs. bemoles según la tonalidad destino).
- Renderiza acordes alineados sobre la letra en la UI.

## Manejo de errores

- **Backend**: respuestas JSON estándar — 401 (auth), 422 (validación), 413 (archivo demasiado grande), 404, 500.
- **Flutter**: mensajes de error simples en pantalla, sin retry automático complejo en v1.
- **Modo offline**: la última lista de canciones (y su contenido) se cachea localmente (sqlite/hive) para que la app siga siendo usable en el atril aunque falle la conexión durante el culto. Los adjuntos (audio/PDF) no se cachean automáticamente en v1 — requieren conexión para reproducirse/descargarse la primera vez.

## Testing

- **Backend**: Laravel feature tests para CRUD de canciones y subida/borrado de adjuntos (incluyendo casos de validación: tipo/tamaño inválido).
- **Flutter**: tests unitarios del parser y transpositor ChordPro (lógica más crítica y con mayor riesgo de romperse silenciosamente).

## Ideas para versiones futuras (backlog, no v1)

- Setlists por servicio: lista ordenada de canciones con tonalidad elegida para ese día.
- Modo escenario: pantalla grande, autoscroll, soporte de pedal Bluetooth para pasar página.
- Compartir setlist del domingo por WhatsApp/link.
- Historial de "última vez tocada" por canción.
- Anotaciones personales por músico sobre una canción, sin modificar el original.
- Capo virtual: sugerencia de cejilla según la tonalidad transportada.
- Búsqueda por letra, no solo por título/artista.
- Roles admin vs. músico (permisos diferenciados).
