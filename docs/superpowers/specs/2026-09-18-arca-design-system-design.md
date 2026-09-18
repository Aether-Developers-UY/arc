# Arca — Sistema de diseño y rediseño de la app

La app pasa a llamarse **Arca** (antes "Arc") a nivel de marca visible. Los nombres internos (carpeta `arc`, repo, base de datos `arc`, paquete Dart `arc_app`) no cambian.

## Objetivo

Que la app se vea ordenada y con identidad propia, usable de un vistazo en el atril con poca luz y también de día: sistema de color y tipografía coherente, logo, tarjetas/contenedores, navegación lateral adaptable, y modo claro y oscuro.

## Identidad

**Concepto:** agua y oro. El azul es el agua del diluvio; el oro es el arca del pacto. El oro se reserva para los acordes, lo único cálido de toda la app, de modo que se encuentren al instante en el atril.

**Logo:** casco de un arca (silueta simple de barco) con un arco encima, que es a la vez el arcoíris del pacto y una ligadura de partitura. Se usa como marca cuadrada (ícono) y como marca + palabra "Arca".

### Paleta

| Rol | Oscuro "Diluvio" | Claro "Día" |
|---|---|---|
| Fondo | `#0B1420` | `#F5F7FA` |
| Superficie (tarjetas) | `#122033` | `#FFFFFF` |
| Superficie elevada / bordes | `#1B2E47` | `#E3E8EF` |
| Primario (azul) | `#4C9BE8` | `#1F5FA8` |
| Texto | `#E8EEF6` | `#0F1B2D` |
| Texto secundario | `#8FA3BC` | `#5B6B80` |
| **Acordes (oro)** | `#F2B441` | `#A8650A` |
| Error | `#FF7A7A` | `#C0392B` |

### Tipografía

- Títulos: **Bricolage Grotesque** (peso 600–700).
- Texto e interfaz: **DM Sans**.
- Acordes: **JetBrains Mono** (monoespaciada, alinea sobre la letra).
- Vía paquete `google_fonts`.

## Estructura

- **Pantalla ancha (>= 900 px):** barra lateral fija a la izquierda con logo, destinos *Canciones* y *Setlists*, y *Cerrar sesión* abajo. Contenido a la derecha, con ancho máximo (~1100 px) centrado.
- **Pantalla angosta (< 900 px):** la navegación pasa a barra inferior con los mismos destinos; cerrar sesión va en el encabezado.
- Las pantallas de detalle y edición (canción, setlist, editores, selector) se abren a pantalla completa encima del shell, con botón de volver.
- Modo claro/oscuro automático según el sistema (`ThemeMode.system`), mismo diseño en ambos.

## Pantallas

- **Login:** dos columnas en pantalla ancha (marca a la izquierda con logo y frase, formulario a la derecha); una columna en angosta.
- **Canciones:** encabezado con título "Canciones" y botón *Nueva canción*; buscador; lista de tarjetas (título, artista, etiqueta de tonalidad).
- **Setlists:** encabezado con título y botón *Nuevo setlist*; tarjetas con bloque de fecha (día/mes) + nombre + cantidad de canciones si está disponible.
- **Detalle de canción ("lector"):** letra grande; acordes en oro con fuente monoespaciada; selector de tonalidad como fila de chips (con la original marcada); adjuntos en panel lateral en pantalla ancha, debajo en angosta.
- **Detalle de setlist:** lista reordenable en tarjetas con número de orden, título, artista, tonalidad; acciones claras.
- **Editores (canción/setlist) y selector de canciones:** formularios centrados con ancho máximo, campos con el estilo del tema.

## Componentes compartidos

`ArcaLogo`, `AppShell`, `PageHeader` (título + acción), `ArcaCard` (contenedor base), `KeyBadge` (etiqueta de tonalidad).

## Fuera de alcance

Renombrar carpeta/repo/base de datos, ícono nativo de la app (Android/iOS launcher), animaciones elaboradas, modo escenario. Sí incluye actualizar el título/manifest web al nombre "Arca".

## Verificación

`flutter analyze` limpio, `flutter test` verde, y revisión visual en navegador en ambos temas y en ancho angosto y ancho.
