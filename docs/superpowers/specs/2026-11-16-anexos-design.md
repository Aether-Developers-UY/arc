# Anexos, roles y usuarios — diseño

## Por qué

La iglesia tiene varios anexos (sedes/congregaciones) y cada uno arma sus
propios cultos. Hoy Arca tiene una sola lista de setlists para todos, así que
cada equipo ve los setlists de los otros anexos mezclados con los suyos. El
objetivo es que **cada equipo vea solo los setlists de su anexo**.

Además, hoy las cuentas se crean a mano en la base. Hace falta un **admin**
que administre a los demás usuarios desde la app.

## Qué quedó decidido (por el usuario)

- Existen **anexos**. Una persona puede pertenecer a **más de uno**.
- **Cada persona se une a los anexos que quiera** (y puede salir). No hay
  aprobación. La separación es organizativa, no una barrera de seguridad:
  cualquiera puede unirse a cualquier anexo.
- Los **setlists se organizan por anexo**: cada equipo ve solo los setlists
  de sus anexos.
- Dos roles: **estándar** y **admin**. El admin administra al resto de los
  usuarios.
- UI: **anexo activo** con selector arriba. Toda la app (Inicio, Setlists,
  fijados) muestra solo el anexo activo; los setlists nuevos se crean en él.

## Objetivos

- Cada setlist pertenece a exactamente un anexo.
- Un usuario solo recibe del servidor (listar, ver, editar, borrar, canciones
  del setlist, reordenar) los setlists de los anexos a los que pertenece. Un
  setlist de otro anexo responde 404.
- Selector de anexo activo visible en la app; se recuerda en el dispositivo.
- Pantalla "Mis anexos": unirse / salir.
- Admin: gestionar anexos (crear, renombrar, borrar) y usuarios (crear,
  editar nombre/correo, cambiar rol, restablecer contraseña, borrar).

## No-objetivos

- Registro público o invitaciones por correo: las cuentas las crea el admin.
- Separar la **biblioteca de canciones** por anexo: sigue siendo común a toda
  la iglesia (un mismo canto se usa en varios anexos). Cualquier usuario
  puede crear/editar canciones como hoy.
- Solicitudes de ingreso con aprobación.
- Que el usuario cambie su propia contraseña (lo hace el admin por ahora).
- Mover un setlist de un anexo a otro.

## Anti-objetivos (sería un fracaso aunque funcione)

- Que alguien abra la app y "desaparezcan" sus setlists sin entender por qué:
  siempre debe verse claramente en qué anexo está parado.
- Que se pierdan los setlists existentes al migrar.
- Que el admin pueda quedarse sin admins (borrarse o quitarse el rol siendo el
  último).

## Enfoques considerados

1. **Anexo activo con selector** — elegido. Claro, no hay que elegir anexo al
   crear setlist. Costo: con varios anexos hay que cambiar para ver los otros.
2. Todo junto con filtro y etiqueta por anexo — recomendado inicialmente;
   descartado por el usuario a favor de la 1.
3. Anexos como carpetas — un toque extra siempre; descartado.

## Diseño

### Datos (backend, Laravel)

- Tabla `annexes`: `id`, `name` (único), timestamps.
- Tabla pivote `annex_user`: `annex_id`, `user_id` (único el par), timestamps.
- `users.role`: string `'standard' | 'admin'`, default `'standard'`.
- `setlists.annex_id`: FK obligatoria a `annexes`.
- Migración de datos: crear un anexo inicial **"Anexo principal"**, asignarle
  todos los setlists existentes y unir a todos los usuarios existentes. El
  primer usuario (id más bajo) queda como **admin**.
- Borrar un anexo: solo si **no tiene setlists** (si tiene, 422 con mensaje
  "Este anexo tiene setlists; borralos antes."). Evita perder cultos por
  accidente. *(Llamada mía.)*

### Permisos

- Setlists (y sus rutas de canciones/reordenar): el usuario debe ser miembro
  del anexo del setlist. Si no, **404** (no revela que existe).
  `GET /setlists?annex_id=X`: X debe ser uno de sus anexos (si no, 404); sin
  `annex_id` devuelve los de todos sus anexos.
  `POST /setlists` requiere `annex_id` de un anexo del que es miembro.
