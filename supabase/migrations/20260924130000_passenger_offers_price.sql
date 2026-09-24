-- Punto 4 del plan del 2026-09-23 (D277): el pasajero propone el precio y el
-- conductor lo ve antes de aceptar.
--
-- Que cambia y por que:
--
--  * `request_ride` recibe `p_offered_amount`, opcional. Sin el, rige la tarifa
--    oficial de `quote_fare`, asi que la app publicada (vc9/vc10) sigue
--    funcionando sin tocarla. Con el, `fare_amount` guarda el valor ofertado.
--    El servidor lo valida: no puede bajar de la tarifa minima vigente ni pasar
--    de `max_offer_multiple` veces la tarifa oficial de ese viaje.
--
--  * `fare_trip_amount` / `fare_cargo_amount` / `fare_is_night` / `fare_is_rural`
--    / `fare_reference` se CONSERVAN como la tarifa oficial de referencia: lo que
--    la tabla habria cobrado. La tarifa oficial total sale de sumarlos, asi que no
--    hace falta una columna nueva y queda a la vista cuanto se aparto la oferta
--    de ella. Por eso se quita `rr_fare_matches_parts`, que exigia que el total
--    fuera SIEMPRE la suma: ya no lo es cuando el pasajero ofrece otro valor.
--
--  * `list_driver_offers` ahora devuelve el valor ofertado, la tarifa oficial,
--    el tipo de servicio, la descripcion de la encomienda y la carga. Hasta hoy
--    el conductor aceptaba sin ver ninguna de esas cosas.
--
--  * `get_min_offer_amount` da el piso a la pantalla del pasajero, para que el
--    campo lo valide sin esperar el rechazo del servidor.

alter table public.ride_requests drop constraint rr_fare_matches_parts;

comment on column public.ride_requests.fare_amount is
  'El valor acordado del servicio: lo que ofrecio el pasajero, o la tarifa oficial si no ofrecio nada. Sobre esto se calcula la comision.';
comment on column public.ride_requests.fare_trip_amount is
  'Parte de viaje de la TARIFA OFICIAL (referencia). La oficial total es esta mas la carga -o la mayor de las dos en una encomienda-; puede diferir de fare_amount.';

-- ---------------------------------------------------------------------------
-- El piso
-- ---------------------------------------------------------------------------

create function public.get_min_offer_amount()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  -- "Tarifa minima vigente": el valor mas bajo de la tabla urbana, hoy $4.000
  -- (un pasajero, de dia). Se lee de la tabla y no se escribe aqui para que
  -- siga a la empresa si la cambia desde el panel.
  select min(amount) from public.urban_fares;
$$;

revoke all on function public.get_min_offer_amount() from public, anon;
grant execute on function public.get_min_offer_amount() to authenticated;

-- ---------------------------------------------------------------------------
-- request_ride con el valor ofertado
-- ---------------------------------------------------------------------------

-- Firma nueva = funcion nueva. Si la vieja se quedara, PostgREST vera dos
-- `request_ride` y no sabra a cual llamar.
drop function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text,
  public.service_type, text, uuid[], smallint[]
);

