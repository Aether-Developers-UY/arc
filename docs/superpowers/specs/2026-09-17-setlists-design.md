# Setlists — Diseño

Permite al equipo de alabanza armar una lista ordenada de canciones para un servicio específico (ej. el domingo), eligiendo la tonalidad a tocar ese día por canción, independiente de la tonalidad original guardada en el catálogo.

## Alcance

- CRUD de setlists (fecha de servicio + nombre opcional).
- Agregar/quitar canciones de un setlist.
- Reordenar canciones dentro de un setlist (drag & drop).
- Elegir una tonalidad específica por canción dentro de ese setlist, sin modificar la canción original.
- Navegar desde una entrada del setlist directo al detalle de la canción, ya con la tonalidad del setlist preseleccionada.

Fuera de alcance (queda en el backlog general): modo escenario/autoscroll, roles admin/músico, compartir setlist por link/WhatsApp, historial de "última vez tocada".

## Modelo de datos

```
setlists:
  id, service_date (date), name (nullable), created_by (FK users), timestamps

setlist_songs:
  id, setlist_id (FK setlists, cascadeOnDelete),
  song_id (FK songs, cascadeOnDelete),
  position (unsigned int),
  key (string, tonalidad elegida para este setlist — se inicializa con
       original_key de la canción al agregarla, pero es independiente),
  timestamps
```

- `position` es 0-indexed y se reescribe completa en cada reorder (no hay huecos ni negociación de posiciones individuales).
- `key` vive en `setlist_songs`, nunca en `songs` — la misma canción puede tener tonalidades distintas en distintos setlists sin tocar el catálogo.
- Si se borra una canción del catálogo (`songs`), sus entradas en `setlist_songs` se borran en cascada (la canción desaparece del setlist, el setlist en sí no se borra).
- Si se borra un setlist, sus `setlist_songs` se borran en cascada (las canciones del catálogo no se tocan).

## API (Laravel)

- `GET /setlists` — lista ordenada por `service_date` ascendente (próximo servicio primero).
- `POST /setlists` — crea (`service_date` requerido, `name` opcional).
- `GET /setlists/{id}` — detalle con sus canciones ordenadas por `position`, incluyendo título/artista de cada canción (eager load).
- `PUT /setlists/{id}` — editar fecha/nombre.
- `DELETE /setlists/{id}` — borrar.
- `POST /setlists/{id}/songs` — agrega una canción al final (`song_id` requerido, `key` opcional — si se omite, usa `original_key` de la canción en ese momento).
- `PUT /setlists/{id}/reorder` — recibe el array completo de `setlist_song_id`s en el nuevo orden; reescribe `position` 0..n-1 según ese orden. Rechaza (422) si el array no contiene exactamente los mismos IDs que ya pertenecen al setlist.
- `PUT /setlists/{id}/songs/{setlistSongId}` — actualiza la `key` elegida para esa entrada.
- `DELETE /setlists/{id}/songs/{setlistSongId}` — quita la canción del setlist (no borra la canción del catálogo).

Permisos: igual que el resto de la app — cualquier usuario autenticado puede crear/editar/borrar cualquier setlist (un solo rol, sin restricciones por dueño).

## Flutter — pantallas

1. **Lista de setlists** (`SetlistListScreen`): ordenados por fecha (próximo primero), cada ítem muestra fecha + nombre. FAB para crear uno nuevo.
2. **Editor de setlist** (`SetlistEditorScreen`): date picker para `service_date`, campo de texto opcional para `name`. Mismo patrón create/edit con parámetro nullable que `SongEditorScreen`.
3. **Detalle de setlist** (`SetlistDetailScreen`):
   - Lista reordenable (drag & drop, `ReorderableListView`) de canciones, cada ítem muestra título + tonalidad elegida para ese setlist.
   - El reorder es optimista: se reordena localmente al soltar y se persiste en background contra `PUT /setlists/{id}/reorder`; si falla, se revierte el orden local y se muestra un mensaje de error.
   - Botón para agregar canción: abre un buscador (reutiliza `songListProvider`/`SongRepository.list`) y al elegir una, llama a `POST /setlists/{id}/songs`.
   - Swipe o botón para quitar una canción del setlist.
   - Tap en una canción navega a `SongDetailScreen`, pasándole la `key` de esa entrada del setlist como tonalidad inicial (en vez de `originalKey`).
4. **Cambio en `SongDetailScreen`**: acepta un parámetro opcional `initialKey` (default: la tonalidad original de la canción si no se pasa nada). El resto del comportamiento (selector, "Restablecer" vuelve a `originalKey`, no a `initialKey`) queda igual.

## Manejo de errores

- Mismo patrón ya establecido: extraer mensaje limpio de la respuesta 422 de Laravel (`errors` map), sin interpolar excepciones crudas.
- Reorder fallido: revertir el estado local y mostrar un mensaje de error sin perder la posición anterior conocida.

## Testing

- **Backend**: feature tests para CRUD de setlists; agregar canción (con y sin `key` explícita); reorder (incluye caso de reindexado correcto y caso de rechazo por IDs incompletos/incorrectos); quitar canción del setlist; borrar una canción del catálogo y confirmar que desaparece del setlist sin borrar el setlist.
- **Frontend**: sin lógica algorítmica nueva de alto riesgo (a diferencia del transpositor ChordPro) — se cubre con el mismo nivel de rigor que songs/attachments (verificación manual + `flutter analyze` limpio), sin suite de tests unitarios dedicada.
