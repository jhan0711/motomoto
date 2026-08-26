-- =============================================================================
-- Bloque especial: D233, la tarifa rural cuenta en los dos sentidos
-- =============================================================================
--
-- Corrige un error del asistente, encontrado por el usuario probando la
-- aplicacion de verdad el 2026-08-26: `quote_fare` solo miraba el DESTINO para
-- decidir si un viaje era rural. Un viaje del parque a Vereda Manzanares
-- cobraba bien, 12.000; el mismo viaje al reves, de Manzanares al parque,
-- cobraba 4.000 urbano, porque el destino era el parque y el origen no se
-- miraba en absoluto. El conductor recorre la misma distancia en los dos
-- sentidos, asi que el precio tiene que ser el mismo.
--
-- LA REGLA NUEVA: se calcula si el origen es rural y si el destino es rural,
-- cada uno por separado con la misma logica de D230 -el punto exacto si tiene
-- `place_id`, si no el nombre mas cercano dentro del radio-, y:
--
--   ninguno de los dos es rural       tarifa urbana, como siempre
--   uno de los dos es rural           esa es la tarifa, sea origen o destino
--   los dos son rurales y distintos   la MAS ALTA de las dos (D233). No hay
--                                     tarifa de la empresa para un trayecto
--                                     entre dos veredas, y la mas alta es el
--                                     lado seguro: no cobrar de menos un viaje
--                                     que probablemente pasa por las dos
--
-- D219 TAMBIEN SE VUELVE SIMETRICO. Antes solo el destino sin lugar y lejos
-- rebotaba con "elige uno de la lista". Ahora el origen puede ser tan lejano
-- como el destino -recoger a alguien en una vereda es justo el caso que este
-- arreglo hace posible-, asi que la misma comprobacion se aplica a los dos.
-- Los codigos de error se separan, ORIGIN_NOT_PRICED y DESTINATION_NOT_PRICED,
-- para que el mensaje no le diga "el destino" a alguien que penso en el punto
-- de recogida.
--
-- CONSECUENCIA QUE HAY QUE SABER: `quote_fare` ahora necesita el origen, no
-- solo el destino. Sin el, no se puede saber si el pasajero esta parado en una
-- vereda. La pantalla del resumen ya podia mostrarse sin ubicacion conocida
-- -D137, "Continuar sin ubicacion"-, y hasta ahora igual calculaba un precio
-- porque el origen no le importaba a la formula. A partir de aqui, sin origen
-- no hay valor que mostrar, y es lo correcto: mostrar un precio sin saber de
-- donde sale seria volver a suponer que es urbano, que es justo el error que
-- se esta corrigiendo.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Funcion auxiliar: la tarifa rural de un punto, si tiene
-- -----------------------------------------------------------------------------

-- Extraida de dentro de `quote_fare` para no escribir la misma logica dos
-- veces, una para el origen y otra para el destino. Devuelve cero filas si el
-- punto no es rural, que es una respuesta valida y frecuente: significa
-- "urbano", no "no se pudo calcular".
create or replace function public.rural_fare_for_point(
  p_lng double precision,
  p_lat double precision,
  p_place_id uuid default null
)
returns table (
  amount integer,
  place_name text,
  distance_m integer
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_punto  extensions.geography;
  v_limite double precision;
begin
  -- El lugar exacto no se redondea a otro (D230): si tiene tarifa propia, es
  -- esa y punto.
  if p_place_id is not null then
    return query
      select rf.amount, pl.name, 0
      from public.rural_fares rf
        join public.places pl on pl.id = rf.place_id
      where rf.place_id = p_place_id
        and rf.is_active;
    return;
  end if;

  v_punto  := extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography;
  v_limite := (public.get_setting('rural_snap_max_km', '3'))::double precision;

  return query
    select rf.amount,
           pl.name,
           round(extensions.st_distance(pl.location, v_punto))::integer
    from public.places pl
      join public.rural_fares rf on rf.place_id = pl.id and rf.is_active
    where pl.is_active
      and extensions.st_dwithin(pl.location, v_punto, v_limite * 1000)
    order by pl.location <-> v_punto
    limit 1;
end;
$$;

comment on function public.rural_fare_for_point is
  'La tarifa rural de un punto -por lugar exacto o por el mas cercano dentro del radio-, o ninguna fila si es urbano.';

revoke all on function public.rural_fare_for_point(double precision, double precision, uuid)
  from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- quote_fare, mirando los dos extremos
-- -----------------------------------------------------------------------------

-- Cambia el orden de los parametros -entran los cuatro del origen-, asi que se
-- borra y se crea en lugar de reemplazar.
drop function if exists public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  uuid, uuid[], smallint[], timestamptz
);

