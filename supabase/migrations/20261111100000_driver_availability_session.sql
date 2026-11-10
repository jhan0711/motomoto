-- =============================================================================
-- D296. Disponibilidad del conductor administrada por el servidor (fase C)
-- =============================================================================
--
-- Diseno y motivos: docs/operaciones/disponibilidad-conductor-diseno.md.
-- Resumen: hoy "disponible" = "ubicacion de hace menos de N segundos". En iOS
-- no corre codigo de la app si el sistema no entrega una posicion, asi que un
-- conductor quieto con la app minimizada desaparece aunque su telefono reciba
-- notificaciones sin problema. Esta migracion separa tres senales: intencion
-- (is_available), seguimiento (ubicacion) y alcanzabilidad (le llega y responde
-- una oferta).
--
-- **NO CAMBIA NADA POR SI SOLA.** El interruptor `availability_mode` nace en
-- 'location', que es la regla de siempre. Se pasa a 'session' desde
-- `app_settings`, sin publicar version, cuando las pruebas con push lo
-- justifiquen; y se vuelve atras igual de facil. Mientras tanto la migracion
-- solo ANOTA (sesiones, ofertas sin responder).
--
-- COMPATIBLE CON LAS APPS YA PUBLICADAS (vc12, vc13, TestFlight): ninguna
-- llama a las funciones nuevas, y no hace falta. Un disparador crea la sesion
-- al pasar `is_available` a verdadero y la cierra al pasar a falso, venga el
-- UPDATE de donde venga.
--
-- Valores acordados con Jhan el 2026-11-10: K = 3 ofertas seguidas sin
-- responder, sesion maxima de 12 h, ventana de alcanzable de 30 min.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Columnas en `drivers` (sin tablas nuevas)
-- ---------------------------------------------------------------------------

alter table public.drivers
  add column availability_session_id uuid,
  add column availability_started_at timestamptz,
  add column last_seen_at            timestamptz,
  add column unanswered_offers       integer not null default 0
    constraint drivers_unanswered_offers_nonneg check (unanswered_offers >= 0),
  add column disconnect_reason       text
    constraint drivers_disconnect_reason_valid check (
      disconnect_reason is null or disconnect_reason in
        ('manual', 'unanswered_offers', 'session_expired', 'other_device')
    ),
  add column location_permission     text
    constraint drivers_location_permission_valid check (
      location_permission is null or location_permission in
        ('always', 'while_in_use', 'denied')
    ),
  add column device_platform         text
    constraint drivers_device_platform_valid check (
      device_platform is null or device_platform in ('android', 'ios')
    );

comment on column public.drivers.availability_session_id is
  'D296. Identifica la sesion "disponible" en curso; cambia cada vez que se enciende.';
comment on column public.drivers.unanswered_offers is
  'D296. Ofertas seguidas que caducaron sin respuesta. A K se desconecta (solo en modo session).';

-- ---------------------------------------------------------------------------
-- 2. Parametros (los valores aprobados). Sin rango en `admin_set_setting`
--    todavia: se cambian por SQL hasta que el panel los exponga.
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value, description) values
  ('availability_mode', '"location"',
   'D296. location = elegible por ubicacion fresca (regla de siempre); session = sesion + alcanzable por push.'),
  ('driver_max_unanswered_offers', '3',
   'D296. Ofertas seguidas sin responder antes de desconectar al conductor (modo session).'),
  ('driver_max_session_hours', '12',
   'D296. Duracion maxima de una sesion disponible (modo session).'),
  ('driver_seen_window_seconds', '1800',
   'D296. Cuanto tiempo cuenta como alcanzable por push un conductor sin ubicacion fresca (modo session).')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 3. `protect_driver_columns`: las columnas de sesion solo las toca el servidor
-- ---------------------------------------------------------------------------
-- Mismas reglas de antes, mas una: el conductor NO puede escribir las columnas
-- nuevas desde su aplicacion (`drivers_update_own` le deja escribir la fila).
-- Las funciones de esta migracion levantan `app.driver_session_write`.

create or replace function public.protect_driver_columns()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if coalesce(current_setting('app.driver_session_write', true), 'off') <> 'on' then
    new.availability_session_id := old.availability_session_id;
    new.availability_started_at := old.availability_started_at;
    new.last_seen_at            := old.last_seen_at;
    new.unanswered_offers       := old.unanswered_offers;
    new.disconnect_reason       := old.disconnect_reason;
    new.location_permission     := old.location_permission;
    new.device_platform         := old.device_platform;
  end if;

  if coalesce(current_setting('motomoto.admin_action', true), '') = 'on'
     and public.is_admin() then
    return new;
  end if;

  if coalesce(current_setting('app.system_rating_update', true), 'off') = 'on' then
    new.approval_status := old.approval_status;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    return new;
  end if;

  new.approval_status := old.approval_status;
  new.approved_at := old.approved_at;
  new.approved_by := old.approved_by;
  new.rating_average := old.rating_average;
  new.rating_count := old.rating_count;
  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. La sesion nace y muere con `is_available`, venga el UPDATE de donde venga
