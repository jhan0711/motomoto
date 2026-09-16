-- =============================================================================
-- D270: motivo al desconectarse (plan de ajustes 2026-09-15, pedido 1)
-- =============================================================================
--
-- PEDIDO DE LA EMPRESA, 2026-09-15: saber por que un conductor se desconecta
-- -almuerzo, descanso, combustible, fin de turno, otro- para poder revisarlo
-- despues desde el panel. Antes `setAvailability` solo escribia el booleano
-- `is_available`; apagarse no dejaba ningun rastro de la razon.
--
-- CATALOGO CERRADO Y NO TEXTO LIBRE, salvo la salida de escape. Un enum se
-- puede filtrar y contar en el panel; un campo de texto libre no. `otro` es esa
-- salida, y solo con `otro` tiene sentido guardar el detalle en
-- `unavailable_reason` -restriccion `drivers_unavailable_reason_needs_otro`-,
-- para que no queden dos motivos contando historias distintas de la misma fila.
--
-- POR QUE UNA FUNCION NUEVA (`set_driver_unavailable`) Y NO SOLO ANADIR LAS DOS
-- COLUMNAS A LA ESCRITURA DIRECTA QUE YA HACE `setAvailability`. Se penso
-- primero en un disparador `before update` que exigiera el motivo con solo
-- mirar `old.is_available`/`new.is_available`, la misma forma que las demas
-- reglas de disponibilidad. **No sirve**, y por un motivo concreto que se
-- encontro leyendo el resto de la base de datos antes de escribir esto:
-- `is_available` NO SOLO LA APAGA EL CONDUCTOR A MANO. Otros tres sitios la
-- apagan solos, sin motivo, como parte de otra cosa:
--
--   - `accept_ride_offer` (D161): al aceptar una oferta que llena el
--     motorraton, recalcula `is_available = (is_available and v_free > 0)`.
--     Es la sesion del propio conductor, pasa constantemente, y exigirle un
--     motivo ahi habria roto aceptar viajes.
--   - `admin_assign_driver` (Fase 20 paso 9): al asignar un conductor a mano,
--     lo apaga igual que si hubiera aceptado ("mientras atiende un servicio no
--     recibe otros").
--   - `admin_set_account_status` / la funcion equivalente de super admin: al
--     bloquear una cuenta, apaga su disponibilidad en el acto.
--
-- Un disparador generico habria tenido que reescribir las tres funciones para
-- que lo esquivaran con una bandera de sesion, mismo patron que ya usa
-- `protect_driver_columns` con `motomoto.admin_action`. Se descarto: dos de
-- esas tres reescrituras tocarian `accept_ride_offer`, y esa funcion **ya se
-- rompio una vez por una reescritura descuidada** -D268, migracion
-- `20260903000000`, que tardo hasta la Fase 23 en destaparse-. Tocarla otra vez
-- para una funcionalidad que no tiene nada que ver con aceptar ofertas es
-- correr el mismo riesgo de nuevo por una ganancia pequena.
--
-- LA ALTERNATIVA, Y LA QUE QUEDA. `set_driver_unavailable` es la unica puerta
-- para apagarse CON motivo, y el motivo se exige dentro de ELLA, no con un
-- disparador que vigile la tabla entera. Las otras tres funciones no cambian
-- ni una linea. Lo que se acepta a cambio: un cliente que escribiera
-- directo en la tabla -saltandose esta funcion, algo que D83 ya permite para
-- encenderla- podria apagarse sin motivo. No se cierra esa puerta a proposito:
-- es la misma confianza que D83 ya deposita en el cliente para esa columna, y
-- este pedido es para que la aplicacion registre bien el motivo caso normal,
-- no un control de seguridad contra un cliente que decide saltarselo.
--
-- LA LIMPIEZA AL REACTIVARSE SI VA EN UN DISPARADOR, y ese si es seguro sin
-- tocar nada mas: **da igual quien ponga `is_available = true`** -el propio
-- conductor, `complete_ride`, `cancel_ride`, un administrador-, el motivo de
-- la vez anterior siempre deja de describir la fila. No hay ningun sitio
-- legitimo que quiera conservarlo.
--
-- DONDE SE VE. Solo el panel administrativo (`admin_list_drivers`, mas abajo).
-- El pasajero nunca ve conductores no disponibles, asi que no hay ningun sitio
-- de su lado donde este dato pudiera aparecer.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El catalogo
-- -----------------------------------------------------------------------------

create type public.driver_unavailable_reason_code as enum (
  'almuerzo',
  'descanso',
  'combustible',
  'fin_de_turno',
  'otro'
);

comment on type public.driver_unavailable_reason_code is
  'Por que un conductor se desconecto. Catalogo cerrado; "otro" es la unica que admite detalle libre.';


-- -----------------------------------------------------------------------------
-- Las columnas
-- -----------------------------------------------------------------------------

alter table public.drivers
  add column unavailable_reason_code public.driver_unavailable_reason_code,
  add column unavailable_reason text;

comment on column public.drivers.unavailable_reason_code is
  'Motivo de la ultima desconexion voluntaria (D270). Nulo mientras esta disponible: el disparador drivers_clear_unavailable_reason lo limpia solo al reactivarse. Tambien puede ser nulo estando apagado, cuando la desconexion no la hizo el propio conductor (ver set_driver_unavailable).';
comment on column public.drivers.unavailable_reason is
  'Detalle libre. Solo tiene sentido junto a unavailable_reason_code = otro (drivers_unavailable_reason_needs_otro).';

alter table public.drivers
  add constraint drivers_unavailable_reason_needs_otro check (
    unavailable_reason is null or unavailable_reason_code = 'otro'
  );

-- Suficiente para una linea corta ("se pincho la llanta cerca del cementerio"),
-- no para una nota de bitacora.
alter table public.drivers
  add constraint drivers_unavailable_reason_length check (
    unavailable_reason is null or length(unavailable_reason) <= 140
  );


-- -----------------------------------------------------------------------------
-- Apagarse con motivo: la unica puerta que lo exige
-- -----------------------------------------------------------------------------
--
-- `security definer` con el mismo patron que `reject_ride_offer` y las cuatro
-- transiciones del viaje: filtra por `auth.uid()` a mano en el UPDATE en lugar
-- de fiarse de RLS, que es como ya trabajan las funciones sencillas del
-- conductor en este archivo.

create function public.set_driver_unavailable(
  p_reason_code public.driver_unavailable_reason_code,
  p_reason_detail text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if p_reason_code is null then
    raise exception 'Elige un motivo antes de desconectarte'
      using errcode = 'P0001', hint = 'UNAVAILABLE_REASON_REQUIRED';
  end if;

  update public.drivers
  set is_available = false,
      unavailable_reason_code = p_reason_code,
      unavailable_reason = nullif(trim(coalesce(p_reason_detail, '')), '')
  where id = v_uid;
end;
$$;

comment on function public.set_driver_unavailable(public.driver_unavailable_reason_code, text) is
  'El conductor se desconecta con un motivo del catalogo (D270). Simetrico a la escritura directa que ya usa el cliente para encenderse (D83): apagar con motivo pasa por aqui, encender sigue siendo un UPDATE del cliente.';

revoke all on function public.set_driver_unavailable(public.driver_unavailable_reason_code, text)
  from public, anon;
grant execute on function public.set_driver_unavailable(public.driver_unavailable_reason_code, text)
  to authenticated;


-- -----------------------------------------------------------------------------
-- Reactivarse limpia el motivo de la vez pasada
-- -----------------------------------------------------------------------------

create function public.clear_unavailable_reason_on_available()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_available then
    new.unavailable_reason_code := null;
    new.unavailable_reason := null;
  end if;

  return new;
end;
$$;

comment on function public.clear_unavailable_reason_on_available() is
  'Borra el motivo de desconexion en cuanto is_available vuelve a true, sin importar quien lo active (D270).';

create trigger drivers_clear_unavailable_reason
  before update on public.drivers
  for each row execute function public.clear_unavailable_reason_on_available();


-- -----------------------------------------------------------------------------
-- El panel: `admin_list_drivers` trae el motivo
-- -----------------------------------------------------------------------------
--
-- Redefinicion completa porque cambia el `returns table` -Postgres no admite
-- anadir columnas a una funcion existente con `create or replace` sin repetir
-- toda la firma-. El resto del cuerpo es igual a `20260826220000`.

drop function public.admin_list_drivers();

create function public.admin_list_drivers()
returns table (
  driver_id uuid,
  full_name text,
  phone text,
  account_status public.user_status,
  approval_status public.driver_approval_status,
  approved_at timestamptz,
  is_available boolean,
  unavailable_reason_code public.driver_unavailable_reason_code,
  unavailable_reason text,
  rating_average numeric,
  rating_count integer,

  vehicle_id uuid,
  unit_number integer,
  plate text,

  has_active_ride boolean,

  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    d.id,
    p.full_name,
    p.phone,
    p.status,
    d.approval_status,
    d.approved_at,
    d.is_available,
    d.unavailable_reason_code,
    d.unavailable_reason,
    d.rating_average,
    d.rating_count,

    v.id,
    v.unit_number,
    v.plate,

    exists (
      select 1 from public.rides r
      where r.driver_id = d.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    d.created_at
  from public.drivers d
  join public.profiles p on p.id = d.id
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id
  order by
    case d.approval_status when 'pending' then 0 when 'approved' then 1 else 2 end,
    p.full_name;
$$;

comment on function public.admin_list_drivers() is
  'Listado de conductores para el panel, con su vehiculo asignado, si esta ocupado y el motivo de su ultima desconexion voluntaria (D270).';

revoke all on function public.admin_list_drivers() from public;
grant execute on function public.admin_list_drivers() to authenticated;
