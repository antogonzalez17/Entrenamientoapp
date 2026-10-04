# Athlete Performance — contexto del proyecto

## Qué es
App de entrenamiento tipo Harbiz/TrainerStudio para que un entrenador programe
sesiones, cuestionarios (wellness/RPE) y las envíe a sus deportistas. Soporta
varios entrenadores independientes, cada uno con su propio equipo.

## Arquitectura
- **Todo vive en un único archivo**: `index.html` (HTML + CSS + JS vainilla,
  sin frameworks, sin build step). Así se despliega tal cual.
- **Hosting**: Netlify, desplegado automáticamente desde este repo de GitHub
  (`antogonzalez17/Entrenamientoapp`) cada vez que se hace push a `main`.
- **Base de datos y autenticación**: Supabase (proyecto "AthleteApp").
  - Cliente JS de Supabase cargado por CDN (`@supabase/supabase-js@2`).
  - La URL del proyecto y la clave pública (`sb_publishable_...`) están
    embebidas directamente al principio del `<script>` en `index.html`
    (es seguro, es la clave pública, no la secreta).
  - Login con email + contraseña (confirmación de email desactivada para
    que el registro sea inmediato).

## Modelo de datos (Supabase)
- `profiles`: cada usuario registrado (entrenador o deportista).
  Columnas: `id` (= auth.users.id), `role` ('coach'|'athlete'), `coach_id`
  (a qué entrenador pertenece, null si es el propio entrenador), `name`,
  `email`, `sport`, `phone`, `notes`.
- `app_data`: la biblioteca de cada entrenador (ejercicios, plantillas de
  sesión y de cuestionario) guardada como JSON en una tabla clave-valor,
  separada por `coach_id`. Claves usadas: `exercises`, `session-templates`,
  `questionnaire-templates`. (Las claves antiguas `assignments` y
  `questionnaire-assignments` siguen ahí solo como copia de seguridad; la
  app ya no las usa.)
- `athlete_items`: cada sesión o cuestionario asignado es una fila propia.
  Columnas: `id`, `coach_id`, `athlete_id`, `kind` ('session'|'questionnaire'),
  `data` (el objeto completo en JSON), `updated_at`. La app guarda fila a
  fila (insert al asignar, update al completar), nunca reescribe todo.
- RLS activado en todas las tablas:
  - `app_data`: el entrenador lee/escribe su espacio; el deportista solo
    puede leer la biblioteca de su entrenador (no puede escribir).
  - `athlete_items`: el entrenador ve/modifica todo lo de su equipo y solo
    puede asignar a deportistas suyos; el deportista solo ve y actualiza
    sus propias filas (no puede crear ni borrar).
  - `profiles`: cada uno ve su perfil; el entrenador, también los de su
    equipo. Un deportista no ve las fichas de sus compañeros.
- Los cambios de base de datos se guardan como `.sql` en la carpeta
  `supabase/` y se ejecutan a mano en el SQL Editor de Supabase.

## Cómo funciona el acceso (sin paneles de admin)
- No hay un panel para "añadir deportistas" manualmente: se registran
  ellos mismos a través de un enlace de invitación.
- Dos tipos de enlace (generados dentro de la sección "Compartir" de la
  propia app, a partir de `location.origin + location.pathname`):
  - `?invite=<coachId>` → quien se registre queda vinculado como
    deportista de ese entrenador.
  - `?invite=coach` → quien se registre se convierte en un entrenador
    nuevo e independiente, con su propio equipo.
- Sin ningún `?invite=` en la URL, se muestra login normal, con la opción
  de "crear cuenta de entrenador" (para el primer entrenador que no tiene
  invitación de nadie).

## Diseño
- Paleta: negro / rojo / blanco (variables CSS `--bg`, `--yellow` (rojo
  principal), `--ember` (rojo secundario), `--sage` (blanco, para estados
  "completado")).
- Tipografía: Space Grotesk (títulos) + Inter (cuerpo), cargadas de Google
  Fonts.
- Logo: escudo "AG Athlete Performance" (imagen WebP embebida en base64 en
  la constante `LOGO_SRC` de `index.html`; se pinta en todas las
  `<img class="brand-logo">`). Lema debajo: "ELEVA TU RENDIMIENTO".
- Fechas: siempre en hora local (`localISO`, `todayISO`, `addDays`,
  `startOfWeek`); nunca usar `toISOString()` para fechas de calendario.

## Funcionalidades ya construidas
- Entrenador: panel con métricas, gestión de deportistas (editar/dar de
  baja), biblioteca de ejercicios (con categorías/etiquetas y vídeo de
  YouTube/Vimeo con miniatura), creador de sesiones por bloques con nombre
  (cada bloque agrupa varios ejercicios), cuestionarios personalizables,
  "Planificación" (antes "Calendario"): vista Semana y vista Mes, botones
  ‹ Hoy ›, el día actual resaltado en rojo; al entrar siempre abre la
  semana/mes actual. Al pulsar un día: "Añadir sesión" o "Añadir
  cuestionario" (se pueden asignar varios cuestionarios distintos el mismo
  día; el mismo cuestionario no se repite para el mismo deportista y día).
  Asignar a uno o varios deportistas, con opción de crear una sesión nueva
  sin salir del flujo. Desde "Deportistas", botón "Planificación" que abre
  la planificación filtrada por ese deportista. Seguimiento de lo completado, sección
  "Compartir" con los dos enlaces de invitación.
- Deportista: su semana con lo asignado, detalle de sesión (marcar
  bloques/ejercicios hechos, dejar RPE y comentarios, reproductor de
  vídeo incrustado), responder cuestionarios, historial.

## Convenciones a mantener
- Un solo archivo `index.html`, nada de build step ni dependencias npm.
- Los cambios se prueban abriendo el archivo o la URL de Netlify
  directamente — no hay entorno de test automatizado.
- Antonio (el usuario) no es programador: explica los cambios en lenguaje
  sencillo cuando apliques algo importante, y evita dar por hecho jerga
  técnica.
