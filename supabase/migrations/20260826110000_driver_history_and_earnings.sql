-- =============================================================================
-- Bloque especial, paso 7: historial y recaudo del conductor
-- =============================================================================
--
-- Cierra los dos ultimos requisitos del bloque que no fueran nuevos de raiz
-- (D217 seccion 15.21): el historial del conductor (Fase 16) YA EXISTIA y solo
-- le faltaba el valor y el tipo de servicio; el recaudo NO EXISTIA como
-- pantalla ni funcion, pero se apoya en lo que ya hay -`rides` mas
-- `ride_requests`- en vez de necesitar tabla nueva, tal como preveia la
-- auditoria.
--
-- PARTE 1: `list_driver_history` y `get_driver_job` ganan el tipo de servicio,
-- la descripcion de encomienda y el valor. Postgres no deja usar
-- `create or replace` para anadir columnas a un `returns table`, aunque sea al
-- final -"cannot change return type of existing function", 42P13-: hay que
-- borrar y crear, igual que D233 con `quote_fare`.
--
-- PARTE 2: `list_driver_earnings`, nueva. El recaudo es una vista de dinero, no
-- del registro operativo: por eso no reutiliza `list_driver_history` -que trae
-- tambien lo rechazado y lo expirado, sin valor- sino que consulta
-- `rides.status = 'completed'` directamente.
--
-- EL PERIODO LO DECIDE EL SERVIDOR, NO EL RANGO QUE MANDE EL TELEFONO (D154:
-- "con que reloj se decide: el del servidor, no el del telefono", la misma
-- regla que ya aplica al recargo nocturno). Por eso `p_period` es 'today' o
-- 'week' y el servidor calcula la medianoche local con `fare_timezone`; el
-- rango personalizado recibe FECHAS, no instantes, por el mismo motivo: una
-- fecha no arrastra huso horario, un timestamptz si.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Parte 1: el historial gana tipo de servicio, encomienda y valor
-- -----------------------------------------------------------------------------

drop function if exists public.list_driver_history(integer, integer);

create function public.list_driver_history(
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
  already_rated boolean,
  -- Nuevas, D217/paso 7. `fare_amount` viaja aunque no haya viaje -una
  -- solicitud rechazada tambien tiene su valor calculado-, y es la pantalla
  -- quien decide mostrarlo solo cuando hubo servicio de verdad.
  service_type public.service_type,
  fare_amount integer,
  fare_is_rural boolean,
  fare_reference text
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
    end,
    r.service_type,
    r.fare_amount,
    r.fare_is_rural,
    r.fare_reference
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
  'Ofertas cerradas del conductor que llama, con su desenlace, si ya las califico y el valor del servicio. De la mas reciente a la mas antigua.';

revoke all on function public.list_driver_history(integer, integer) from public, anon;
grant execute on function public.list_driver_history(integer, integer) to authenticated;


drop function if exists public.get_driver_job(uuid);

create function public.get_driver_job(p_offer_id uuid)
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
  my_comment text,

  -- Nuevas, D217/paso 7. El detalle trae mas que la lista -el desglose de
  -- viaje y carga, no solo el total- porque aqui es donde el conductor
  -- entiende el numero, igual que ya hace `FareRow` del lado del pasajero.
  service_type public.service_type,
  parcel_description text,
  fare_trip_amount integer,
  fare_cargo_amount integer,
  fare_amount integer,
  fare_is_night boolean,
  fare_is_rural boolean,
  fare_reference text
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
    c.comment,

    r.service_type,
    r.parcel_description,
    r.fare_trip_amount,
    r.fare_cargo_amount,
    r.fare_amount,
    r.fare_is_night,
    r.fare_is_rural,
    r.fare_reference
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
  'Una oferta cerrada del conductor que llama, con su linea de tiempo, su calificacion y el valor del servicio. Cero o una fila.';

revoke all on function public.get_driver_job(uuid) from public, anon;
grant execute on function public.get_driver_job(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- Parte 2: el recaudo, nueva
-- -----------------------------------------------------------------------------

-- Solo lo COMPLETADO tiene valor cobrado de verdad. No reutiliza
-- `list_driver_history` -que trae tambien rechazos y expiraciones- porque el
-- recaudo es dinero entregado, no registro operativo.
create function public.list_driver_earnings(
  p_period text default 'today',
  p_from_date date default null,
  p_to_date date default null
)
returns table (
  ride_id uuid,
  request_id uuid,
  completed_at timestamptz,
  origin_label text,
  destination_label text,
  service_type public.service_type,
  parcel_description text,
  passenger_count smallint,
  fare_amount integer
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_zona  text;
  v_hoy   date;
  v_desde date;
  v_hasta date;  -- exclusivo
begin
  v_zona := (public.get_setting('fare_timezone', '"America/Bogota"')) #>> '{}';
  v_hoy  := (now() at time zone v_zona)::date;

  case p_period
    when 'today' then
      v_desde := v_hoy;
      v_hasta := v_hoy + 1;
    when 'week' then
      -- `date_trunc('week', ...)` es ISO 8601: empieza el lunes, igual que la
      -- semana en Colombia. No hace falta calcularlo a mano.
      v_desde := date_trunc('week', v_hoy::timestamp)::date;
      v_hasta := v_desde + 7;
    when 'custom' then
      if p_from_date is null or p_to_date is null then
        raise exception 'Elige las dos fechas del rango'
          using errcode = 'P0001', hint = 'EARNINGS_RANGE_REQUIRED';
      end if;
      if p_to_date < p_from_date then
        raise exception 'La fecha final no puede ser antes que la inicial'
          using errcode = 'P0001', hint = 'EARNINGS_RANGE_INVALID';
      end if;
      v_desde := p_from_date;
      v_hasta := p_to_date + 1;
    else
      raise exception 'Ese periodo de recaudo no se reconoce'
        using errcode = 'P0001', hint = 'EARNINGS_PERIOD_INVALID';
  end case;

  return query
    select
      d.id,
      r.id,
      d.completed_at,
      r.origin_label,
      r.destination_label,
      r.service_type,
      r.parcel_description,
      r.passenger_count,
      r.fare_amount
    from public.rides d
      join public.ride_requests r on r.id = d.request_id
    where d.driver_id = (select auth.uid())
      and d.status = 'completed'
      and (d.completed_at at time zone v_zona)::date >= v_desde
      and (d.completed_at at time zone v_zona)::date < v_hasta
    order by d.completed_at desc
    limit 500;
end;
$$;

comment on function public.list_driver_earnings is
  'Los servicios completados del conductor que llama dentro de un periodo -hoy, esta semana o un rango de fechas-, con su valor. El total lo suma quien llama.';

revoke all on function public.list_driver_earnings(text, date, date) from public, anon;
grant execute on function public.list_driver_earnings(text, date, date) to authenticated;
