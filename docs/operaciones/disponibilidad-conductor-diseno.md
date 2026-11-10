# Disponibilidad del conductor: diseño (fase C)

Escrito el 2026-11-10. **Solo diseño: no hay nada aplicado en la base de datos
ni en la app.** Pendiente de aprobación de Jhan, punto por punto (sección 9).

## 1. El problema

Un conductor "disponible" desaparece de las búsquedas a los pocos minutos de
minimizar la app. `find_available_drivers` lo descarta si su ubicación tiene más
de `driver_location_stale_seconds` (120 s; parcheado a 600 el 2026-11-10), y la
única fuente de ubicación en segundo plano es la tarea nativa de `expo-location`.

Medido en un iPhone 16 (2026-11-10): con la app minimizada, `driver_locations.
updated_at` se detuvo más de 5 minutos. En iOS no corre código de la app si el
sistema no entrega una posición, así que **no existe un "latido" propio** en
segundo plano. Cualquier regla del tipo "si no hay señal en N segundos, fuera"
reproduce el problema en iOS con otro nombre.

## 2. Hechos verificados del sistema actual (2026-11-10)

- `drivers.is_available` lo escribe la app directo (`driver-service.ts`, `update`
  con RLS). No existe noción de sesión ni de motivo de desconexión.
- `find_available_drivers` filtra por `is_available`, aprobación, saldo
  (`driver_can_work`), cuenta activa, vehículo activo, asientos libres y
  **frescura de `driver_locations.updated_at`** (única señal de "vivo").
- Las ofertas van a **todos** los elegibles (D160). La distancia solo se guarda,
  no decide. Por eso la frescura protege contra conductores fantasma, no contra
  una mala asignación.
- `accept_ride_offer` es atómica: toma `for update` sobre `ride_requests` y
  rechaza con "Otro conductor tomo esta solicitud". **Ya está resuelto**; solo
  falta una prueba con dos aceptaciones simultáneas.
- Push: el disparador `notify_new_offer` llama a `send_push_notification`, que
  lee `profiles.push_token` y envía por Expo Push con `pg_net`. Sin recibos:
  un token inválido nunca se limpia.
- `pg_cron` y `pg_net` están instalados. Hay un trabajo por minuto
  (`expire_stale_requests` + `offer_pending_requests`).

## 3. Principio

Separar tres cosas que hoy se mezclan en una sola ("ubicación fresca"):

| Señal              | Qué dice                             | Quién la fija          |
| ------------------ | ------------------------------------ | ---------------------- |
| **Intención**      | El conductor quiere trabajar         | Él, con el interruptor |
| **Seguimiento**    | El teléfono está mandando posiciones | La tarea nativa        |
| **Alcanzabilidad** | Una oferta le llega y la responde    | Push + sus respuestas  |

Elegible = intención **y** (seguimiento vivo **o** alcanzable). Un conductor
quieto en iOS tiene intención y alcanzabilidad aunque no tenga seguimiento.

## 4. Datos (sin tablas nuevas)

Columnas nuevas en `drivers` (la tabla ya es 1:1 con el conductor):

| Columna                   | Tipo        | Uso                                                                            |
| ------------------------- | ----------- | ------------------------------------------------------------------------------ |
| `availability_session_id` | uuid null   | Se crea al ponerse disponible; evita que un teléfono viejo pise a uno nuevo    |
| `availability_started_at` | timestamptz | Inicio de la sesión, para el cierre por duración máxima                        |
| `last_seen_at`            | timestamptz | Último signo de vida: app abierta, oferta respondida                           |
| `unanswered_offers`       | int         | Ofertas seguidas sin responder; a K se desconecta                              |
| `disconnect_reason`       | text null   | `manual`, `unanswered_offers`, `session_expired`, `vehicle_full`, `no_balance` |
| `location_permission`     | text null   | `always`, `while_in_use`, `denied`; lo manda la app                            |
| `device_platform`         | text null   | `android` / `ios`                                                              |

`driver_tracking_events` (ya aplicada) sigue siendo solo diagnóstico.

## 5. Reglas

**Elegible** (cambio en `find_available_drivers`):

