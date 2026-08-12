-- =============================================================================
-- Fase 14, paso 1: la referencia del punto de recogida
-- =============================================================================
--
-- POR QUE EXISTE ESTA COLUMNA. Una coordenada no siempre dice donde esta la
-- persona. En Amalfi hay sitios como "Alto de la Virgen" cuyo nombre abarca tres
-- cuadras, y lo que se guarda es la coordenada del LUGAR, no la del pasajero que
-- espera en una de esas esquinas. Hoy eso se resuelve por telefono: la gente
-- dice "estoy frente a la tienda" o "en la casa azul". Esto es meter esa frase
-- en la solicitud, que es donde el conductor puede leerla sin llamar.
--
-- Es corta y opcional a proposito. Obligarla anadiria un paso a cada servicio
-- para cubrir el caso raro, y quien pide desde un lugar sin ambiguedad no tiene
-- nada que escribir. El limite de 80 caracteres es lo que cabe en dos lineas de
-- la tarjeta del conductor sin cortarse: mas texto del que se lee de un vistazo
-- en la calle no ayuda, estorba.
--
-- QUIEN LA VE, Y CUANDO (D172). Solo el conductor que ya acepto. No viaja en la
-- oferta. Es la misma linea que la Fase 12 trazo para el nombre y el telefono
-- del pasajero: antes de aceptar nadie se ha comprometido con nadie, y una
-- referencia como "la casa azul de la esquina" situa a una persona con bastante
-- mas precision que el nombre de un sector. Por eso se anade a
-- `list_driver_active_rides` y NO a las funciones de ofertas.
--
-- REQUEST_RIDE SE BORRA ANTES DE CREARLA, y no es una manera de hablar.
-- `create or replace` empareja por nombre Y tipos de los argumentos, asi que
-- anadir un parametro no reemplaza nada: crea una segunda funcion con nueve
-- argumentos al lado de la nueva de diez. Quedarian las dos vivas, y la vieja
-- seguiria creando solicitudes sin referencia el dia que alguien la llamara por
-- descuido. Al borrarla se pierden sus permisos, asi que hay que volver a
-- concederlos abajo.
--
-- AVISO PARA QUIEN VUELVA A TOCAR ESTA FUNCION. Su cuerpo se reescribe entero
-- cada vez, asi que hay que partir de la ULTIMA version aplicada y no de la
-- primera que aparezca al buscar. Aqui se partio de la de la Fase 5 y se
-- perdieron sin darse cuenta las dos comprobaciones de zona de servicio (D150) y
-- la caducidad dirigida (D151), que se habian anadido despues en dos migraciones
-- distintas. Para saber cual manda:
--
--   grep -l "function public.request_ride(" supabase/migrations/*.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- La columna
-- -----------------------------------------------------------------------------

alter table public.ride_requests
  add column pickup_reference text
    constraint rr_pickup_reference_length check (
      pickup_reference is null or length(trim(pickup_reference)) between 1 and 80
    );

comment on column public.ride_requests.pickup_reference is
  'Referencia escrita del punto de recogida, opcional. La ve el conductor que acepto (D172).';


-- -----------------------------------------------------------------------------
-- Crear la solicitud, ahora con referencia
-- -----------------------------------------------------------------------------

drop function if exists public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid
);

create function public.request_ride(
  p_origin_lng double precision,
  p_origin_lat double precision,
  p_origin_label text,
  p_destination_lng double precision,
  p_destination_lat double precision,
  p_destination_label text,
  p_passenger_count smallint,
  p_origin_place_id uuid default null,
  p_destination_place_id uuid default null,
  p_pickup_reference text default null
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
  v_reference text;
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

  -- La referencia se normaliza aqui y no en la pantalla. Un campo con tres
  -- espacios es un campo vacio, y guardarlo dejaria a la tarjeta del conductor
  -- reservando sitio para una linea en blanco.
  v_reference := nullif(trim(coalesce(p_pickup_reference, '')), '');

  -- Se rechaza en lugar de recortar. Recortar en silencio le devolveria al
  -- pasajero un servicio pedido con una referencia distinta de la que escribio,
  -- y cortada justo por donde estaba el dato que importaba.
  if v_reference is not null and length(v_reference) > 80 then
    raise exception 'La referencia del punto de recogida es demasiado larga'
      using errcode = 'P0001', hint = 'PICKUP_REFERENCE_TOO_LONG';
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
    pickup_reference, contact_phone, expires_at
  ) values (
    v_uid, p_passenger_count,
    v_origin, p_origin_label, p_origin_place_id,
    extensions.st_setsrid(extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326)::extensions.geography,
    p_destination_label, p_destination_place_id,
    v_reference, v_profile.phone, now() + make_interval(secs => v_expiry)
  ) returning id into v_request_id;

  perform public.offer_request_to_drivers(v_request_id);

  return v_request_id;
end;
$$;

comment on function public.request_ride is
  'Crea una solicitud y la ofrece a los conductores cercanos. Unica via de creacion.';


-- -----------------------------------------------------------------------------
-- La solicitud viva del pasajero, ahora con su referencia
-- -----------------------------------------------------------------------------
--
-- Se le devuelve al pasajero lo que el mismo escribio. No es informacion nueva
-- para el, pero sin esto la pantalla que restaura un servicio en curso (D152) no
-- podria ensenarsela, y el pasajero no tendria como comprobar que la referencia
-- que dio es la que le llego al conductor.

drop function if exists public.get_active_request();

create function public.get_active_request()
returns table (
  id uuid,
  status public.ride_request_status,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  pickup_reference text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  requested_at timestamptz,
  expires_at timestamptz,
  seconds_remaining integer,

  -- Todo lo que sigue va en nulo mientras la solicitud sigue en 'searching'.
  -- No hay conductor porque todavia no ha aceptado nadie, y esa es justo la
  -- diferencia que la pantalla necesita distinguir.
  ride_id uuid,
  ride_status public.ride_status,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
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
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(r.origin::extensions.geometry),
    extensions.st_x(r.origin::extensions.geometry),
    r.origin_label,
    r.pickup_reference,
    extensions.st_y(r.destination::extensions.geometry),
    extensions.st_x(r.destination::extensions.geometry),
    r.destination_label,
    r.requested_at,
    r.expires_at,
    -- Los segundos que quedan se calculan aqui y no en el telefono a proposito.
    -- El cliente restaria expires_at menos su propio reloj, y el reloj de un
    -- telefono puede ir desviado minutos. La cuenta atras arranca de este numero
    -- y a partir de ahi corre sola en la pantalla, que para eso si sirve.
    case
      when r.status = 'searching'
      then greatest(0, ceil(extract(epoch from (r.expires_at - now()))))::integer
    end,

    v.ride_id,
    v.ride_status,
    v.driver_name,
    v.driver_phone,
    v.driver_rating,
    v.unit_number,
    v.plate
  from public.ride_requests r
    -- LATERAL con LIMIT 1 y no un join a secas. Hoy una solicitud produce un
    -- solo viaje (D5), pero el modelo admite repartir un grupo entre varios
    -- motorratones, y el dia que eso llegue un join normal duplicaria la
    -- solicitud en lugar de fallar. Asi el contrato de "cero o una fila" se
    -- sostiene solo.
    left join lateral (
      select
        d.id as ride_id,
        d.status as ride_status,
        p.full_name as driver_name,
        p.phone as driver_phone,
        dr.rating_average as driver_rating,
        veh.unit_number,
        veh.plate
      from public.rides d
        join public.drivers dr on dr.id = d.driver_id
        join public.profiles p on p.id = d.driver_id
        join public.vehicles veh on veh.id = d.vehicle_id
      where d.request_id = r.id
        and d.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      order by d.accepted_at desc
      limit 1
    ) v on true
  where r.passenger_id = (select auth.uid())
    and r.status in ('searching', 'assigned', 'in_progress')
    -- Una solicitud que ya paso su hora no se devuelve aunque siga marcada como
    -- searching. Puede estarlo durante menos de un minuto, hasta que pase
    -- pg_cron. Devolverla pintaria una cuenta atras parada en cero, y el
    -- pasajero preferiria un mapa limpio desde el que volver a pedir.
    and (r.status <> 'searching' or r.expires_at > now());
$$;

comment on function public.get_active_request is
  'La solicitud viva del pasajero, con el conductor asignado cuando ya lo hay. Cero o una fila.';


-- -----------------------------------------------------------------------------
-- Los viajes del conductor, ahora con la referencia
-- -----------------------------------------------------------------------------
--
-- Este es el sitio para el que se escribio la columna. Todo lo demas de este
-- archivo existe para que esta linea tenga algo que devolver.

drop function if exists public.list_driver_active_rides();

create function public.list_driver_active_rides()
returns table (
  ride_id uuid,
  request_id uuid,
  status public.ride_status,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  pickup_reference text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  passenger_name text,
  passenger_phone text,
  accepted_at timestamptz
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    v.id,
    r.id,
    v.status,
    v.passenger_count,
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(r.origin::extensions.geometry),
    extensions.st_x(r.origin::extensions.geometry),
    r.origin_label,
    r.pickup_reference,
    extensions.st_y(r.destination::extensions.geometry),
    extensions.st_x(r.destination::extensions.geometry),
    r.destination_label,
    p.full_name,
    -- El telefono sale de la solicitud y no del perfil a proposito: se congelo
    -- al pedir el servicio. Si el pasajero cambia de numero manana, el conductor
    -- que lo esta recogiendo hoy tiene que seguir viendo el que servia entonces.
    r.contact_phone,
    v.accepted_at
  from public.rides v
    join public.ride_requests r on r.id = v.request_id
    join public.profiles p on p.id = r.passenger_id
  where v.driver_id = (select auth.uid())
    and v.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  order by v.accepted_at;
$$;

comment on function public.list_driver_active_rides is
  'Viajes en curso del conductor que llama, con los datos del pasajero. Lista, no fila.';


-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------
--
-- Las tres funciones se borraron, asi que sus permisos se fueron con ellas y hay
-- que volver a concederlos. Una funcion recien creada nace ademas con permiso de
-- ejecucion para PUBLIC, que incluye al rol `anon`: por eso primero se revoca.
--
-- En `request_ride` eso cierra de paso un pendiente que venia de la Fase 11.
-- Hasta hoy `anon` podia llamarla y la funcion lo rechazaba desde dentro, al no
-- encontrarle perfil. Seguia siendo una puerta abierta con un guardia detras.

revoke all on function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text
) from public, anon;

revoke all on function public.get_active_request() from public, anon;
revoke all on function public.list_driver_active_rides() from public, anon;

grant execute on function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text
) to authenticated;

grant execute on function public.get_active_request() to authenticated;
grant execute on function public.list_driver_active_rides() to authenticated;