-- ---------------------------------------------------------------------------
-- Se llama `drivers_session_sync` a proposito: los disparadores BEFORE se
-- ejecutan por orden alfabetico, y este tiene que ir DESPUES de
-- `drivers_protect_columns` para poder fijar lo que aquel revierte.

create function public.sync_driver_session()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.is_available and not coalesce(old.is_available, false) then
    new.availability_session_id := gen_random_uuid();
    new.availability_started_at := now();
    new.last_seen_at            := now();
    new.unanswered_offers       := 0;
    new.disconnect_reason       := null;
  elsif not new.is_available and coalesce(old.is_available, false) then
    new.availability_session_id := null;
    new.availability_started_at := null;
    if new.disconnect_reason is null then
      new.disconnect_reason := 'manual';
    end if;
  end if;
  return new;
end;
$function$;

create trigger drivers_session_sync
  before update of is_available on public.drivers
  for each row execute function public.sync_driver_session();

-- ---------------------------------------------------------------------------
-- 5. Ofertas: responder resetea el contador; caducar sin respuesta lo sube
-- ---------------------------------------------------------------------------
-- Solo cuenta como "ignorada" una oferta que caduco POR TIEMPO
-- (`expires_at <= now()`) mientras la solicitud seguia buscando. Una oferta que
-- otro conductor dejo sin objeto, o de una solicitud que el pasajero cancelo,
-- no es culpa del conductor y no cuenta.

create function public.track_offer_response()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_request_status public.ride_request_status;
  v_count integer;
  v_k integer;
