-- =============================================================================
-- Fase 16, paso 4: el detalle de un servicio
-- =============================================================================
--
-- Dos funciones mas, una por rol, que devuelven UNA fila con todo lo que la
-- lista no cabia: la linea de tiempo completa, la placa, la referencia del
-- punto de recogida y el motivo de la cancelacion.
--
-- SIGUEN SIENDO SECURITY INVOKER, y de nuevo no hace falta ninguna politica
-- nueva. Que el pasajero solo pueda abrir sus solicitudes y el conductor solo
-- sus ofertas lo sostienen `ride_requests_select_own` y `ride_offers_select_own`
-- desde la Fase 5, y ademas cada funcion lo dice en su `where`. Pedir el
-- identificador de otro no da error: da cero filas, que en pantalla es "no
-- encontramos ese servicio" y es exactamente lo que debe pasar.
--
-- LO QUE EL CONDUCTOR NO VE SI NO ACEPTO: ni el nombre del pasajero ni la
-- referencia del punto de recogida. Las dos son datos de una persona concreta y
-- solo aparecen cuando alguien se comprometio a llevarla. La regla es la misma
-- del paso 1, y aqui hay que repetirla porque hay una columna mas que proteger.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El desenlace de una oferta, en un solo sitio
-- -----------------------------------------------------------------------------

-- Esta cuenta estaba escrita dentro de `list_driver_history`. Ahora la necesitan
-- dos funciones, y dos copias de la misma regla son dos copias que se separan:
-- basta con que alguien anada un estado y toque solo una. Se extrae aqui y las
-- dos la llaman.
create or replace function public.ride_offer_outcome(
  p_response public.ride_offer_response,
  p_ride_status public.ride_status,
  p_request_status public.ride_request_status
)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_response = 'rejected' then 'rejected'
    when p_response = 'accepted' and p_ride_status = 'completed' then 'completed'
    when p_response = 'accepted' and p_ride_status = 'cancelled' then 'cancelled'
    -- Sin respuesta suya. Si la solicitud llego a asignarse, fue otro quien la
    -- tomo; si no, se agoto el tiempo sin que nadie fuera.
    when p_request_status in ('assigned', 'in_progress', 'completed') then 'taken_by_other'
    else 'expired'
  end;
$$;

comment on function public.ride_offer_outcome is
  'Como acabo una oferta: completed, cancelled, rejected, taken_by_other o expired.';

revoke all on function public.ride_offer_outcome(
  public.ride_offer_response, public.ride_status, public.ride_request_status
) from public, anon;
grant execute on function public.ride_offer_outcome(
  public.ride_offer_response, public.ride_status, public.ride_request_status
) to authenticated;