create function public.request_ride(p_origin_lng double precision, p_origin_lat double precision, p_origin_label text, p_destination_lng double precision, p_destination_lat double precision, p_destination_label text, p_passenger_count smallint, p_origin_place_id uuid DEFAULT NULL::uuid, p_destination_place_id uuid DEFAULT NULL::uuid, p_pickup_reference text DEFAULT NULL::text, p_service_type service_type DEFAULT 'passenger'::service_type, p_parcel_description text DEFAULT NULL::text, p_cargo_type_ids uuid[] DEFAULT '{}'::uuid[], p_cargo_quantities smallint[] DEFAULT '{}'::smallint[], p_offered_amount integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
  v_price integer;
  v_min integer;
  v_max_multiple integer;
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

  -- D277: el pasajero propone el valor. Sin oferta -clientes viejos, o quien no
  -- toca el campo- rige la tarifa oficial de siempre. El cliente ahora manda un
  -- numero, asi que la frontera de confianza esta aqui y no en la pantalla.
  v_price := coalesce(p_offered_amount, v_fare.total_amount);

  if p_offered_amount is not null then
    v_min := public.get_min_offer_amount();

    if p_offered_amount < v_min then
      raise exception 'El valor ofertado no puede ser menor que la tarifa minima'
        using errcode = 'P0001', hint = 'OFFER_BELOW_MINIMUM';
    end if;

    -- Tope contra el error de dedo -un cero de mas- y no contra la avaricia: si
    -- alguien quiere pagar mas, es su plata, pero $400.000 en vez de $4.000 casi
    -- seguro es un descuido. Relativo a la tarifa oficial de ese viaje.
    v_max_multiple := (public.get_setting('max_offer_multiple', '5'))::integer;

    if p_offered_amount > v_fare.total_amount * v_max_multiple then
      raise exception 'El valor ofertado es demasiado alto para este viaje'
        using errcode = 'P0001', hint = 'OFFER_ABOVE_MAXIMUM';
    end if;
  end if;

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
    v_price, v_fare.trip_amount, v_fare.cargo_amount,
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
$function$
;

comment on function public.request_ride is
  'Crea una solicitud con su valor -el ofertado por el pasajero o, sin oferta, la tarifa oficial- y la ofrece a los conductores. Unica via de creacion.';

revoke all on function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text,
  public.service_type, text, uuid[], smallint[], integer
) from public, anon;

grant execute on function public.request_ride(
  double precision, double precision, text,
  double precision, double precision, text,
  smallint, uuid, uuid, text,
  public.service_type, text, uuid[], smallint[], integer
) to authenticated;

-- ---------------------------------------------------------------------------
-- list_driver_offers con el valor, el tipo de servicio y la carga
-- ---------------------------------------------------------------------------

drop function public.list_driver_offers();

-- `security definer` porque la carga vive en `ride_request_cargo`, que el
-- conductor solo puede leer una vez vinculado al viaje (H15); una oferta
-- pendiente todavia no lo vincula. Sigue siendo seguro por lo mismo que antes:
-- solo devuelve las ofertas de `auth.uid()`, y la carga no es un dato sensible.
create function public.list_driver_offers()
returns table (
  offer_id uuid,
  request_id uuid,
  expires_at timestamptz,
  seconds_remaining integer,
  distance_m integer,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  requested_at timestamptz,
  fare_amount integer,
  fare_official_amount integer,
  service_type public.service_type,
  parcel_description text,
  cargo_summary text
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    o.id,
    r.id,
    o.expires_at,
    -- Calculados por el servidor y no por el telefono, mismo criterio que D154:
    -- un reloj desajustado ensenaria un temporizador falso, y aqui el
    -- temporizador es lo que decide si el conductor llega a tiempo o no.
    greatest(0, ceil(extract(epoch from (o.expires_at - now()))))::integer,
    o.distance_m,
    r.passenger_count,
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(r.origin::extensions.geometry),
    extensions.st_x(r.origin::extensions.geometry),
    r.origin_label,
    extensions.st_y(r.destination::extensions.geometry),
    extensions.st_x(r.destination::extensions.geometry),
    r.destination_label,
    r.requested_at,
    r.fare_amount,
    -- La tarifa que la tabla habria cobrado, para que el conductor vea cuanto
    -- se aparta la oferta de ella. Misma regla de suma que `quote_fare`.
    case r.service_type
      when 'parcel' then greatest(r.fare_trip_amount, r.fare_cargo_amount)
      else r.fare_trip_amount + r.fare_cargo_amount
    end,
    r.service_type,
    r.parcel_description,
    (
      select string_agg(rc.quantity || ' x ' || ct.name, ', ' order by ct.name)
      from public.ride_request_cargo rc
        join public.cargo_types ct on ct.id = rc.cargo_type_id
      where rc.request_id = r.id
    )
  from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
  where o.driver_id = (select auth.uid())
    and o.response = 'pending'
    and o.expires_at > now()
    -- Y la solicitud tiene que seguir buscando. Sin esta condicion, una oferta
    -- cuyo servicio ya se llevo otro conductor seguiria apareciendo hasta que
    -- caducara sola, y el conductor gastaria su atencion en algo que ya no
    -- existe. El estado de la solicitud manda sobre el de la oferta.
    and r.status = 'searching'
  order by o.expires_at;
$$;

revoke all on function public.list_driver_offers() from public, anon;
grant execute on function public.list_driver_offers() to authenticated;
