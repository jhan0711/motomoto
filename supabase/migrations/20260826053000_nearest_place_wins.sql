-- =============================================================================
-- Bloque especial: corrige D226. Gana el punto nombrado mas cercano, sea el que sea
-- =============================================================================
--
-- D230, que MODIFICA A D226 Y A D227. Lo destaparon las coordenadas reales de la
-- empresa, entregadas el 2026-08-26, y es una correccion de un error del
-- asistente: no de codigo, de interpretacion.
--
-- LO QUE DIJO EL USUARIO, con sus palabras: "si esta mas cerca de un lugar que
-- de el otro, se cobre el del lugar mas cerca". Al escribir D226 eso se estrecho
-- sin darse cuenta a "del destino RURAL mas cercano", y comparando solo contra
-- los rurales el pueblo se queda sin nada con que defenderse.
--
-- EL DATO QUE LO DEMOSTRO. Con las coordenadas de verdad medidas contra el
-- servidor, los destinos rurales no estan lejos del pueblo: estan entremezclados
-- con el. Alto del Rio queda a 1.432 m del parque, El Taparo a 1.459 y Alto
-- Peldar a 2.865. Con el radio de 2 km de D227:
--
--   **32 de los 36 lugares urbanos caian dentro del radio de un destino rural,
--   el parque incluido.** Un viaje al parque habria cobrado 10.800 en vez de
--   4.000.
--
-- No se llego a cargar ninguna tarifa rural con la regla vieja puesta, asi que
-- esto nunca estuvo en produccion. Se vio midiendo antes de cargar.
--
-- LA REGLA NUEVA, que es la que dijo el usuario desde el principio: **gana el
-- punto nombrado mas cercano, urbano o rural.** Si lo mas cerca es el parque, se
-- cobra urbano; si lo mas cerca es Montanita, se cobra Montanita. Un lugar
-- urbano ya no necesita defenderse de nada, porque el mas cercano a el es el
-- mismo, a cero metros.
--
-- Y EL RADIO DEJA DE SER DELICADO, que era lo que mas preocupaba de D227. Sube a
-- 3 km, y ahora si sale de una medida: la separacion entre destinos rurales es
-- de 314 m la minima, 979 la mediana y 4.273 la maxima, asi que un punto en
-- mitad del tramo mas largo queda a 2,2 km de un extremo. Tres kilometros lo
-- cubre con margen y sin holgura. Con la regla nueva, pasarse de radio ya no
-- encarece el pueblo: solo alcanza a puntos que no tienen ningun nombre cerca.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El radio, ahora medido
-- -----------------------------------------------------------------------------

update public.app_settings
set value = '3',
    description = 'D230. Radio para cobrar la tarifa del punto nombrado mas cercano. Medido: los rurales se separan 314 m como minimo y 4.273 como maximo.'
where key = 'rural_snap_max_km';


-- -----------------------------------------------------------------------------
-- quote_fare, comparando contra TODOS los lugares
-- -----------------------------------------------------------------------------

-- No cambia el tipo de retorno, asi que basta con reemplazarla y los permisos se
-- conservan. Solo cambia el bloque que decide la tarifa del viaje.
create or replace function public.quote_fare(
  p_service_type public.service_type,
  p_passenger_count smallint,
  p_destination_lng double precision,
  p_destination_lat double precision,
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
  v_destino  extensions.geography;
  v_cercano  record;
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

  -- La franja cruza la medianoche, asi que es una O y no una Y.
  v_noche := case
    when v_inicio > v_fin then v_hora >= v_inicio or v_hora < v_fin
    else v_hora >= v_inicio and v_hora < v_fin
  end;

  v_destino := extensions.st_setsrid(
    extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326
  )::extensions.geography;

  -- ------------------------------------------------------- la tarifa del viaje

  -- PRIMERO EL DESTINO EXACTO. Si el pasajero eligio Montanita de la lista, paga
  -- Montanita. No hace falta buscar: el punto mas cercano a un lugar es el
  -- mismo, a cero metros, asi que buscar daria la misma respuesta mas despacio.
  if p_destination_place_id is not null then
    select rf.amount, pl.name, 0
      into v_rural, v_ref, v_ref_m
    from public.rural_fares rf
      join public.places pl on pl.id = rf.place_id
    where rf.place_id = p_destination_place_id
      and rf.is_active;
  end if;

  -- Y SI EL DESTINO NO ES UN LUGAR DE LA LISTA, EL MAS CERCANO (D230).
  --
  -- Se mira contra TODOS los lugares activos, no solo contra los que tienen
  -- tarifa rural. Es lo que corrige a D226 y lo que hace que el pueblo no se
  -- encarezca: cerca del parque el nombre mas proximo es un lugar urbano, y un
  -- lugar urbano no pone precio rural.
  --
  -- Que el mas cercano NO tenga tarifa rural es una respuesta valida y
  -- frecuente, no un fallo: significa "esto es urbano".
  if p_destination_place_id is null then
    v_limite := (public.get_setting('rural_snap_max_km', '3'))::double precision;

    select pl.id,
           pl.name,
           round(extensions.st_distance(pl.location, v_destino))::integer as m,
           rf.amount
      into v_cercano
    from public.places pl
      left join public.rural_fares rf on rf.place_id = pl.id and rf.is_active
    where pl.is_active
      -- `st_dwithin` y no `st_distance < x`: el primero usa el indice espacial
      -- de `places` y el segundo obliga a medir contra todas las filas.
      and extensions.st_dwithin(pl.location, v_destino, v_limite * 1000)
    order by pl.location <-> v_destino
    limit 1;

    if found and v_cercano.amount is not null then
      v_rural := v_cercano.amount;
      v_ref   := v_cercano.name;
      v_ref_m := v_cercano.m;
    end if;
  end if;

  v_es_rural := v_rural is not null;

  if v_es_rural then
    -- Plana: no mira cuantos van ni que hora es (D222).
    v_viaje := v_rural;
    v_noche := false;
  else
    v_ref   := null;
    v_ref_m := null;

    -- D219. Solo para lo que NO viene de la lista de la empresa.
    if p_destination_place_id is null then
      v_limite := (public.get_setting('unpriced_destination_max_km', '5'))::double precision;

      select extensions.st_distance(
               extensions.st_setsrid(extensions.st_makepoint(
                 (public.get_setting('fare_center_lng', '-75.074987'))::double precision,
                 (public.get_setting('fare_center_lat', '6.907392'))::double precision
               ), 4326)::extensions.geography,
               v_destino
             ) / 1000.0
        into v_km;

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

    -- NO SE INVENTA UN VALOR POR DEFECTO.
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
  'Cuanto vale un servicio. La tarifa la pone el punto nombrado mas cercano, urbano o rural (D230).';
