-- =============================================================================
-- Migracion 6B: funciones de transicion de estado
-- =============================================================================
--
-- DECISION D15: el cliente nunca hace UPDATE sobre un estado. Estas funciones
-- son la unica puerta.
--
-- Cada una valida tres cosas antes de tocar nada:
--   1. Quien llama y si tiene derecho a hacerlo
--   2. En que estado esta el objeto y si la transicion es legal desde ahi
--   3. Si la operacion tiene sentido en la realidad fisica (por ejemplo, no se
--      puede confirmar llegada estando a dos kilometros)
--
-- Convencion de errores: mensaje en espanol, apto para mostrar al usuario, y un
-- codigo estable en el campo hint para que la aplicacion reaccione sin depender
-- del texto.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Ofrecer una solicitud a los conductores cercanos
-- -----------------------------------------------------------------------------

-- Uso interno. La llama request_ride nada mas crear la solicitud.
--
-- REGLA R12: no se reofrece a quien ya recibio la oferta. El filtro evita el
-- intento, y la restriccion de unicidad de la tabla lo garantiza aunque el
-- filtro fallara.
create or replace function public.offer_request_to_drivers(
  p_request_id uuid,
  p_limit integer default 5
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request public.ride_requests;
  v_seconds integer;
  v_count integer := 0;
begin
  select * into v_request from public.ride_requests where id = p_request_id;
  if not found or v_request.status <> 'searching' then
    return 0;
  end if;

  v_seconds := (public.get_setting('offer_response_seconds', '20'))::integer;

  insert into public.ride_offers (request_id, driver_id, expires_at, distance_m)
  select p_request_id, d.driver_id, now() + make_interval(secs => v_seconds), round(d.distance_m)
  from public.find_available_drivers(
         v_request.origin,
         v_request.passenger_count
       ) d
  where not exists (
    select 1 from public.ride_offers o
    where o.request_id = p_request_id and o.driver_id = d.driver_id
  )
  limit p_limit;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.offer_request_to_drivers(uuid, integer) from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- Solicitar un servicio
-- -----------------------------------------------------------------------------

create or replace function public.request_ride(
  p_origin_lng double precision,
  p_origin_lat double precision,
  p_origin_label text,
  p_destination_lng double precision,
  p_destination_lat double precision,
  p_destination_label text,
  p_passenger_count smallint,
  p_origin_place_id uuid default null,
  p_destination_place_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_max smallint;
  v_expiry integer;
  v_origin extensions.geography;
  v_request_id uuid;
  v_candidates integer;
begin
  select * into v_profile from public.profiles where id = v_uid;

  if not found then
    raise exception 'No se encontro tu perfil' using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  if v_profile.status = 'blocked' then
    raise exception 'Tu cuenta esta bloqueada. Comunicate con la empresa'
      using errcode = 'P0001', hint = 'ACCOUNT_BLOCKED';
  end if;

  if v_profile.role <> 'passenger' then
    raise exception 'Solo los pasajeros pueden solicitar servicios'
      using errcode = 'P0001', hint = 'NOT_A_PASSENGER';
  end if;

  -- Aqui se hace efectiva la obligatoriedad del telefono que profiles permite
  -- dejar vacio: un perfil incompleto es aceptable, una solicitud sin telefono
  -- de contacto no.
  if v_profile.phone is null then
    raise exception 'Necesitas registrar un telefono antes de solicitar un servicio'
      using errcode = 'P0001', hint = 'PHONE_REQUIRED';
  end if;

  -- REGLA R11, leida de la configuracion y no fijada en el codigo.
  v_max := (public.get_setting('max_passengers_per_request', '3'))::smallint;
  if p_passenger_count < 1 or p_passenger_count > v_max then
    raise exception 'La cantidad de pasajeros debe estar entre 1 y %', v_max
      using errcode = 'P0001', hint = 'PASSENGER_COUNT_OUT_OF_RANGE';
  end if;

  -- REGLA R6. El indice unico ya lo impide, pero un mensaje claro vale mas que
  -- una violacion de unicidad en la pantalla del usuario.
  if exists (
    select 1 from public.ride_requests
    where passenger_id = v_uid
      and status in ('searching', 'assigned', 'in_progress')
  ) then
    raise exception 'Ya tienes un servicio en curso'
      using errcode = 'P0001', hint = 'ACTIVE_REQUEST_EXISTS';
  end if;

  v_origin := extensions.st_setsrid(extensions.st_makepoint(p_origin_lng, p_origin_lat), 4326)::extensions.geography;

  -- REGLA R1 revisada: si no hay ningun conductor disponible con capacidad, se
  -- avisa de inmediato en lugar de crear una solicitud que va a caducar tras
  -- cinco minutos de espera inutil.
  select count(*) into v_candidates
  from public.find_available_drivers(v_origin, p_passenger_count);

  if v_candidates = 0 then
    raise exception 'No hay motorratones disponibles en este momento'
      using errcode = 'P0001', hint = 'NO_DRIVERS_AVAILABLE';
  end if;

  v_expiry := (public.get_setting('request_expiry_seconds', '300'))::integer;

  insert into public.ride_requests (
    passenger_id, passenger_count,
    origin, origin_label, origin_place_id,
    destination, destination_label, destination_place_id,
    contact_phone, expires_at
  ) values (
    v_uid, p_passenger_count,
    v_origin, p_origin_label, p_origin_place_id,
    extensions.st_setsrid(extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326)::extensions.geography,
    p_destination_label, p_destination_place_id,
    v_profile.phone, now() + make_interval(secs => v_expiry)
  ) returning id into v_request_id;

  perform public.offer_request_to_drivers(v_request_id);

  return v_request_id;
end;
$$;

comment on function public.request_ride is
  'Crea una solicitud y la ofrece a los conductores cercanos. Unica via de creacion.';


-- -----------------------------------------------------------------------------
-- Aceptar una oferta
-- -----------------------------------------------------------------------------

create or replace function public.accept_ride_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := (select auth.uid());
  v_offer public.ride_offers;
  v_request public.ride_requests;
  v_vehicle uuid;
  v_ride_id uuid;
begin
  select * into v_offer from public.ride_offers where id = p_offer_id;

  if not found or v_offer.driver_id <> v_uid then
    raise exception 'Esa oferta no es tuya' using errcode = 'P0001', hint = 'OFFER_NOT_FOUND';
  end if;

  if v_offer.response <> 'pending' then
    raise exception 'Ya respondiste a esta solicitud'
      using errcode = 'P0001', hint = 'OFFER_ALREADY_ANSWERED';
  end if;

  if v_offer.expires_at < now() then
    raise exception 'La solicitud expiro' using errcode = 'P0001', hint = 'OFFER_EXPIRED';
  end if;

  select * into v_request from public.ride_requests where id = v_offer.request_id for update;

  if v_request.status <> 'searching' then
    raise exception 'Otro conductor tomo esta solicitud'
      using errcode = 'P0001', hint = 'REQUEST_ALREADY_TAKEN';
  end if;

  select a.vehicle_id into v_vehicle
  from public.driver_vehicle_assignments a
  join public.vehicles v on v.id = a.vehicle_id
  where a.driver_id = v_uid and a.unassigned_at is null and v.status = 'active';

  if v_vehicle is null then
    raise exception 'No tienes un motorraton asignado'
      using errcode = 'P0001', hint = 'NO_VEHICLE_ASSIGNED';
  end if;

  -- Marcar la oferta como aceptada. Si otro conductor gano la carrera, el indice
  -- unico parcial ro_one_accepted_per_request rechaza esta escritura. No es una
  -- comprobacion previa que pueda quedarse obsoleta entre el SELECT y el UPDATE:
  -- es el propio motor de la base de datos garantizando que solo pasa uno.
  begin
    update public.ride_offers
    set response = 'accepted', responded_at = now()
    where id = p_offer_id;
  exception when unique_violation then
    raise exception 'Otro conductor tomo esta solicitud'
      using errcode = 'P0001', hint = 'REQUEST_ALREADY_TAKEN';
  end;

  insert into public.rides (request_id, driver_id, vehicle_id, passenger_count)
  values (v_request.id, v_uid, v_vehicle, v_request.passenger_count)
  returning id into v_ride_id;

  update public.ride_requests
  set status = 'assigned', assigned_at = now()
  where id = v_request.id;

  -- Las demas ofertas dejan de tener sentido.
  update public.ride_offers
  set response = 'expired', responded_at = now()
  where request_id = v_request.id and response = 'pending';

  -- REGLA R7: mientras atiende un servicio no recibe otros.
  update public.drivers set is_available = false where id = v_uid;

  return v_ride_id;
end;
$$;


-- -----------------------------------------------------------------------------
-- Rechazar una oferta
-- -----------------------------------------------------------------------------

create or replace function public.reject_ride_offer(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  update public.ride_offers
  set response = 'rejected', responded_at = now()
  where id = p_offer_id
    and driver_id = v_uid
    and response = 'pending';

  if not found then
    raise exception 'Esa oferta no esta disponible'
      using errcode = 'P0001', hint = 'OFFER_NOT_AVAILABLE';
  end if;
end;
$$;


-- -----------------------------------------------------------------------------
-- Transiciones del viaje
-- -----------------------------------------------------------------------------

-- Comprueba que quien llama es el conductor del viaje y que el estado actual
-- permite la transicion. Se usa en las cuatro funciones siguientes.
create or replace function public.assert_ride_driver(
  p_ride_id uuid,
  p_allowed public.ride_status[]
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ride public.rides;
begin
  select * into v_ride from public.rides where id = p_ride_id for update;

  if not found or v_ride.driver_id <> (select auth.uid()) then
    raise exception 'Ese viaje no es tuyo' using errcode = 'P0001', hint = 'RIDE_NOT_FOUND';
  end if;

  if not (v_ride.status = any(p_allowed)) then
    raise exception 'El viaje esta en estado % y no admite esta accion', v_ride.status
      using errcode = 'P0001', hint = 'INVALID_STATE_TRANSITION';
  end if;

  return v_ride;
end;
$$;

revoke all on function public.assert_ride_driver(uuid, public.ride_status[]) from public, anon, authenticated;


-- El conductor sale hacia el punto de recogida.
create or replace function public.start_driving_to_pickup(p_ride_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_ride_driver(p_ride_id, array['assigned']::public.ride_status[]);
  update public.rides set status = 'driver_on_the_way' where id = p_ride_id;
end;
$$;


-- El conductor confirma que llego.
create or replace function public.confirm_driver_arrival(p_ride_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ride public.rides;
  v_radius integer;
  v_distance double precision;
begin
  v_ride := public.assert_ride_driver(
    p_ride_id,
    array['assigned', 'driver_on_the_way']::public.ride_status[]
  );

  -- REGLA R5. Validacion contra la realidad fisica, no solo contra el estado:
  -- no se puede anunciar la llegada estando lejos. Si no hay posicion reciente
  -- del conductor se permite igualmente, porque en zona montanosa perder
  -- cobertura es normal y bloquear el servicio por eso seria peor.
  v_radius := (public.get_setting('driver_arrival_radius_m', '150'))::integer;

  select extensions.st_distance(dl.location, rq.origin)
  into v_distance
  from public.driver_locations dl
  join public.ride_requests rq on rq.id = v_ride.request_id
  where dl.driver_id = v_ride.driver_id
    and dl.updated_at > now() - interval '5 minutes';

  if v_distance is not null and v_distance > v_radius then
    raise exception 'Estas a % metros del punto de recogida. Acercate para confirmar la llegada',
      round(v_distance)
      using errcode = 'P0001', hint = 'TOO_FAR_FROM_PICKUP';
  end if;

  update public.rides
  set status = 'driver_arrived', driver_arrived_at = now()
  where id = p_ride_id;
end;
$$;


-- Empieza el recorrido con el pasajero a bordo.
create or replace function public.start_ride(p_ride_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ride public.rides;
begin
  v_ride := public.assert_ride_driver(p_ride_id, array['driver_arrived']::public.ride_status[]);

  update public.rides
  set status = 'in_progress', started_at = now()
  where id = p_ride_id;

  update public.ride_requests
  set status = 'in_progress', started_at = now()
  where id = v_ride.request_id;
end;
$$;


-- Finaliza el servicio.
create or replace function public.complete_ride(p_ride_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ride public.rides;
  v_distance integer;
  v_points integer;
begin
  v_ride := public.assert_ride_driver(p_ride_id, array['in_progress']::public.ride_status[]);

  -- Longitud del recorrido a partir de los puntos registrados. Hacen falta al
  -- menos dos; si el conductor no tuvo cobertura, se deja sin calcular en lugar
  -- de guardar un cero enganoso.
  select count(*) into v_points from public.ride_locations where ride_id = p_ride_id;

  if v_points >= 2 then
    select round(extensions.st_length(
             extensions.st_makeline(array_agg(location::extensions.geometry order by recorded_at))::extensions.geography
           ))::integer
    into v_distance
    from public.ride_locations where ride_id = p_ride_id;
  end if;

  update public.rides
  set status = 'completed',
      completed_at = now(),
      distance_m = v_distance,
      duration_s = extract(epoch from (now() - started_at))::integer
  where id = p_ride_id;

  update public.ride_requests
  set status = 'completed', completed_at = now()
  where id = v_ride.request_id;

  -- El conductor vuelve a estar libre.
  update public.drivers set is_available = true where id = v_ride.driver_id;
end;
$$;


-- -----------------------------------------------------------------------------
-- Cancelaciones
-- -----------------------------------------------------------------------------

-- Cancelacion por parte del conductor.
--
-- SITUACION DE LA FASE 0: "El conductor cancela". La solicitud vuelve a
-- 'searching' y se ofrece de nuevo, en lugar de dejar al pasajero tirado.
create or replace function public.cancel_ride(p_ride_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ride public.rides;
  v_expiry integer;
begin
  v_ride := public.assert_ride_driver(
    p_ride_id,
    array['assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress']::public.ride_status[]
  );

  update public.rides
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = 'driver',
      cancellation_reason = p_reason
  where id = p_ride_id;

  update public.drivers set is_available = true where id = v_ride.driver_id;

  -- Si el recorrido no habia empezado, el pasajero merece otra oportunidad.
  if v_ride.status in ('assigned', 'driver_on_the_way', 'driver_arrived') then
    v_expiry := (public.get_setting('request_expiry_seconds', '300'))::integer;

    update public.ride_requests
    set status = 'searching',
        assigned_at = null,
        expires_at = now() + make_interval(secs => v_expiry)
    where id = v_ride.request_id;

    perform public.offer_request_to_drivers(v_ride.request_id);
  else
    update public.ride_requests
    set status = 'cancelled',
        cancelled_at = now(),
        cancelled_by = 'driver',
        cancellation_reason = p_reason
    where id = v_ride.request_id;
  end if;
end;
$$;


-- Cancelacion por parte del pasajero.
create or replace function public.cancel_request(p_request_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_request public.ride_requests;
begin
  select * into v_request from public.ride_requests where id = p_request_id for update;

  if not found or (v_request.passenger_id <> v_uid and not public.is_admin()) then
    raise exception 'Esa solicitud no es tuya' using errcode = 'P0001', hint = 'REQUEST_NOT_FOUND';
  end if;

  if v_request.status not in ('searching', 'assigned') then
    raise exception 'Un servicio en curso no se puede cancelar desde aqui'
      using errcode = 'P0001', hint = 'INVALID_STATE_TRANSITION';
  end if;

  update public.rides
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = case when public.is_admin() then 'admin' else 'passenger' end,
      cancellation_reason = p_reason
  where request_id = p_request_id
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived');

  update public.drivers
  set is_available = true
  where id in (select driver_id from public.rides where request_id = p_request_id);

  update public.ride_offers
  set response = 'expired', responded_at = now()
  where request_id = p_request_id and response = 'pending';

  update public.ride_requests
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = case when public.is_admin() then 'admin' else 'passenger' end,
      cancellation_reason = p_reason
  where id = p_request_id;
end;
$$;


-- -----------------------------------------------------------------------------
-- Calificar
-- -----------------------------------------------------------------------------

create or replace function public.rate_ride(
  p_ride_id uuid,
  p_stars smallint,
  p_comment text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_ride public.rides;
  v_passenger uuid;
  v_rated uuid;
  v_rating_id uuid;
begin
  -- En dos consultas y no en una con JOIN. Motivo: SELECT ... INTO con varios
  -- destinos asigna columna a columna, asi que "select r.*, rq.passenger_id into
  -- v_ride, v_passenger" intentaria meter la primera columna suelta en una
  -- variable de tipo fila. Es un error que el compilador no detecta y solo
  -- aparece al crear la funcion.
  select * into v_ride from public.rides where id = p_ride_id;

  if not found then
    raise exception 'Viaje no encontrado' using errcode = 'P0001', hint = 'RIDE_NOT_FOUND';
  end if;

  select passenger_id into v_passenger
  from public.ride_requests where id = v_ride.request_id;

  if v_uid not in (v_passenger, v_ride.driver_id) then
    raise exception 'No participaste en ese viaje'
      using errcode = 'P0001', hint = 'NOT_A_PARTICIPANT';
  end if;

  if v_ride.status <> 'completed' then
    raise exception 'Solo se pueden calificar servicios terminados'
      using errcode = 'P0001', hint = 'RIDE_NOT_COMPLETED';
  end if;

  v_rated := case when v_uid = v_passenger then v_ride.driver_id else v_passenger end;

  -- REGLA R8. La restriccion de unicidad ya lo impide; esto solo mejora el
  -- mensaje que ve el usuario.
  begin
    insert into public.ratings (ride_id, rater_id, rated_id, stars, comment)
    values (p_ride_id, v_uid, v_rated, p_stars, nullif(trim(p_comment), ''))
    returning id into v_rating_id;
  exception when unique_violation then
    raise exception 'Ya calificaste este servicio'
      using errcode = 'P0001', hint = 'ALREADY_RATED';
  end;

  return v_rating_id;
end;
$$;


-- -----------------------------------------------------------------------------
-- Caducar solicitudes desatendidas
-- -----------------------------------------------------------------------------

-- REGLA R1. La invocara una tarea programada. Cierra las solicitudes que nadie
-- acepto y las deja como 'expired', que es un final distinto de 'cancelled': una
-- refleja falta de cobertura de la flota y la otra una decision del usuario.
create or replace function public.expire_stale_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.ride_offers
  set response = 'expired', responded_at = now()
  where response = 'pending' and expires_at < now();

  update public.ride_requests
  set status = 'expired'
  where status = 'searching' and expires_at < now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.expire_stale_requests() from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------

-- Solo estas son accesibles desde la aplicacion. Las auxiliares quedaron
-- explicitamente cerradas mas arriba.
grant execute on function public.request_ride(double precision, double precision, text, double precision, double precision, text, smallint, uuid, uuid) to authenticated;
grant execute on function public.cancel_request(uuid, text) to authenticated;
grant execute on function public.accept_ride_offer(uuid) to authenticated;
grant execute on function public.reject_ride_offer(uuid) to authenticated;
grant execute on function public.start_driving_to_pickup(uuid) to authenticated;
grant execute on function public.confirm_driver_arrival(uuid) to authenticated;
grant execute on function public.start_ride(uuid) to authenticated;
grant execute on function public.complete_ride(uuid) to authenticated;
grant execute on function public.cancel_ride(uuid, text) to authenticated;
grant execute on function public.rate_ride(uuid, smallint, text) to authenticated;