- **El admin también tiene que unirse a un anexo para ver sus setlists**
  — misma regla para todos, simple. *(Llamada mía; el admin puede unirse a
  cualquiera igual que cualquiera.)*
- Canciones y adjuntos: sin cambios (todos).
- Gestión de anexos y usuarios: solo admin (403 si no).

### API nueva

- `GET /me` → agrega `role` y `annexes` (`[{id, name}]`). Login devuelve lo
  mismo en `user`.
- `GET /annexes` → todos los anexos, con `is_member` para el usuario actual.
- `POST /annexes/{annex}/join`, `DELETE /annexes/{annex}/join` → unirse/salir
  (idempotentes).
- Admin: `POST /annexes`, `PUT /annexes/{annex}`, `DELETE /annexes/{annex}`.
- Admin: `GET /users`, `POST /users` (nombre, correo, contraseña, rol),
  `PUT /users/{user}` (nombre, correo, rol, contraseña opcional),
  `DELETE /users/{user}`.
  - No se puede quitar el rol admin ni borrar al **último admin** (422).
  - Un admin no puede borrarse a sí mismo (422).
- **Borrar un usuario no borra lo que creó.** Hoy `songs.created_by` y
  `setlists.created_by` tienen `cascadeOnDelete`, así que borrar a alguien
  borraría sus canciones (con adjuntos) y sus setlists. Se cambian a
  **nullable + `nullOnDelete`**: el contenido queda, sin autor. *(Llamada
  mía.)* El borrado revoca sus tokens.
- No hay "desactivar" usuarios: solo borrar. *(Llamada mía.)*
- **Restablecer la contraseña** de un usuario revoca todos sus tokens (sirve
  para el caso de teléfono perdido o alguien que se fue); la app ya maneja el
  401 volviendo al login. Cambiar rol o nombre no revoca. *(Llamada mía.)*
- Compatibilidad: si un cliente viejo crea un setlist **sin** `annex_id`, el
  servidor usa el primer anexo del usuario (por id); si no tiene ninguno, 422.
  *(Llamada mía; evita romper builds instalados.)*

### App (Flutter)

- **Usuario actual**: el provider de sesión guarda `role` y `annexes` desde
  `/me`.
- **Anexo activo**: provider que lo guarda en `SharedPreferences`. Si el
  guardado ya no es uno de mis anexos (salí, lo borraron), toma el primero.
- **Selector**: en la barra superior de Inicio y Setlists (en web, arriba de
  la columna lateral), muestra "Anexo: <nombre> ▾" y abre la lista de mis
  anexos + "Gestionar mis anexos". Si tengo un solo anexo igual se ve el
  nombre (para que siempre se sepa dónde estoy), pero sin flecha si no hay
  a dónde cambiar.
- **Sin anexos**: Inicio y Setlists muestran un estado vacío "Todavía no
  estás en ningún anexo" con botón "Elegir anexos".
- **Setlists**: la lista pide `annex_id` = activo. Crear setlist lo crea en el
  activo.
- **Fijados en Inicio**: se siguen guardando por dispositivo; Inicio muestra
  solo los fijados que pertenecen al anexo activo. El tope de 3 fijados pasa
  a ser **por anexo**. *(Llamada mía.)* Los fijados existentes se conservan:
  como todos los setlists pasan al "Anexo principal", quedan fijados ahí.
- **Mis anexos** (pantalla): lista de todos los anexos con un switch
  "Soy parte". Accesible desde el selector y desde el menú de usuario.
- **Admin** (solo si `role == admin`): entrada "Administración" en la
  navegación con dos pestañas:
  - **Usuarios**: lista; crear (nombre, correo, contraseña inicial, rol);
    editar; restablecer contraseña; borrar con confirmación.
  - **Anexos**: lista; crear; renombrar; borrar con confirmación.
- Textos en castellano rioplatense (voseo), como el resto de la app.

## Lo que queda a criterio del que construye

- Nombres exactos de clases/providers, siguiendo los patrones existentes
  (repositorios Dio + Riverpod, Policies/FormRequests de Laravel).
- Diseño visual de las pantallas nuevas, con los componentes existentes
  (`ArcaCard`, `ContentFrame`, tokens de `arca_tokens`).
- Tests: feature tests de Laravel para permisos y reglas del último admin;
  widget tests para selector, "Mis anexos" y pantallas de admin.
