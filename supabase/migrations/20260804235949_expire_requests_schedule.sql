-- =============================================================================
-- Fase 11B: caducidad de las solicitudes desatendidas
-- =============================================================================
--
-- La funcion expire_stale_requests existe desde la Fase 5 y su comentario dice
-- que "la invocara una tarea programada". Esa tarea nunca se creo, asi que hasta
-- hoy nadie caducaba nada: una solicitud que ningun conductor aceptaba se
-- quedaba en searching para siempre.
--
-- Eso no es cosmetico. El indice rr_one_active_per_passenger solo admite una
-- solicitud activa por pasajero (R6), asi que una solicitud fantasma le impide
-- pedir otro servicio. Y en las estadisticas de cobertura de flota, un searching
-- eterno no es ni "nadie acepto" ni "el usuario cancelo", que es justo la
-- distincion que la seccion 8 queria preservar al separar EXPIRED de CANCELLED.
--
-- DECISION D151: dos capas.
--
--   1. pg_cron cada minuto. Es la que deja los datos correctos aunque todos
--      cierren la aplicacion. Barre solicitudes y ofertas.
--   2. Una limpieza dirigida dentro de request_ride, solo de las solicitudes del
--      propio pasajero. Cubre la ventana de hasta sesenta segundos entre barrido
--      y barrido, que es el unico momento en que el usuario notaria el problema.
--
-- La segunda no sustituye a la primera: solo evita que el pasajero se coma un
-- "ya tienes un servicio en curso" por una solicitud que en realidad ya expiro.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- La extension
-- -----------------------------------------------------------------------------

-- Sin clausula "with schema" a proposito. pg_cron no es reubicable y su propio
-- fichero de control decide donde va; forzarle un esquema es un error. El
-- servidor ya lo trae en shared_preload_libraries, comprobado antes de escribir
-- esta migracion, asi que aqui solo queda registrarlo.
create extension if not exists pg_cron;

grant usage on schema cron to postgres;


-- -----------------------------------------------------------------------------
-- La tarea
-- -----------------------------------------------------------------------------

-- Se desprograma primero para que la migracion se pueda volver a aplicar sobre
-- una base que ya la tenga sin acabar con dos tareas haciendo lo mismo.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'expire-stale-requests') then
    perform cron.unschedule('expire-stale-requests');
  end if;
end;
$$;

-- Cada minuto. La regla R1 habla de cinco minutos, asi que un minuto de
-- granularidad es holgado: en el peor caso una solicitud vive 5:59 en vez de
-- 5:00, y ese margen es invisible para quien espera.
--
-- El barrido se apoya en rr_searching_expiry_idx, un indice parcial creado en la
-- Fase 5 precisamente para esto, asi que no recorre la tabla entera.
select cron.schedule(
  'expire-stale-requests',
  '* * * * *',
  'select public.expire_stale_requests();'
);


-- -----------------------------------------------------------------------------
-- request_ride: limpieza dirigida antes de comprobar la regla R6
-- -----------------------------------------------------------------------------

-- Se reescribe entera porque create or replace lo exige. Respecto a la migracion
-- 20260804234258 lo unico que cambia es el bloque marcado FASE 11B.
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

  -- FASE 11, DECISION D150. Van antes que el estado del pasajero porque validan
  -- los argumentos que acaba de enviar, que es lo mas barato de comprobar y lo
  -- mas concreto de explicar. Cierra H11.
  if not public.is_within_service_area(p_origin_lng, p_origin_lat) then
    raise exception 'El punto de recogida esta fuera de la zona de servicio'
      using errcode = 'P0001', hint = 'ORIGIN_OUT_OF_AREA';
  end if;

  if not public.is_within_service_area(p_destination_lng, p_destination_lat) then
    raise exception 'El destino esta fuera de la zona de servicio'
      using errcode = 'P0001', hint = 'DESTINATION_OUT_OF_AREA';
  end if;

  -- FASE 11B, DECISION D151. Cubre la ventana de hasta un minuto entre dos
  -- pasadas de pg_cron. Sin esto, un pasajero que abandono una solicitud y
  -- vuelve justo en ese hueco leeria "ya tienes un servicio en curso" por algo
  -- que en realidad ya caduco.
  --
  -- Solo las suyas, no un barrido global: el barrido completo, ofertas
  -- incluidas, es responsabilidad de la tarea programada. Aqui interesa
  -- desbloquear a quien esta delante de la pantalla, no limpiar la base entera
  -- en mitad de la peticion de un usuario.
  update public.ride_requests
  set status = 'expired'
  where passenger_id = v_uid
    and status = 'searching'
    and expires_at < now();

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