-- La lista pasa a usar la funcion en lugar de su copia. El resultado es el
-- mismo; lo que cambia es que ahora solo hay una definicion de la regla.
create or replace function public.list_driver_history(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  offer_id uuid,
  request_id uuid,
  ride_id uuid,
  outcome text,
  offered_at timestamptz,
  responded_at timestamptz,
  finished_at timestamptz,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  pickup_distance_m integer,
  distance_m integer,
  duration_s integer,
  cancelled_by public.actor_type,
  passenger_name text
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    o.id,
    r.id,
    d.id,
    public.ride_offer_outcome(o.response, d.status, r.status),
    o.offered_at,
    o.responded_at,
    coalesce(d.completed_at, d.cancelled_at, o.responded_at, o.expires_at),
    r.origin_label,
    r.destination_label,
    r.passenger_count,
    o.distance_m,
    d.distance_m,
    d.duration_s,
    d.cancelled_by,
    case when o.response = 'accepted' then p.full_name end
  from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
    left join public.rides d on d.request_id = o.request_id
      and d.driver_id = o.driver_id
    left join public.profiles p on p.id = r.passenger_id
  where o.driver_id = (select auth.uid())
    and o.response <> 'pending'
    and (d.id is null or d.status in ('completed', 'cancelled'))
  order by o.offered_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

comment on function public.list_driver_history is
  'Ofertas cerradas del conductor que llama, con su desenlace, de la mas reciente a la mas antigua.';


-- -----------------------------------------------------------------------------
-- El detalle para el pasajero
-- -----------------------------------------------------------------------------

create or replace function public.get_passenger_trip(p_request_id uuid)
returns table (
  request_id uuid,
  status public.ride_request_status,
  passenger_count smallint,
  origin_label text,
  destination_label text,
  pickup_reference text,
  requested_at timestamptz,
  expires_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by public.actor_type,
  cancellation_reason text,

  -- La linea de tiempo sale del VIAJE y no de la solicitud. Los dos guardan
  -- horas parecidas, pero solo el viaje sabe cuando el conductor llego a
  -- esperar, que es el paso que el pasajero recuerda.
  ride_id uuid,
  ride_status public.ride_status,
  accepted_at timestamptz,
  driver_arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  distance_m integer,
  duration_s integer,

  driver_name text,
  vehicle_unit_number integer,
  vehicle_plate text
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.status,
    r.passenger_count,
    r.origin_label,
    r.destination_label,
    r.pickup_reference,
    r.requested_at,
    r.expires_at,
    r.cancelled_at,
    r.cancelled_by,
    r.cancellation_reason,

    v.ride_id,
    v.ride_status,
    v.accepted_at,
    v.driver_arrived_at,
    v.started_at,
    v.completed_at,
    v.trip_distance_m,
    v.trip_duration_s,

    v.driver_name,
    v.unit_number,
    v.plate
  from public.ride_requests r
    left join lateral (
      select
        d.id as ride_id,
        d.status as ride_status,
        d.accepted_at,
        d.driver_arrived_at,
        d.started_at,
        d.completed_at,
        d.distance_m as trip_distance_m,
        d.duration_s as trip_duration_s,
        p.full_name as driver_name,
        veh.unit_number,
        veh.plate
      from public.rides d
        left join public.profiles p on p.id = d.driver_id
        left join public.vehicles veh on veh.id = d.vehicle_id
      where d.request_id = r.id
      order by d.accepted_at desc
      limit 1
    ) v on true
  where r.id = p_request_id
    -- El dueño se comprueba aqui ademas de en la politica, como en
    -- `get_active_request` y en las dos listas del paso 1. La politica es la que
    -- manda; esto hace que la funcion diga por si sola de quien es lo que
    -- devuelve, sin tener que ir a leer la migracion de la Fase 5.
    and r.passenger_id = (select auth.uid())
    and r.status in ('completed', 'cancelled', 'expired');
$$;

comment on function public.get_passenger_trip is
  'Un servicio cerrado del pasajero que llama, con su linea de tiempo. Cero o una fila.';

revoke all on function public.get_passenger_trip(uuid) from public, anon;
grant execute on function public.get_passenger_trip(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- El detalle para el conductor
-- -----------------------------------------------------------------------------

create or replace function public.get_driver_job(p_offer_id uuid)
returns table (
  offer_id uuid,
  request_id uuid,
  ride_id uuid,
  outcome text,
  offered_at timestamptz,
  offer_expires_at timestamptz,
  responded_at timestamptz,
  pickup_distance_m integer,

  requested_at timestamptz,
  origin_label text,
  destination_label text,
  pickup_reference text,
  passenger_count smallint,

  accepted_at timestamptz,
  driver_arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by public.actor_type,
  cancellation_reason text,
  distance_m integer,
  duration_s integer,

  passenger_name text
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    o.id,
    r.id,
    d.id,
    public.ride_offer_outcome(o.response, d.status, r.status),
    o.offered_at,
    o.expires_at,
    o.responded_at,
    o.distance_m,

    r.requested_at,
    r.origin_label,
    r.destination_label,
    -- La referencia la escribe el pasajero para que lo encuentren, y quien no
    -- fue a buscarlo no la necesita. Misma linea que el nombre.
    case when o.response = 'accepted' then r.pickup_reference end,
    r.passenger_count,

    d.accepted_at,
    d.driver_arrived_at,
    d.started_at,
    d.completed_at,
    d.cancelled_at,
    d.cancelled_by,
    d.cancellation_reason,
    d.distance_m,
    d.duration_s,

    case when o.response = 'accepted' then p.full_name end
  from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
    left join public.rides d on d.request_id = o.request_id
      and d.driver_id = o.driver_id
    left join public.profiles p on p.id = r.passenger_id
  where o.id = p_offer_id
    and o.driver_id = (select auth.uid())
    and o.response <> 'pending'
    and (d.id is null or d.status in ('completed', 'cancelled'));
$$;

comment on function public.get_driver_job is
  'Una oferta cerrada del conductor que llama, con su linea de tiempo. Cero o una fila.';

revoke all on function public.get_driver_job(uuid) from public, anon;
grant execute on function public.get_driver_job(uuid) to authenticated;
