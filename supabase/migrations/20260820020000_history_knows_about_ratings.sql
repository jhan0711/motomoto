-- =============================================================================
-- Fase 17, paso 4: el historial sabe que esta calificado y que no
-- =============================================================================
--
-- Las cuatro funciones de la Fase 16 devuelven ahora si QUIEN LLAMA ya califico
-- ese servicio, y las de detalle devuelven ademas las estrellas y el comentario
-- que dio. Con eso la lista puede senalar lo que quedo pendiente y el detalle
-- puede ofrecer calificarlo, que es lo unico que faltaba para que una
-- calificacion no dependa de estar mirando la pantalla en el minuto justo en que
-- termina el servicio.
--
-- SIEMPRE FILTRADO POR `rater_id`, nunca solo por viaje. La politica
-- `ratings_select_involved` deja ver las dos filas de un mismo servicio: la que
-- uno dio y la que recibio. Sin el filtro, un servicio calificado por la otra
-- parte se veria como calificado por uno mismo, y la aplicacion dejaria de
-- ofrecer algo que todavia se puede hacer.
--
-- LO QUE NO SE DEVUELVE, Y ES UNA DECISION: la calificacion que uno RECIBIO en
-- ese viaje. Es un dato de la otra parte sobre uno, y ensenarlo viaje por viaje
-- convierte el historial en un sitio donde mirar quien te puso tres estrellas. La
-- nota que si se ve es el promedio del conductor, que ya existe en su perfil
-- desde la Fase 5. Si la empresa lo necesita al detalle, es del panel (Fase 20).
--
-- Hay que borrarlas antes de recrearlas: `create or replace` no admite cambiar
-- las columnas que devuelve una funcion.
-- =============================================================================

drop function if exists public.list_passenger_history(integer, integer);
drop function if exists public.list_driver_history(integer, integer);
drop function if exists public.get_passenger_trip(uuid);
drop function if exists public.get_driver_job(uuid);


-- -----------------------------------------------------------------------------
-- La lista del pasajero
-- -----------------------------------------------------------------------------

create or replace function public.list_passenger_history(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  request_id uuid,
  status public.ride_request_status,
  requested_at timestamptz,
  finished_at timestamptz,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  cancelled_by public.actor_type,
  cancellation_reason text,
  ride_id uuid,
  distance_m integer,
  duration_s integer,
  driver_name text,
  vehicle_unit_number integer,
  vehicle_plate text,
  -- Nulo cuando no hubo viaje: ahi no hay nada que calificar, que es distinto de
  -- estar sin calificar.
  already_rated boolean
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.status,
    r.requested_at,
    coalesce(r.completed_at, r.cancelled_at, r.expires_at),
    r.origin_label,
    r.destination_label,
    r.passenger_count,
    r.cancelled_by,
    r.cancellation_reason,
    v.ride_id,
    v.trip_distance_m,
    v.trip_duration_s,
    v.driver_name,
    v.unit_number,
    v.plate,
    case
      when v.ride_id is not null then exists (
        select 1 from public.ratings c
        where c.ride_id = v.ride_id and c.rater_id = (select auth.uid())
      )
    end
  from public.ride_requests r
    left join lateral (
      select
        d.id as ride_id,
        d.status as ride_status,
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
  where r.passenger_id = (select auth.uid())
    and r.status in ('completed', 'cancelled', 'expired')
  order by r.requested_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

comment on function public.list_passenger_history is
  'Solicitudes terminadas, canceladas y caducadas del pasajero que llama, con si ya las califico. De la mas reciente a la mas antigua.';

revoke all on function public.list_passenger_history(integer, integer) from public, anon;
grant execute on function public.list_passenger_history(integer, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- La lista del conductor
-- -----------------------------------------------------------------------------

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
  passenger_name text,
  already_rated boolean
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
    case when o.response = 'accepted' then p.full_name end,
    case
      when d.id is not null then exists (
        select 1 from public.ratings c
        where c.ride_id = d.id and c.rater_id = (select auth.uid())
      )
    end
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
  'Ofertas cerradas del conductor que llama, con su desenlace y si ya las califico. De la mas reciente a la mas antigua.';

revoke all on function public.list_driver_history(integer, integer) from public, anon;
grant execute on function public.list_driver_history(integer, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- El detalle del pasajero
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
  vehicle_plate text,

  -- La calificacion que dio ESTE pasajero. Nula si no la dio.
  my_stars smallint,
  my_comment text
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
    v.plate,

    c.stars,
    c.comment
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
    left join public.ratings c
      on c.ride_id = v.ride_id and c.rater_id = (select auth.uid())
  where r.id = p_request_id
    and r.passenger_id = (select auth.uid())
    and r.status in ('completed', 'cancelled', 'expired');
$$;

comment on function public.get_passenger_trip is
  'Un servicio cerrado del pasajero que llama, con su linea de tiempo y la calificacion que dio. Cero o una fila.';

revoke all on function public.get_passenger_trip(uuid) from public, anon;
grant execute on function public.get_passenger_trip(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- El detalle del conductor
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

  passenger_name text,

  my_stars smallint,
  my_comment text
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

    case when o.response = 'accepted' then p.full_name end,

    c.stars,
    c.comment
  from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
    left join public.rides d on d.request_id = o.request_id
      and d.driver_id = o.driver_id
    left join public.profiles p on p.id = r.passenger_id
    left join public.ratings c
      on c.ride_id = d.id and c.rater_id = (select auth.uid())
  where o.id = p_offer_id
    and o.driver_id = (select auth.uid())
    and o.response <> 'pending'
    and (d.id is null or d.status in ('completed', 'cancelled'));
$$;

comment on function public.get_driver_job is
  'Una oferta cerrada del conductor que llama, con su linea de tiempo y la calificacion que dio. Cero o una fila.';

revoke all on function public.get_driver_job(uuid) from public, anon;
grant execute on function public.get_driver_job(uuid) to authenticated;