begin
  perform set_config('app.driver_session_write', 'on', true);

  if old.response = 'pending' and new.response in ('accepted', 'rejected') then
    update public.drivers
    set unanswered_offers = 0, last_seen_at = now()
    where id = new.driver_id;

  elsif old.response = 'pending' and new.response = 'expired'
        and new.expires_at <= now() then
    select status into v_request_status
    from public.ride_requests where id = new.request_id;

    if v_request_status = 'searching' then
      update public.drivers
      set unanswered_offers = unanswered_offers + 1
      where id = new.driver_id and is_available
      returning unanswered_offers into v_count;

      v_k := (public.get_setting('driver_max_unanswered_offers', '3'))::integer;

      -- Siempre se cuenta; solo se DESCONECTA en modo 'session'.
      if v_count is not null and v_count >= v_k
         and coalesce(public.get_setting('availability_mode', '"location"') #>> '{}', 'location') = 'session' then
        update public.drivers
        set is_available = false, disconnect_reason = 'unanswered_offers'
        where id = new.driver_id;
      end if;
    end if;
  end if;

  return null;
end;
$function$;

create trigger ride_offers_track_response
  after update of response on public.ride_offers
  for each row
  when (old.response is distinct from new.response)
  execute function public.track_offer_response();

-- ---------------------------------------------------------------------------
-- 6. Funciones para la app nueva (las apps ya publicadas no las usan)
-- ---------------------------------------------------------------------------

-- Enciende la disponibilidad y anota plataforma y permiso. Devuelve el id de
-- sesion. El disparador de arriba crea la sesion; esto solo anade los datos.
create function public.driver_go_online(p_platform text, p_permission text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_session uuid;
begin
  if auth.uid() is null then
    raise exception 'Sin sesion' using errcode = 'P0001', hint = 'NOT_AUTHENTICATED';
  end if;

  perform set_config('app.driver_session_write', 'on', true);

  update public.drivers
  set is_available = true,
      device_platform = p_platform,
      location_permission = p_permission,
      last_seen_at = now()
  where id = auth.uid()
  returning availability_session_id into v_session;

  if not found then
    raise exception 'No eres conductor' using errcode = 'P0001', hint = 'NOT_A_DRIVER';
  end if;

  return v_session;
end;
$function$;

-- Anota que el conductor esta vivo (la app lo llama al volver a primer plano) y
-- devuelve el estado real del servidor, para que la pantalla no dependa de una
-- variable local.
create function public.driver_touch(p_permission text default null)
 returns table (is_available boolean, disconnect_reason text, session_id uuid)
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    raise exception 'Sin sesion' using errcode = 'P0001', hint = 'NOT_AUTHENTICATED';
  end if;

  perform set_config('app.driver_session_write', 'on', true);

  update public.drivers d
  set last_seen_at = now(),
      unanswered_offers = 0,
      location_permission = coalesce(p_permission, d.location_permission)
  where d.id = auth.uid();

  return query
    select d.is_available, d.disconnect_reason, d.availability_session_id
    from public.drivers d where d.id = auth.uid();
end;
$function$;

revoke all on function public.driver_go_online(text, text) from public, anon;
revoke all on function public.driver_touch(text) from public, anon;
grant execute on function public.driver_go_online(text, text) to authenticated;
grant execute on function public.driver_touch(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Cierre de sesiones largas, en el servidor (pg_cron, sin depender del telefono)
-- ---------------------------------------------------------------------------

create function public.expire_driver_sessions()
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_count integer;
begin
  -- Solo en modo 'session'. En 'location' no hay sesiones que cerrar.
  if coalesce(public.get_setting('availability_mode', '"location"') #>> '{}', 'location') <> 'session' then
    return 0;
  end if;

  perform set_config('app.driver_session_write', 'on', true);

  update public.drivers
  set is_available = false, disconnect_reason = 'session_expired'
  where is_available
    and availability_started_at is not null
    and availability_started_at < now()
      - make_interval(hours => (public.get_setting('driver_max_session_hours', '12'))::integer);

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

revoke all on function public.expire_driver_sessions() from public, anon, authenticated;

select cron.schedule('driver-session-sweep', '* * * * *', 'select public.expire_driver_sessions()');

-- ---------------------------------------------------------------------------
-- 8. find_available_drivers con los dos modos
-- ---------------------------------------------------------------------------

create or replace function public.find_available_drivers(p_origin geography, p_passenger_count smallint, p_max_staleness interval DEFAULT NULL::interval)
 RETURNS TABLE(driver_id uuid, full_name text, unit_number integer, plate text, max_passengers smallint, rating_average numeric, distance_m double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select
    d.id,
    p.full_name,
    v.unit_number,
    v.plate,
    v.max_passengers,
    d.rating_average,
    extensions.st_distance(dl.location, p_origin) as distance_m
  from public.drivers d
    join public.profiles p on p.id = d.id
    join public.driver_locations dl on dl.driver_id = d.id
    join public.driver_vehicle_assignments a
      on a.driver_id = d.id and a.unassigned_at is null
    join public.vehicles v on v.id = a.vehicle_id
  where d.is_available
    and d.approval_status = 'approved'
    -- D278: sin saldo para el viaje minimo no se le ofrece nada. Es la red de
    -- seguridad de los otros tres cortes: un conductor que quedo encendido, o
    -- al que un ajuste le bajo el saldo, no recibe ofertas que no podria aceptar.
    and public.driver_can_work(d.id)
    and p.status = 'active'
    and v.status = 'active'
    -- Asientos libres, no capacidad total. Un motorraton de tres que ya lleva
    -- dos personas solo sirve para una solicitud de una.
    and v.max_passengers - coalesce((
          select sum(r.passenger_count)
          from public.rides r
          where r.vehicle_id = v.id
            and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
        ), 0) >= p_passenger_count
    -- D296. Dos modos, conmutables desde `app_settings.availability_mode` SIN
    -- publicar version: 'location' es la regla de siempre (solo cuenta la
    -- frescura de la ubicacion) y 'session' separa intencion, seguimiento y
    -- alcanzabilidad -ver docs/operaciones/disponibilidad-conductor-diseno.md-.
    and (
      -- MODO 'location' (por defecto): exactamente lo de antes.
      (
        coalesce(public.get_setting('availability_mode', '"location"') #>> '{}', 'location') <> 'session'
        and dl.updated_at > now() - coalesce(
              p_max_staleness,
              make_interval(secs => (public.get_setting('driver_location_stale_seconds', '120'))::integer)
            )
      )
      or
      -- MODO 'session': sesion vigente, sin demasiadas ofertas ignoradas, y
      -- (ubicacion fresca O alcanzable por push). Un conductor quieto en iOS no
      -- genera ubicacion, pero sigue siendo alcanzable: no se le descarta por
      -- no moverse.
      (
        coalesce(public.get_setting('availability_mode', '"location"') #>> '{}', 'location') = 'session'
        and d.unanswered_offers < (public.get_setting('driver_max_unanswered_offers', '3'))::integer
        and d.availability_started_at is not null
        and d.availability_started_at > now()
              - make_interval(hours => (public.get_setting('driver_max_session_hours', '12'))::integer)
        and (
          dl.updated_at > now() - coalesce(
                p_max_staleness,
                make_interval(secs => (public.get_setting('driver_location_stale_seconds', '120'))::integer)
              )
          or (
            greatest(d.last_seen_at, dl.updated_at) > now()
              - make_interval(secs => (public.get_setting('driver_seen_window_seconds', '1800'))::integer)
            and p.push_token is not null
          )
        )
      )
    )
  -- Se conserva el orden por cercania aunque con D160 ya no decida quien gana.
  -- Sigue sirviendo para dos cosas: la distancia que se guarda en cada oferta, y
  -- el dia que la empresa quiera volver a un reparto por tandas.
  order by dl.location <-> p_origin;
$function$;
