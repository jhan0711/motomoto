-- =============================================================================
-- Fase 17, correccion: solo lo TERMINADO puede estar sin calificar
-- =============================================================================
--
-- LO ENCONTRO LA TABLET, con datos reales. Un servicio cancelado que si llego a
-- tener viaje —alguien lo acepto y luego se cayo— salia en el historial marcado
-- como "Sin calificar", y el detalle ofrecia el boton. Tocarlo habria llevado a
-- un error del servidor: `rate_ride` solo acepta servicios TERMINADOS, y con
-- razon, porque no se califica un viaje que no ocurrio.
--
-- La condicion era "hay viaje". La correcta es "hay viaje y termino". Con eso,
-- `already_rated` vuelve a tener sus tres estados con sentido: verdadero ya
-- calificado, falso pendiente de calificar, y **nulo cuando no hay nada que
-- calificar** —caducadas, canceladas antes de aceptar, y ahora tambien
-- canceladas despues de aceptar—.
--
-- Las columnas no cambian, asi que basta con `create or replace`.
-- =============================================================================

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
      when v.ride_status = 'completed' then exists (
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
      when d.status = 'completed' then exists (
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
