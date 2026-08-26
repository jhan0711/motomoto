-- =============================================================================
-- Bloque especial, paso 4: request_ride crea encomiendas, carga y valor
-- =============================================================================
--
-- Engancha todo lo de los pasos anteriores. Es la funcion que cierra D217: a
-- partir de aqui una solicitud nace con su valor escrito, el mismo que el
-- pasajero vio antes de confirmar.
--
-- AVISO, EL DE SIEMPRE Y POR CUARTA VEZ. `request_ride` se reescribe entera cada
-- vez, asi que hay que partir de la ULTIMA version aplicada y no de la primera
-- que aparezca al buscar:
--
--   grep -l "function public.request_ride(" supabase/migrations/*.sql
--
-- Esta parte de `20260811184748_pickup_reference.sql`, que era la que mandaba.
-- **Se conservan las once comprobaciones que ya tenia**, en el mismo orden:
-- perfil, cuenta bloqueada, rol, telefono, R11, las dos de zona de servicio
-- (D150), la referencia, la caducidad dirigida (D151), R6 y la de conductores
-- disponibles (R1 revisada). Eso es justo lo que E30 borro sin querer, y por eso
-- las pruebas de regresion de aquel error siguen puestas.
--
-- LOS CUATRO PARAMETROS NUEVOS VAN AL FINAL Y CON VALOR POR DEFECTO. Asi la
-- llamada que hoy hace la aplicacion sigue valiendo sin tocar una linea de
-- TypeScript: un viaje de pasajeros sin carga es exactamente lo que era. La
-- pantalla se ocupa despues, en su propio paso.
--
-- `find_available_drivers` NO SE TOCA, y conviene decir por que no hizo falta.
-- Filtra por `asientos libres >= p_passenger_count`, y una encomienda pide cero,
-- asi que cualquier conductor disponible es candidato, incluso uno con el
-- motorraton lleno. Es exactamente lo que dice D220: la carga va en la parrilla
-- y no quita puesto. Comprobado leyendo la funcion antes de decidir no tocarla.
-- =============================================================================

drop function if exists public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text
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
  p_pickup_reference text default null,
  p_service_type public.service_type default 'passenger',
  p_parcel_description text default null,
  p_cargo_type_ids uuid[] default '{}',
  p_cargo_quantities smallint[] default '{}'
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
  v_parcel text;
  v_fare record;
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
  --
  -- VALE TAMBIEN PARA LA ENCOMIENDA, y con mas motivo: quien manda un paquete no
  -- va a bordo, asi que el telefono es la unica forma que tiene el conductor de
  -- localizarle si algo se tuerce.
  if v_profile.phone is null then
    raise exception 'Necesitas registrar un telefono antes de solicitar un servicio'
      using errcode = 'P0001', hint = 'PHONE_REQUIRED';
  end if;

  -- ------------------------------------------------- lo que trae cada servicio

  -- La descripcion se normaliza antes de mirarla, igual que la referencia: un
  -- campo con tres espacios es un campo vacio.
  v_parcel := nullif(trim(coalesce(p_parcel_description, '')), '');

  if p_service_type = 'parcel' then
    -- Una encomienda con pasajeros no es una encomienda: es un pasajero con
    -- carga. Los tres casos no se confunden.
    if p_passenger_count <> 0 then
      raise exception 'Una encomienda no lleva pasajeros'
        using errcode = 'P0001', hint = 'PARCEL_HAS_NO_PASSENGERS';
    end if;

    -- La restriccion de la tabla ya lo impide, pero un mensaje claro vale mas
    -- que un 23514 en la pantalla del usuario. Mismo criterio que R6 con su
    -- indice unico.
    if v_parcel is null then
      raise exception 'Dinos que es la encomienda'
        using errcode = 'P0001', hint = 'PARCEL_DESCRIPTION_REQUIRED';
    end if;

    if length(v_parcel) < 3 or length(v_parcel) > 120 then
      raise exception 'La descripcion de la encomienda debe tener entre 3 y 120 caracteres'
        using errcode = 'P0001', hint = 'PARCEL_DESCRIPTION_LENGTH';
    end if;

    if coalesce(array_length(p_cargo_type_ids, 1), 0) = 0 then
      raise exception 'Una encomienda necesita al menos una carga'
        using errcode = 'P0001', hint = 'PARCEL_NEEDS_CARGO';
    end if;
  else
    -- REGLA R11, leida de la configuracion y no fijada en el codigo.
    v_max := (public.get_setting('max_passengers_per_request', '3'))::smallint;
    if p_passenger_count < 1 or p_passenger_count > v_max then
      raise exception 'La cantidad de pasajeros debe estar entre 1 y %', v_max
        using errcode = 'P0001', hint = 'PASSENGER_COUNT_OUT_OF_RANGE';
    end if;

    -- Se rechaza en lugar de ignorarla. Un viaje de pasajeros ya tiene
    -- `pickup_reference` para las aclaraciones, y guardar en silencio un dato
    -- que la aplicacion no va a ensenar en ningun sitio es peor que decir que
    -- sobra.
    if v_parcel is not null then
      raise exception 'Un viaje de pasajeros no lleva descripcion de encomienda'
        using errcode = 'P0001', hint = 'PARCEL_DESCRIPTION_NOT_ALLOWED';
    end if;
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
  update public.ride_requests
  set status = 'expired'
  where passenger_id = v_uid
    and status = 'searching'
    and expires_at < now();

  -- REGLA R6. El indice unico ya lo impide, pero un mensaje claro vale mas que
  -- una violacion de unicidad en la pantalla del usuario.
  --
  -- SE APLICA IGUAL A LA ENCOMIENDA, y es una decision, no un descuido: una
  -- persona atiende un servicio a la vez, sea el suyo o el de su paquete. Si la
  -- empresa quiere que se pueda mandar una encomienda mientras uno viaja, es una
  -- migracion que cambia el indice `rr_one_active_per_passenger`, y hay que
  -- pedirsela.
  if exists (
    select 1 from public.ride_requests
    where passenger_id = v_uid
      and status in ('searching', 'assigned', 'in_progress')
  ) then
    raise exception 'Ya tienes un servicio en curso'
      using errcode = 'P0001', hint = 'ACTIVE_REQUEST_EXISTS';
  end if;

  v_origin := extensions.st_setsrid(extensions.st_makepoint(p_origin_lng, p_origin_lat), 4326)::extensions.geography;

  -- ------------------------------------------------------------------ el valor

  -- LA MISMA FUNCION QUE LLAMA LA PANTALLA, y de ahi que este bloque sea tan
  -- corto. Es lo unico que garantiza que el pasajero pague lo que vio: dos
  -- calculos separados se desincronizan el dia que alguien toque uno.
  --
  -- Va aqui, despues de las comprobaciones y antes de crear nada, porque puede
  -- fallar: si el destino no se puede cobrar (D219) hay que decirlo antes de que
  -- exista una solicitud, no despues.
  --
  -- Se llama SIN pasarle la hora, para que use la del servidor. Es el unico
  -- sitio del sistema donde eso importa de verdad: la hora del telefono la
  -- cambia cualquiera desde los ajustes, y con ella el recargo nocturno.
  select * into v_fare from public.quote_fare(
    p_service_type,
    p_passenger_count,
    p_destination_lng,
    p_destination_lat,
    p_destination_place_id,
    p_cargo_type_ids,
    p_cargo_quantities
  );

  -- REGLA R1 revisada: si no hay ningun conductor disponible con capacidad, se
  -- avisa de inmediato en lugar de crear una solicitud que va a caducar tras
  -- cinco minutos de espera inutil.
  --
  -- Con una encomienda el conteo pide cero asientos, asi que entra cualquier
  -- conductor disponible aunque lleve el motorraton lleno (D220).
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
    pickup_reference, contact_phone, expires_at,
    service_type, parcel_description,
    fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural, fare_reference
  ) values (
    v_uid, p_passenger_count,
    v_origin, p_origin_label, p_origin_place_id,
    extensions.st_setsrid(extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326)::extensions.geography,
    p_destination_label, p_destination_place_id,
    v_reference, v_profile.phone, now() + make_interval(secs => v_expiry),
    p_service_type, v_parcel,
    v_fare.total_amount, v_fare.trip_amount, v_fare.cargo_amount,
    v_fare.is_night, v_fare.is_rural, v_fare.reference
  ) returning id into v_request_id;

  -- ------------------------------------------------------------------ la carga

  -- ANTES DE OFRECER, no despues. El conductor tiene que ver que le proponen
  -- para decidir si acepta, y si la oferta saliera primero habria un instante en
  -- que la solicitud existe con su precio pero sin decir que lleva.
  --
  -- `unit_amount` se copia de `cargo_types` en este momento (D225). Es la misma
  -- transaccion en la que `quote_fare` acaba de leer esos precios, asi que lo
  -- que se congela es exactamente lo que se cobro: no hay ventana para que el
  -- panel cambie una tarifa entre las dos lecturas.
  if array_length(p_cargo_type_ids, 1) is not null then
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    select v_request_id, c.tipo, c.cantidad, ct.amount
    from unnest(p_cargo_type_ids, p_cargo_quantities) as c(tipo, cantidad)
      join public.cargo_types ct on ct.id = c.tipo;
  end if;

  perform public.offer_request_to_drivers(v_request_id);

  return v_request_id;
end;
$$;

comment on function public.request_ride is
  'Crea una solicitud con su valor ya calculado y la ofrece a los conductores. Unica via de creacion.';

revoke all on function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text,
  public.service_type, text, uuid[], smallint[]
) from public, anon;

grant execute on function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text,
  public.service_type, text, uuid[], smallint[]
) to authenticated;
