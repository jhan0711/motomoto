-- =============================================================================
-- FASE 20, PASO 8: listado e inspeccion de servicios
-- =============================================================================
--
-- La pantalla que responde "que paso con este servicio". Hasta ahora el panel
-- podia ver lo que esta pasando **ahora** (el tablero, paso 3) y lo de **una
-- persona** (paso 7), pero no la operacion entera ni un servicio concreto de
-- punta a punta.
--
-- LO QUE YA EXISTIA Y NO SE REHACE. `list_driver_history` y
-- `list_passenger_history` son de la Fase 16 y **siguen siendo de sus duenos**:
-- cada uno ve lo suyo, con las reglas de privacidad de D198 -el nombre del
-- pasajero solo viaja si el conductor acepto-. Estas funciones son otra cosa:
-- **la empresa mirando su propia operacion**, sin esos filtros, porque para
-- decidir sobre una queja hace falta ver las dos partes.
--
-- EL RECORRIDO SE DEVUELVE COMO DATOS, NO COMO MAPA, y conviene decir por que.
-- `ride_locations` tiene hoy **12 puntos repartidos en 10 viajes**: uno por
-- viaje. No es un fallo de la tabla, es que **el emulador no puede producir
-- movimiento** —esta medido desde la Fase 14— y nadie ha conducido de verdad con
-- la aplicacion. Dibujar un mapa con un punto no ensena nada, asi que el panel
-- muestra lo que hay: cuantos puntos, desde cuando hasta cuando, y la distancia
-- que `complete_ride` calculo. **El mapa se pondra cuando haya rastros de
-- verdad**, y entonces se vera si sirve.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- admin_list_rides
-- -----------------------------------------------------------------------------
--
-- El listado de la operacion, con filtros. `security invoker` (D242): un
-- pasajero que la llamara veria solo sus propias solicitudes, porque
-- `ride_requests_select_own` es lo unico que le deja la RLS.
create or replace function public.admin_list_rides(
  -- Nulo en cualquiera de los tres = sin filtrar por eso.
  p_status public.ride_request_status default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  -- Busca por nombre de pasajero, de conductor, o por etiqueta de origen o
  -- destino. Un solo campo, porque quien busca no sabe de antemano en cual esta
  -- lo que recuerda.
  p_search text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  request_id uuid,
  status public.ride_request_status,
  service_type public.service_type,
  passenger_count smallint,

  passenger_id uuid,
  passenger_name text,
  driver_id uuid,
  driver_name text,
  unit_number integer,

  origin_label text,
  destination_label text,
  fare_amount integer,

  requested_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by public.actor_type,

  -- Cuanto tardo de punta a punta, en minutos. Nulo si no termino.
  duration_minutes integer,

  -- Para que la pantalla pueda decir "1 de 57" sin pedir el listado entero.
  total_count bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  with filtrados as (
    select
      rr.id,
      rr.status,
      rr.service_type,
      rr.passenger_count,
      rr.passenger_id,
      pp.full_name as passenger_name,
      r.driver_id,
      dp.full_name as driver_name,
      v.unit_number,
      rr.origin_label,
      rr.destination_label,
      rr.fare_amount,
      rr.requested_at,
      rr.completed_at,
      rr.cancelled_at,
      rr.cancelled_by
    from public.ride_requests rr
    join public.profiles pp on pp.id = rr.passenger_id
    -- El viaje cancelado no cuenta como "el conductor de este servicio": pudo
    -- echarse atras y haberlo tomado otro. Mismo criterio que el tablero.
    left join public.rides r on r.request_id = rr.id and r.status <> 'cancelled'
    left join public.profiles dp on dp.id = r.driver_id
    left join public.vehicles v on v.id = r.vehicle_id
    where (p_status is null or rr.status = p_status)
      and (p_from is null or rr.requested_at >= p_from)
      and (p_to is null or rr.requested_at < p_to)
      and (
        p_search is null or trim(p_search) = ''
        or pp.full_name ilike '%' || trim(p_search) || '%'
        or dp.full_name ilike '%' || trim(p_search) || '%'
        or rr.origin_label ilike '%' || trim(p_search) || '%'
        or rr.destination_label ilike '%' || trim(p_search) || '%'
      )
  )
  select
    f.*,
    case
      when f.completed_at is not null
      then greatest(0, extract(epoch from (f.completed_at - f.requested_at)) / 60)::integer
    end,
    count(*) over ()
  from filtrados f
  order by f.requested_at desc
  -- Tope de 100, como el historial de la Fase 16 (D199): por la API cualquiera
  -- puede pedir sin techo.
  limit least(coalesce(p_limit, 30), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

comment on function public.admin_list_rides(public.ride_request_status, timestamptz, timestamptz, text, integer, integer) is
  'Listado de servicios de la operacion, con filtros y total para paginar.';

revoke all on function public.admin_list_rides(public.ride_request_status, timestamptz, timestamptz, text, integer, integer) from public;
grant execute on function public.admin_list_rides(public.ride_request_status, timestamptz, timestamptz, text, integer, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_get_ride_detail
-- -----------------------------------------------------------------------------
--
-- Un servicio entero: **la linea de tiempo completa y las dos partes**. Es la
-- pantalla desde la que se resuelve una queja, asi que trae lo que las funciones
-- de la Fase 16 esconden a proposito de cada lado.
create or replace function public.admin_get_ride_detail(p_request_id uuid)
returns table (
  request_id uuid,
  status public.ride_request_status,
  service_type public.service_type,
  parcel_description text,
  passenger_count smallint,

  passenger_id uuid,
  passenger_name text,
  passenger_phone text,
  contact_phone text,

  driver_id uuid,
  driver_name text,
  driver_phone text,
  unit_number integer,
  plate text,

  origin_label text,
  pickup_reference text,
  destination_label text,

  -- El desglose entero, no solo el total: con los precios cambiando desde el
  -- panel, un total suelto no se puede volver a explicar (bloque especial).
  fare_amount integer,
  fare_trip_amount integer,
  fare_cargo_amount integer,
  fare_is_night boolean,
  fare_is_rural boolean,
  fare_reference text,

  -- La linea de tiempo, tal como quedo.
  requested_at timestamptz,
  expires_at timestamptz,
  assigned_at timestamptz,
  accepted_at timestamptz,
  driver_arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by public.actor_type,
  cancellation_reason text,

  distance_m integer,
  duration_s integer,

  -- El rastro, como datos. Ver la cabecera: hoy hay un punto por viaje.
  track_points integer,
  track_first_at timestamptz,
  track_last_at timestamptz,

  -- Cuantos conductores recibieron la oferta y que hicieron. Es lo que responde
  -- "¿por que tardo tanto en encontrar motorraton?".
  offers_total integer,
  offers_rejected integer,
  offers_expired integer
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

    rr.passenger_id,
    pp.full_name,
    pp.phone,
    rr.contact_phone,

    r.driver_id,
    dp.full_name,
    dp.phone,
    v.unit_number,
    v.plate,

    rr.origin_label,
    rr.pickup_reference,
    rr.destination_label,

    rr.fare_amount,
    rr.fare_trip_amount,
    rr.fare_cargo_amount,
    rr.fare_is_night,
    rr.fare_is_rural,
    rr.fare_reference,

    rr.requested_at,
    rr.expires_at,
    rr.assigned_at,
    r.accepted_at,
    r.driver_arrived_at,
    r.started_at,
    rr.completed_at,
    rr.cancelled_at,
    rr.cancelled_by,
    rr.cancellation_reason,

    r.distance_m,
    r.duration_s,

    (select count(*)::integer from public.ride_locations rl where rl.ride_id = r.id),
    (select min(rl.recorded_at) from public.ride_locations rl where rl.ride_id = r.id),
    (select max(rl.recorded_at) from public.ride_locations rl where rl.ride_id = r.id),

    (select count(*)::integer from public.ride_offers o where o.request_id = rr.id),
    (select count(*)::integer from public.ride_offers o
     where o.request_id = rr.id and o.response = 'rejected'),
    (select count(*)::integer from public.ride_offers o
     where o.request_id = rr.id and o.response = 'expired')
  from public.ride_requests rr
  join public.profiles pp on pp.id = rr.passenger_id
  left join public.rides r on r.request_id = rr.id and r.status <> 'cancelled'
  left join public.profiles dp on dp.id = r.driver_id
  left join public.vehicles v on v.id = r.vehicle_id
  where rr.id = p_request_id;
$$;

comment on function public.admin_get_ride_detail(uuid) is
  'Un servicio entero para el panel: linea de tiempo, las dos partes y sus ofertas.';

revoke all on function public.admin_get_ride_detail(uuid) from public;
grant execute on function public.admin_get_ride_detail(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_get_ride_offers
-- -----------------------------------------------------------------------------
--
-- A quien se le ofrecio el servicio y que hizo cada uno.
--
-- **Es lo que convierte "nadie lo tomo" en algo accionable**: si a cinco
-- conductores les llego y los cinco dejaron pasar el tiempo, el problema es
-- otro que si no le llego a ninguno.
create or replace function public.admin_get_ride_offers(p_request_id uuid)
returns table (
  offer_id uuid,
  driver_id uuid,
  driver_name text,
  unit_number integer,
  distance_m integer,
  offered_at timestamptz,
  expires_at timestamptz,
  response public.ride_offer_response,
  responded_at timestamptz,
  -- Cuanto tardo en responder. Nulo si no respondio.
  response_seconds integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    o.id,
    o.driver_id,
    dp.full_name,
    v.unit_number,
    o.distance_m,
    o.offered_at,
    o.expires_at,
    o.response,
    o.responded_at,
    case
      when o.responded_at is not null
      then greatest(0, extract(epoch from (o.responded_at - o.offered_at)))::integer
    end
  from public.ride_offers o
  join public.profiles dp on dp.id = o.driver_id
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = o.driver_id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id
  where o.request_id = p_request_id
  order by o.offered_at;
$$;

comment on function public.admin_get_ride_offers(uuid) is
  'Las ofertas de un servicio: a quien llego, que respondio y cuanto tardo.';

revoke all on function public.admin_get_ride_offers(uuid) from public;
grant execute on function public.admin_get_ride_offers(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_get_ride_ratings
-- -----------------------------------------------------------------------------
--
-- Las calificaciones de un servicio, **en los dos sentidos**. Las funciones de
-- la Fase 17 le ensenan a cada parte lo que le corresponde; esta las pone juntas,
-- que es lo que hace falta para entender una queja.
create or replace function public.admin_get_ride_ratings(p_request_id uuid)
returns table (
  rating_id uuid,
  rater_name text,
  rater_role public.user_role,
  rated_name text,
  stars smallint,
  comment text,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    rt.id,
    rp.full_name,
    rp.role,
    dp.full_name,
    rt.stars,
    rt.comment,
    rt.created_at
  from public.ratings rt
  join public.rides r on r.id = rt.ride_id
  join public.profiles rp on rp.id = rt.rater_id
  join public.profiles dp on dp.id = rt.rated_id
  where r.request_id = p_request_id
  order by rt.created_at;
$$;

comment on function public.admin_get_ride_ratings(uuid) is
  'Las calificaciones de un servicio, en los dos sentidos y juntas.';

revoke all on function public.admin_get_ride_ratings(uuid) from public;
grant execute on function public.admin_get_ride_ratings(uuid) to authenticated;
