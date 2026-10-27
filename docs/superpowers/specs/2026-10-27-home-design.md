# Inicio (Home) — Diseño

## Objetivo

Una pantalla de **Inicio** con acceso rápido a lo que se usa en cada culto: hasta 3 setlists fijados por el usuario, la biblioteca de canciones y un espacio reservado para secciones futuras. Es la primera pestaña y la pantalla con la que se abre la app.

Contenido central: las canciones del culto con sus acordes. Los archivos (PDF, audio) siguen asociados a una canción, no al setlist.

## Alcance

**Incluye**
- Nueva pestaña "Inicio" (primera en el sidebar y en la barra inferior), que es la pantalla inicial después del login.
- Hasta 3 setlists fijados, mostrados como bloques en una misma fila.
- Accesos a Biblioteca de canciones y a Todos los setlists.
- Un bloque "Próximamente" (placeholder) que marca el lugar de futuras secciones.
- Persistencia local de los fijados, por dispositivo.

**No incluye (más adelante)**
- Líneas de canciones especiales / enganches (medleys con sus propios archivos).
- Cambios en el backend. No hay endpoints nuevos.
- Otras secciones de Inicio.

## Comportamiento

### Fijados
- Cada persona elige sus fijados en su dispositivo. No se comparten entre dispositivos ni usuarios.
- Máximo 3. Se muestran en el orden en que se fijaron.
- Cada bloque muestra: fecha (`shortDate`), nombre, hasta 3 canciones con su tono (el del setlist) y el total de canciones ("5 canciones").
- **Tocar el bloque** abre `SetlistDetailScreen(setlistId)`, que ya existe. Desde ahí, tocar una canción abre la vista de letra y acordes en el tono del setlist (comportamiento actual).
- Si hay menos de 3, aparece un bloque punteado "+ Fijar setlist". Abre una hoja con la lista de setlists no fijados; al elegir uno se agrega.
- Cada bloque tiene un menú "⋯" con "Quitar de fijados". Quitar solo borra el fijado local, no el setlist.
- Un fijado cuyo setlist ya no existe (borrado) se descarta en silencio de la lista local.

### Estados
- **Sin fijados**: un recuadro punteado "Todavía no elegiste un culto" con el botón "Elegir setlist". Los accesos a Biblioteca y Todos los setlists se ven igual.
- **Cargando**: el bloque muestra un esqueleto simple o un indicador, sin bloquear el resto de Inicio.
- **Error al cargar un bloque**: el bloque muestra "No se pudo cargar" con reintento. No afecta a los otros.
- **No hay setlists creados**: "+ Fijar setlist" explica que primero hay que crear uno y lleva a la pestaña Setlists.

### Navegación
- Pestañas: Inicio, Canciones, Setlists (Inicio primero). Escritorio: sidebar; celular: `NavigationBar`.
- "Biblioteca de canciones" y "Todos los setlists" cambian a la pestaña correspondiente del shell.
- Inicio es el índice 0 del `IndexedStack`.

### Responsive
- **Escritorio (>= 900 px)**: los 3 bloques en una fila, mismo ancho (`Expanded`).
- **Celular**: la fila se desliza horizontalmente (cada bloque ~70% del ancho, se ve un borde del siguiente). Siguen siendo una sola fila.
- Tema claro/oscuro con `ArcaTokens`/`ArcaCard`; todo clickeable con `cursor-pointer` (ya global en web).

## Arquitectura

Todo en el app Flutter (`arc_app`), nuevo feature `lib/features/home/`.

- `pinned_setlists_provider.dart`: `AsyncNotifier<List<int>>` con los ids fijados. Persiste en `SharedPreferences` (clave `pinned_setlist_ids`, lista de strings). Métodos: `pin(id)` (ignora si ya está o si hay 3), `unpin(id)`. Carga inicial asíncrona al iniciar; mientras no cargó, Inicio muestra el estado cargando.
- `setlistDetailProvider`: `FutureProvider.family<Setlist, int>` que llama a `setlistRepositoryProvider.getOne(id)`. La lista de setlists no trae canciones, por eso cada bloque pide el detalle. Si responde 404 el id se desfija.
- `home_screen.dart`: `HomeScreen` con la fila de fijados, los accesos y el placeholder.
- `pinned_setlist_card.dart`: el bloque; `pin_setlist_sheet.dart`: la hoja para elegir un setlist a fijar (usa `setlistListProvider`).
- `AppShell`: se agrega el destino "Inicio" (ícono `home`) al principio de `_destinations` y `HomeScreen` al principio del `IndexedStack`. Los accesos a Biblioteca y Setlists llaman a un callback que cambia `_index`.
- Sin dependencias nuevas (`shared_preferences` ya se usa en el cache de canciones).

## Decisiones de detalle

- **Setlist inexistente**: `getOne` no captura errores, así que lanza `DioException`. El bloque que recibe un `DioException` con `response?.statusCode == 404` llama a `unpin(id)`; cualquier otro error (red, 500) muestra "No se pudo cargar" con reintento y **no** desfija. No se toca el repositorio.
- **Alcance de los fijados**: por dispositivo, una sola clave, sin separar por usuario. Los setlists son del ministerio (no de cada usuario), así que dos personas en el mismo dispositivo comparten fijados. Los ids que ya no existen se limpian por el caso 404.
- **Datos del bloque**: se usan `Setlist.songs` y `SetlistSong.key` / `songTitle` del detalle (ya existentes). Si una canción no tiene tono, se muestra solo el título. Todos los tamaños muestran hasta 3 canciones y una línea "N canciones".
- **Hoja "Fijar setlist"**: usa `setlistListProvider` tal como viene (sin paginar), ordenado por fecha descendente, sin los ya fijados. Sin búsqueda.
- **Quitar un fijado**: cada bloque tiene un botón "⋯" con la opción "Quitar de fijados". No hay modo de edición ni reordenamiento; para reemplazar se quita y se fija otro. Se elimina el botón "Editar fijados" del mockup.
- **Carga de ids**: el notifier es `AsyncNotifier<List<int>>`, para que Inicio no muestre el estado vacío antes de leer `SharedPreferences`.
- **Datos frescos**: `setlistDetailProvider` es `autoDispose`; el shell invalida los detalles al volver a la pestaña Inicio, así los cambios hechos en Setlists se ven al volver.
- **Índices del shell**: no hay tests ni código externo que dependan de los índices actuales (Canciones = 0, Setlists = 1); se desplazan a 1 y 2.

## Tests

- `PinnedSetlistsNotifier`: fija, respeta el máximo de 3, no duplica, desfija, persiste y recarga desde `SharedPreferences` (mock de valores).
- `HomeScreen`: estado vacío, 1 y 3 fijados, bloque punteado solo si hay menos de 3, tocar un bloque abre el detalle, error en un bloque no rompe los demás, id de setlist inexistente se descarta.
- `AppShell`: Inicio es la primera pestaña y los accesos cambian de pestaña.
- Prueba de layout en ancho de escritorio y de celular (sin overflow).

## Pendiente a futuro (no se construye ahora)

- Líneas de canciones / enganches: varias canciones con transiciones específicas y posibilidad de subir PDF o audio a la línea. Inicio reserva el espacio con el bloque "Próximamente".