create function public.quote_fare(
  p_service_type public.service_type,
  p_passenger_count smallint,
  p_origin_lng double precision,
  p_origin_lat double precision,
  p_destination_lng double precision,
  p_destination_lat double precision,
  p_origin_place_id uuid default null,
  p_destination_place_id uuid default null,
  p_cargo_type_ids uuid[] default '{}',
  p_cargo_quantities smallint[] default '{}',
  p_at timestamptz default now()
)
returns table (
  is_rural boolean,
  is_night boolean,
  trip_amount integer,
  cargo_amount integer,
  total_amount integer,
  reference text,
  reference_m integer
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_zona     text;
  v_inicio   integer;
  v_fin      integer;
  v_hora     integer;
  v_noche    boolean;
  v_rural    integer;
  v_ref      text;
  v_ref_m    integer;
  v_es_rural boolean;
  v_max      smallint;
  v_pc       smallint;
  v_viaje    integer;
  v_carga    integer := 0;
  v_total    integer;
  v_n        integer;
  v_km       double precision;
  v_limite   double precision;
  v_centro   extensions.geography;
  v_origen   record;
  v_destino  record;
begin
  -- ------------------------------------------------------------ los argumentos

  if p_service_type = 'parcel' then
    if p_passenger_count <> 0 then
      raise exception 'Una encomienda no lleva pasajeros'
        using errcode = 'P0001', hint = 'PARCEL_HAS_NO_PASSENGERS';
    end if;

    if coalesce(array_length(p_cargo_type_ids, 1), 0) = 0 then
      raise exception 'Una encomienda necesita al menos una carga'
        using errcode = 'P0001', hint = 'PARCEL_NEEDS_CARGO';
    end if;
  else
    v_max := (public.get_setting('max_passengers_per_request', '3'))::smallint;
    if p_passenger_count < 1 or p_passenger_count > v_max then
      raise exception 'La cantidad de pasajeros debe estar entre 1 y %', v_max
        using errcode = 'P0001', hint = 'PASSENGER_COUNT_OUT_OF_RANGE';
    end if;
  end if;

  if coalesce(array_length(p_cargo_type_ids, 1), 0)
     <> coalesce(array_length(p_cargo_quantities, 1), 0) then
    raise exception 'Cada carga necesita su cantidad'
      using errcode = 'P0001', hint = 'CARGO_ARRAYS_MISMATCH';
  end if;

  if array_length(p_cargo_type_ids, 1) is not null then
    select count(*), count(distinct t) into v_n, v_max
    from unnest(p_cargo_type_ids) t;
    if v_n <> v_max then
      raise exception 'Hay dos cargas del mismo tipo; usa la cantidad'
        using errcode = 'P0001', hint = 'CARGO_TYPE_REPEATED';
    end if;
  end if;

  -- ------------------------------------------------------------------- la hora

  v_zona   := (public.get_setting('fare_timezone', '"America/Bogota"')) #>> '{}';
  v_inicio := (public.get_setting('night_fare_start_hour', '22'))::integer;
  v_fin    := (public.get_setting('night_fare_end_hour', '5'))::integer;

  v_hora := extract(hour from (p_at at time zone v_zona));

  v_noche := case
    when v_inicio > v_fin then v_hora >= v_inicio or v_hora < v_fin
    else v_hora >= v_inicio and v_hora < v_fin
  end;

  -- ------------------------------------------------------- la tarifa del viaje

  -- D233: se mira el origen y el destino por separado, con la misma logica.
  select * into v_origen  from public.rural_fare_for_point(p_origin_lng, p_origin_lat, p_origin_place_id);
  select * into v_destino from public.rural_fare_for_point(p_destination_lng, p_destination_lat, p_destination_place_id);

  if v_origen.amount is not null and v_destino.amount is not null then
    -- Los dos son rurales. Si es el mismo lugar -ida y vuelta al mismo punto,
    -- caso raro pero posible- da igual cual se use. Si son distintos, gana el
    -- mas caro (D233): no hay tarifa de la empresa para un trayecto entre dos
    -- veredas, y cobrar de menos seria peor que cobrar de mas.
    if v_origen.amount >= v_destino.amount then
      v_rural := v_origen.amount; v_ref := v_origen.place_name; v_ref_m := v_origen.distance_m;
    else
      v_rural := v_destino.amount; v_ref := v_destino.place_name; v_ref_m := v_destino.distance_m;
    end if;
  elsif v_origen.amount is not null then
    v_rural := v_origen.amount; v_ref := v_origen.place_name; v_ref_m := v_origen.distance_m;
  elsif v_destino.amount is not null then
    v_rural := v_destino.amount; v_ref := v_destino.place_name; v_ref_m := v_destino.distance_m;
  end if;

  v_es_rural := v_rural is not null;

  if v_es_rural then
    -- Plana: no mira cuantos van ni que hora es (D222).
    v_viaje := v_rural;
    v_noche := false;
  else
    v_ref   := null;
    v_ref_m := null;

    -- D219, simetrico desde D233: un punto sin lugar y lejos del centro no se
    -- puede cobrar, sea el origen o el destino. Antes solo se miraba el
    -- destino; ahora el origen puede ser una vereda de verdad (es justo el
    -- caso que este arreglo hace posible), asi que necesita la misma regla.
    v_limite := (public.get_setting('unpriced_destination_max_km', '5'))::double precision;
    v_centro := extensions.st_setsrid(extensions.st_makepoint(
                  (public.get_setting('fare_center_lng', '-75.074987'))::double precision,
                  (public.get_setting('fare_center_lat', '6.907392'))::double precision
                ), 4326)::extensions.geography;

    if p_origin_place_id is null then
      v_km := extensions.st_distance(
        v_centro,
        extensions.st_setsrid(extensions.st_makepoint(p_origin_lng, p_origin_lat), 4326)::extensions.geography
      ) / 1000.0;

      if v_km > v_limite then
        raise exception 'Ese punto de recogida no tiene tarifa. Elige uno de la lista'
          using errcode = 'P0001', hint = 'ORIGIN_NOT_PRICED';
      end if;
    end if;

    if p_destination_place_id is null then
      v_km := extensions.st_distance(
        v_centro,
        extensions.st_setsrid(extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326)::extensions.geography
      ) / 1000.0;

      if v_km > v_limite then
        raise exception 'Ese destino no tiene tarifa. Elige uno de la lista'
          using errcode = 'P0001', hint = 'DESTINATION_NOT_PRICED';
      end if;
    end if;

    v_pc := case when p_service_type = 'parcel' then 1::smallint else p_passenger_count end;

    select uf.amount into v_viaje
    from public.urban_fares uf
    where uf.passenger_count = v_pc
      and uf.is_night = v_noche;

    if v_viaje is null then
      raise exception 'No hay tarifa configurada para % pasajeros', v_pc
        using errcode = 'P0001', hint = 'URBAN_FARE_NOT_CONFIGURED';
    end if;
  end if;

  -- ------------------------------------------------------------------ la carga

  if array_length(p_cargo_type_ids, 1) is not null then
    select coalesce(sum(ct.amount * c.cantidad), 0), count(*)
      into v_carga, v_n
    from unnest(p_cargo_type_ids, p_cargo_quantities) as c(tipo, cantidad)
      join public.cargo_types ct on ct.id = c.tipo and ct.is_active;

    if v_n <> array_length(p_cargo_type_ids, 1) then
      raise exception 'Alguna de las cargas ya no esta disponible'
        using errcode = 'P0001', hint = 'CARGO_TYPE_NOT_AVAILABLE';
    end if;

    if exists (select 1 from unnest(p_cargo_quantities) q where q < 1 or q > 20) then
      raise exception 'La cantidad de cada carga debe estar entre 1 y 20'
        using errcode = 'P0001', hint = 'CARGO_QUANTITY_OUT_OF_RANGE';
    end if;
  end if;

  -- ------------------------------------------------------------------ el total

  v_total := case p_service_type
    when 'parcel' then greatest(v_viaje, v_carga)
    when 'passenger' then v_viaje + v_carga
  end;

  return query select v_es_rural, v_noche, v_viaje, v_carga, v_total, v_ref, v_ref_m;
end;
$$;

comment on function public.quote_fare is
  'Cuanto vale un servicio. Rural si el origen o el destino lo son; el mas caro si los dos (D233).';

revoke all on function public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  double precision, double precision, uuid, uuid, uuid[], smallint[], timestamptz
) from public, anon;

