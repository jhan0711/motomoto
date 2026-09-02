-- =============================================================================
-- SE DEVUELVEN LAS COLUMNAS QUE LA MIGRACION ANTERIOR SE LLEVO POR DELANTE
-- =============================================================================
--
-- **Error del asistente en `20260902150000`, y de los feos.** Para anadirle dos
-- columnas a `admin_list_active_services` hubo que soltarla y recrearla -no se
-- puede cambiar el tipo de retorno con `create or replace`-, y **se reescribio
-- de memoria en vez de partir de su definicion real**. En el camino se perdieron
-- ocho columnas que si existian:
--
--   fare_is_rural, requested_at, expires_at, ride_status,
--   driver_id, driver_phone, plate, accepted_at
--
-- Lo encontro `prueba_tablero.sql` al pedir `ride_id`, que tambien faltaba.
-- **La prueba de un paso viejo cazo el destrozo de uno nuevo**, que es
-- exactamente para lo que esta la regresion.
--
-- Aqui se parte de la definicion de `20260826200000` copiada entera, y **lo
-- unico que se anade son las dos columnas del paso 11**:
--
--   `driver_blocked` — que la empresa vea en el tablero que ese conductor esta
--   bloqueado. Termina el viaje que lleva (D262), asi que sigue en la lista y
--   sin esto no habria nada que lo distinguiera.
--
--   `signal_lost` — R10. Nulo cuando todavia no hay conductor: no es lo mismo
--   que "hay senal", es que no hay de quien esperarla.
--
-- Se quita tambien el `where public.is_admin()` que la anterior habia colado: la
-- funcion es `security invoker` a proposito y **se apoya en las politicas RLS**,
-- que es lo que decidio `20260826200000`.
-- =============================================================================

drop function if exists public.admin_list_active_services();

create function public.admin_list_active_services()
returns table (
  request_id uuid,
  status public.ride_request_status,
  service_type public.service_type,
  parcel_description text,
  passenger_count smallint,

  passenger_name text,
  passenger_phone text,

  origin_label text,
  destination_label text,
  pickup_reference text,

  fare_amount integer,
  fare_is_rural boolean,
  fare_reference text,

  requested_at timestamptz,
  expires_at timestamptz,
  -- Cuanto lleva vivo el servicio. Se calcula aqui y no en el panel porque el
  -- reloj del navegador lo cambia cualquiera.
  waiting_seconds integer,

  -- Del viaje, cuando ya hay uno. Nulos mientras el servicio sigue en searching.
  ride_id uuid,
  ride_status public.ride_status,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  unit_number integer,
  plate text,
  accepted_at timestamptz,
  driver_location_age_seconds integer,

  -- **PASO 11.** Que su cuenta este bloqueada, y si lleva demasiado sin dar
  -- senal (R10). Las dos son del conductor, asi que van con lo suyo.
  driver_blocked boolean,
  signal_lost boolean,

  -- Cuantos conductores tienen la oferta encima de la mesa ahora mismo.
  pending_offers integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    rr.id,
    rr.status,
    rr.service_type,
    rr.parcel_description,
    rr.passenger_count,

    pp.full_name,
    rr.contact_phone,

    rr.origin_label,
    rr.destination_label,
    rr.pickup_reference,

    rr.fare_amount,
    rr.fare_is_rural,
    rr.fare_reference,

    rr.requested_at,
    rr.expires_at,
    greatest(0, extract(epoch from (now() - rr.requested_at))::integer),

    r.id,
    r.status,
    r.driver_id,
    dp.full_name,
    dp.phone,
    v.unit_number,
    v.plate,
    r.accepted_at,
    case
      when dl.updated_at is null then null
      else greatest(0, extract(epoch from (now() - dl.updated_at))::integer)
    end,

    -- **QUE EL CONDUCTOR ESTE BLOQUEADO SE VE EN EL TABLERO.** Antes no se veia
    -- por ningun lado: la empresa bloqueaba a alguien y el servicio seguia en la
    -- pantalla igual que los demas, sin nada que dijera que ese motorraton es el
    -- ultimo que va a hacer esa persona.
    case when r.driver_id is not null then dp.status = 'blocked' end,

    -- R10. Solo tiene sentido con conductor: en `searching` todavia no hay de
    -- quien esperar senal, y por eso es nulo y no falso.
    case when r.driver_id is not null then
      dl.updated_at is null
      or dl.updated_at < now() - make_interval(
           secs => (public.get_setting('driver_signal_lost_seconds', '180'))::integer)
    end,

    (
      select count(*)::integer
      from public.ride_offers o
      -- La columna se llama `response`, no `status`: una oferta no tiene estado
      -- propio, tiene la respuesta que dio el conductor.
      where o.request_id = rr.id
        and o.response = 'pending'
        and o.expires_at > now()
    )
  from public.ride_requests rr
  join public.profiles pp on pp.id = rr.passenger_id

  -- El viaje cancelado no cuenta: un servicio puede tener un viaje cancelado
  -- -el conductor se echo atras- y haber vuelto a `searching` esperando otro.
  -- Sin este filtro el tablero mostraria el conductor que ya no viene.
  left join public.rides r
    on r.request_id = rr.id and r.status <> 'cancelled'
  left join public.profiles dp on dp.id = r.driver_id
  left join public.vehicles v on v.id = r.vehicle_id
  left join public.driver_locations dl on dl.driver_id = r.driver_id

  where rr.status in ('searching', 'assigned', 'in_progress')
  -- Los que llevan mas tiempo esperando, arriba.
  order by rr.requested_at asc;
$$;

comment on function public.admin_list_active_services() is
  'Servicios en curso para el tablero, con la senal del conductor y si esta bloqueado.';

-- `security invoker` a proposito: las politicas RLS se aplican con la identidad
-- de quien llama, asi que un pasajero solo veria lo suyo.
revoke all on function public.admin_list_active_services() from public;
revoke all on function public.admin_list_active_services() from anon, authenticated;
grant execute on function public.admin_list_active_services() to authenticated;
