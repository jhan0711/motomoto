-- =============================================================================
-- CORRECCION DE UN ERROR DEL ASISTENTE, introducido minutos antes en
-- 20260827080000_admin_places_and_rural_fares.sql (Fase 20, paso 6a).
-- =============================================================================
--
-- QUE ESTABA MAL. `admin_create_place` llamaba a `is_within_service_area`
-- pasandole un `geography`, y esa funcion **recibe longitud y latitud sueltas**:
-- `is_within_service_area(p_lng double precision, p_lat double precision)`.
--
-- POR QUE PASO, y es lo unico que merece la pena de este error: **se supuso la
-- firma en vez de mirarla**. La funcion existe desde la Fase 11 y se uso de
-- memoria, sin abrir su definicion. La regla 2 del proyecto -verificar, no
-- suponer- vale tambien para las firmas de las funciones propias, no solo para
-- los datos.
--
-- Lo unico bueno: **fallaba al ejecutarse, no en silencio**. Un error de tipos
-- en PL/pgSQL no salta al crear la funcion, solo al llamarla, asi que lo cazo la
-- primera comprobacion de `prueba_lugares.sql` que intento crear un lugar. Si la
-- prueba no hubiera existido, el fallo habria aparecido en el panel.
-- =============================================================================

create or replace function public.admin_create_place(
  p_name text,
  p_lng double precision,
  p_lat double precision,
  p_description text default null,
  p_sort_order smallint default 0,
  p_rural_amount integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_center extensions.geography;
  v_max_km double precision;
  v_distance double precision;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede crear lugares'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if length(trim(coalesce(p_name, ''))) not between 2 and 120 then
    raise exception 'El nombre debe tener entre 2 y 120 caracteres'
      using errcode = 'P0001', hint = 'INVALID_PLACE_NAME';
  end if;

  if exists (select 1 from public.places where lower(trim(name)) = lower(trim(p_name))) then
    raise exception 'Ya existe un lugar con ese nombre'
      using errcode = 'P0001', hint = 'PLACE_NAME_TAKEN';
  end if;

  if p_lng is null or p_lat is null then
    raise exception 'El lugar necesita una coordenada'
      using errcode = 'P0001', hint = 'PLACE_NEEDS_LOCATION';
  end if;

  -- AQUI ESTABA EL FALLO: recibe lng y lat, no un punto.
  if not public.is_within_service_area(p_lng, p_lat) then
    raise exception 'Ese punto esta fuera del area de servicio del municipio'
      using errcode = 'P0001', hint = 'PLACE_OUTSIDE_SERVICE_AREA';
  end if;

  if p_rural_amount is not null and (p_rural_amount <= 0 or p_rural_amount > 1000000) then
    raise exception 'La tarifa debe estar entre 1 y 1.000.000 de pesos'
      using errcode = 'P0001', hint = 'INVALID_FARE_AMOUNT';
  end if;

  -- D229: no se crea un lugar lejano sin decidir su tarifa. El radio es el mismo
  -- `unpriced_destination_max_km` que usa D219 para rebotar destinos sin precio,
  -- asi que afinar uno afina el otro.
  select
    extensions.st_setsrid(
      extensions.st_makepoint(
        (select (value #>> '{}')::double precision from public.app_settings
         where key = 'fare_center_lng'),
        (select (value #>> '{}')::double precision from public.app_settings
         where key = 'fare_center_lat')
      ), 4326)::extensions.geography,
    (select (value #>> '{}')::double precision from public.app_settings
     where key = 'unpriced_destination_max_km')
  into v_center, v_max_km;

  v_distance := extensions.st_distance(
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
    v_center
  );

  if v_distance > v_max_km * 1000 and p_rural_amount is null then
    raise exception 'Ese lugar esta a % km del centro. Necesita una tarifa rural, o la aplicacion no dejara pedir viajes hasta alli',
      round((v_distance / 1000)::numeric, 1)
      using errcode = 'P0001', hint = 'DISTANT_PLACE_NEEDS_FARE';
  end if;

  insert into public.places (name, description, location, sort_order)
  values (
    trim(p_name),
    nullif(trim(coalesce(p_description, '')), ''),
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
    p_sort_order
  )
  returning id into v_id;

  if p_rural_amount is not null then
    insert into public.rural_fares (place_id, amount, updated_by)
    values (v_id, p_rural_amount, (select auth.uid()));
  end if;

  perform public.log_admin_action(
    'create_place', 'places', v_id::text, null,
    jsonb_build_object('name', trim(p_name), 'lng', p_lng, 'lat', p_lat,
                       'distance_from_center_m', round(v_distance),
                       'rural_amount', p_rural_amount)
  );

  return v_id;
end;
$$;

comment on function public.admin_create_place(text, double precision, double precision, text, smallint, integer) is
  'Crea un lugar. Exige tarifa rural si cae fuera del radio de D219 (D229).';