grant execute on function public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  double precision, double precision, uuid, uuid, uuid[], smallint[], timestamptz
) to authenticated;


-- -----------------------------------------------------------------------------
-- request_ride, pasandole el origen a quote_fare
-- -----------------------------------------------------------------------------

-- Solo cambia la llamada a `quote_fare`, que ahora recibe los cuatro datos del
-- origen que `request_ride` ya tenia en sus propios parametros. El resto de la
-- funcion no se toca: se reemplaza porque la firma de `quote_fare` cambio, no
-- porque haga falta otra logica aqui. Version de referencia,
-- `20260826040000_request_ride_with_fare.sql`, que sigue siendo la penultima
-- aplicada: comprobado con
--
--   grep -l "function public.request_ride(" supabase/migrations/*.sql
create or replace function public.request_ride(
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

  if v_profile.phone is null then
    raise exception 'Necesitas registrar un telefono antes de solicitar un servicio'
      using errcode = 'P0001', hint = 'PHONE_REQUIRED';
  end if;

  v_parcel := nullif(trim(coalesce(p_parcel_description, '')), '');

  if p_service_type = 'parcel' then
    if p_passenger_count <> 0 then
      raise exception 'Una encomienda no lleva pasajeros'
        using errcode = 'P0001', hint = 'PARCEL_HAS_NO_PASSENGERS';
    end if;

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
    v_max := (public.get_setting('max_passengers_per_request', '3'))::smallint;
    if p_passenger_count < 1 or p_passenger_count > v_max then
      raise exception 'La cantidad de pasajeros debe estar entre 1 y %', v_max
        using errcode = 'P0001', hint = 'PASSENGER_COUNT_OUT_OF_RANGE';
    end if;

    if v_parcel is not null then
      raise exception 'Un viaje de pasajeros no lleva descripcion de encomienda'
        using errcode = 'P0001', hint = 'PARCEL_DESCRIPTION_NOT_ALLOWED';
    end if;
  end if;

  if not public.is_within_service_area(p_origin_lng, p_origin_lat) then
    raise exception 'El punto de recogida esta fuera de la zona de servicio'
      using errcode = 'P0001', hint = 'ORIGIN_OUT_OF_AREA';
  end if;

  if not public.is_within_service_area(p_destination_lng, p_destination_lat) then
    raise exception 'El destino esta fuera de la zona de servicio'
      using errcode = 'P0001', hint = 'DESTINATION_OUT_OF_AREA';
  end if;

  v_reference := nullif(trim(coalesce(p_pickup_reference, '')), '');

  if v_reference is not null and length(v_reference) > 80 then
    raise exception 'La referencia del punto de recogida es demasiado larga'
      using errcode = 'P0001', hint = 'PICKUP_REFERENCE_TOO_LONG';
  end if;

  update public.ride_requests
  set status = 'expired'
  where passenger_id = v_uid
    and status = 'searching'
    and expires_at < now();

  if exists (
    select 1 from public.ride_requests
    where passenger_id = v_uid
      and status in ('searching', 'assigned', 'in_progress')
  ) then
    raise exception 'Ya tienes un servicio en curso'
      using errcode = 'P0001', hint = 'ACTIVE_REQUEST_EXISTS';
  end if;

  v_origin := extensions.st_setsrid(extensions.st_makepoint(p_origin_lng, p_origin_lat), 4326)::extensions.geography;

  -- D233: ahora se le pasa el origen tambien, no solo el destino.
  select * into v_fare from public.quote_fare(
    p_service_type,
    p_passenger_count,
    p_origin_lng,
    p_origin_lat,
    p_destination_lng,
    p_destination_lat,
    p_origin_place_id,
    p_destination_place_id,
    p_cargo_type_ids,
    p_cargo_quantities
  );

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
  'Crea una solicitud con su valor ya calculado -mirando origen y destino- y la ofrece a los conductores. Unica via de creacion.';

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