```
is_available
and unanswered_offers < K
and sesion vigente (availability_started_at > now() - driver_max_session_hours)
and (  ubicacion fresca   (driver_locations.updated_at > now() - driver_location_stale_seconds)
    or alcanzable         (last_seen_at > now() - driver_seen_window_seconds
                           and profiles.push_token is not null))
```

**Desconexión automática** (en el trabajo por minuto de `pg_cron`, en el
servidor, sin depender del teléfono):

1. Sesiones con más de `driver_max_session_hours` → `is_available = false`,
   motivo `session_expired`.
2. Cuando una oferta caduca sin respuesta → `unanswered_offers + 1`. Al llegar a
   K → `is_available = false`, motivo `unanswered_offers`.
3. Cualquier respuesta (aceptar o rechazar) o abrir la app → `unanswered_offers
= 0` y `last_seen_at = now()`.

**Qué ve el conductor** al volver a la app: si el servidor lo desconectó, un
aviso con el motivo y un botón para reconectarse. Es la parte "estado real, no
variable local".

## 6. Cambios por capa

- **Base de datos:** una migración (columnas, parámetros nuevos, `find_available_
drivers`, ampliación del trabajo de `pg_cron`, y dos funciones: `driver_go_
online(plataforma, permiso)` que crea la sesión y `driver_touch()` que anota
  `last_seen_at`). Interruptor `availability_mode` en `app_settings`
  (`location` / `session`) para pasar de uno a otro **sin publicar versión** y
  volver atrás si algo sale mal.
- **App:** el interruptor llama a `driver_go_online` en vez de un `update`; la
  app llama a `driver_touch` al volver a primer plano; un módulo único
  (`driver-online-engine`) deriva el estado de pantalla (`offline`, `online`,
  `temporarily_disconnected`, `busy`, `error`) leyendo la fila de `drivers`.
  No se reescriben pantallas.
- **Push:** se conserva Expo Push (envuelve FCM y APNs, gratis). Falta: recibos
  para limpiar tokens inválidos y reintentos. Verificar el canal de Android de
  alta importancia y, en iOS, nivel de interrupción "time-sensitive".

## 7. Lo que NO se hace

- No se usa un latido por temporizador de JavaScript.
- No se descarta a un conductor solo por estar quieto.
- No se pasa a FCM/APNs directos ni a módulos nativos propios: se reconsideran
  solo si el diario demuestra que `expo-location` falla por algo que ellos sí
  arreglarían.
- No se crean tablas nuevas.

## 8. Riesgos

- Un conductor con el teléfono apagado puede recibir hasta K ofertas antes de
  desconectarse (cada una cuesta `offer_response_seconds` = 30 s al pasajero).
  Con K = 3 son hasta 90 s extra en el peor caso. Se mide y se ajusta.
- Ofertas en iOS: si el conductor no ve el aviso en 30 s, cuenta como sin
  responder. Por eso la prueba de push con la app minimizada va antes de activar
  el modo `session`.
- Dos teléfonos con la misma cuenta: la sesión más nueva gana. Hay que decidir
  qué se le dice al otro (sección 9, punto 4).

## 9. Decisiones (aprobadas por Jhan el 2026-11-10)

1. **K = 3** ofertas seguidas sin responder antes de desconectar.
2. **Sesión máxima: 12 horas.**
3. **Ventana de "alcanzable por push": 30 minutos** (1800 s).
4. **Dos teléfonos con la misma cuenta:** el nuevo desconecta al anterior, que
   muestra "Tu cuenta se abrió en otro teléfono". (El motivo `other_device` ya
   existe en la base; falta la parte de la app.)

**Estado:** migración escrita y **validada con `rollback`** (7 comprobaciones de
comportamiento, ver D296), **sin aplicar**. Nace en modo `location`: no cambia
nada hasta pasar `availability_mode` a `session`.

## 10. Pruebas previas a activar el modo `session`

1. iOS y Android, conductor quieto 5, 10 y 30 minutos, pantalla bloqueada.
2. Oferta nueva con la app minimizada (iOS y Android): llega el aviso y se
   abre la solicitud.
3. Dos conductores aceptando a la vez: uno solo gana.
4. Teléfono apagado con la app disponible: tras K ofertas se desconecta y el
   pasajero no se queda esperando.
5. Volver a la app tras una desconexión del servidor: aviso y reconexión.
