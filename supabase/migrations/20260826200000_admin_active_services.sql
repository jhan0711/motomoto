-- =============================================================================
-- FASE 20, PASO 3: el tablero de servicios en curso
-- =============================================================================
--
-- La primera pantalla con contenido real del panel. Responde a la pregunta que
-- se hace un despachador: **que esta pasando ahora mismo**.
--
-- POR QUE UNA FUNCION Y NO CONSULTAS DIRECTAS. Las politicas RLS de la Fase 5 ya
-- dejan a un administrador leer `ride_requests`, `rides`, `profiles`, `drivers`
-- y `vehicles`, asi que el panel PODRIA armar esto con joins desde el navegador.
-- Se hace con funcion por lo mismo que el historial de la Fase 16: la forma del
-- dato queda decidida en un sitio, el panel no tiene que saber que un servicio
-- vive repartido entre dos tablas, y el dia que cambie el reparto no hay que
-- tocar la pantalla. Ademas evita cinco consultas anidadas por fila.
--
-- QUE CUENTA COMO "EN CURSO". Los tres estados vivos de `ride_request_status`:
--
--   searching     nadie lo ha aceptado todavia
--   assigned      hay conductor, aun no ha empezado el recorrido
--   in_progress   el recorrido va en marcha
--
-- `completed`, `cancelled` y `expired` son pasado y salen del listado de
-- servicios del paso 8, no de aqui.
--
-- **`searching` es el estado que mas importa del tablero**, aunque parezca el
-- menos interesante: un servicio que lleva rato buscando y no encuentra
-- motorraton es el problema que la empresa quiere ver ANTES de que el pasajero
-- se canse y cancele. Por eso la funcion devuelve `waiting_seconds`, calculado
-- con el reloj del servidor (D154) y no con el del navegador.
-- =============================================================================

create or replace function public.admin_list_active_services()
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
  -- reloj del navegador lo cambia cualquiera, y porque una pantalla que resta
  -- fechas en el cliente se desincroniza con el servidor en cuanto hay latencia.
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
  -- Cuando se supo por ultima vez donde estaba el conductor. Un tablero que
  -- muestra un servicio en marcha con una posicion de hace veinte minutos esta
  -- mintiendo, y esa es justo la alerta de R10 que espera el paso 11.
  driver_location_age_seconds integer,

  -- Cuantos conductores tienen la oferta encima de la mesa ahora mismo. Solo
  -- tiene sentido en searching, y es lo que distingue "nadie la ha visto" de
  -- "la han visto cinco y ninguno la coge".
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

    (
      select count(*)::integer
      from public.ride_offers o
      -- La columna se llama `response`, no `status`: una oferta no tiene estado
      -- propio, tiene la respuesta que dio el conductor. El enum es
      -- `ride_offer_response` -pending, accepted, rejected, expired-.
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
  -- Los que llevan mas tiempo esperando, arriba. Es el orden en que un
  -- despachador quiere leerlos: lo que se esta pudriendo primero.
  order by rr.requested_at asc;
$$;

comment on function public.admin_list_active_services() is
  'Servicios en curso para el tablero del panel. searching, assigned e in_progress.';

-- `security invoker` a proposito, al reves que las funciones que escriben: aqui
-- interesa que las politicas RLS se apliquen con la identidad de quien llama.
-- Un pasajero que llame a esta funcion vera solo lo suyo, y no lo de todos, que
-- es lo que pasaria con `security definer`. La comprobacion de administrador no
-- hace falta porque la hacen las politicas, y la prueba lo mide.
revoke all on function public.admin_list_active_services() from public;
grant execute on function public.admin_list_active_services() to authenticated;
