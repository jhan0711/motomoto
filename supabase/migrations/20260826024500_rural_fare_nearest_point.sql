-- =============================================================================
-- Bloque especial, paso 3b: la tarifa rural del punto mas cercano
-- =============================================================================
--
-- D226. Lo pregunto el usuario el 2026-08-25 y destapo un hueco real: hasta
-- ahora `quote_fare` solo sabia cobrar rural si el destino ERA EXACTAMENTE uno
-- de los 36 de la lista.
--
-- Con sus palabras: "en la lista estan senalados el alto de Montanita y Guaico,
-- en caso tal un pasajero vaya para un punto medio, como se calcularia el
-- costo". Hoy ese punto medio caeria en tarifa urbana —4.000 por un viaje de
-- 20.000— o rebotaria por D219. Las dos respuestas son malas.
--
-- LA REGLA, propuesta por el usuario y aprobada el 2026-08-25: se cobra la
-- tarifa del destino rural MAS CERCANO, si hay alguno lo bastante cerca. Se
-- eligio frente a las otras dos por un motivo concreto: usa unicamente tarifas
-- que la empresa ya autorizo, sin inventar ninguna. Redondear siempre al destino
-- siguiente cobraria de mas a quien se baja doscientos metros despues del punto,
-- y no cobrar los puntos medios devolveria ese pasajero al telefono, que es
-- justo lo que este proyecto quiere quitar.
--
-- POR QUE HACE FALTA UN LIMITE, y es lo que mas cuidado pide. La distancia se
-- mide EN LINEA RECTA, y los 36 destinos salen del pueblo por vias distintas.
-- Sin limite, un punto a 15 km por un camino sin nombre se pegaria a algun
-- destino que queda cerca en el mapa pero lejos por carretera, y saldria barato.
-- Con limite, lo que no se pega cae en D219 y se rechaza, que es el fallo
-- seguro: mejor no dejar pedir que cobrar de menos en silencio.
--
-- EL VALOR DEL LIMITE ES PROVISIONAL Y ESTA PUESTO CORTO A PROPOSITO.
--
-- Dos kilometros, y no porque nadie lo haya medido: **faltan las coordenadas de
-- 34 de los 36 destinos rurales**. Cuando lleguen hay que medir la separacion
-- real entre ellos y poner el numero que digan los datos, igual que se hizo con
-- la tolerancia del poligono del municipio en la Fase 11. Si los puntos de una
-- misma via estan a seis kilometros unos de otros, dos deja fuera media region.
--
-- Mientras tanto, corto es el lado seguro: lo que no alcanza a pegarse no se
-- cobra barato, se rechaza. Es un UPDATE de una fila el dia que se afine, no una
-- migracion.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El limite
-- -----------------------------------------------------------------------------

insert into public.app_settings (key, value, description) values
  ('rural_snap_max_km', '2',
   'D226. PROVISIONAL. Radio para cobrar la tarifa del destino rural mas cercano. Medir con las coordenadas reales.');


-- -----------------------------------------------------------------------------
-- De donde salio el precio
-- -----------------------------------------------------------------------------

-- La segunda mitad de lo que se acordo: que se vea en que se basa el valor.
-- "Tarifa de Montanita - $15.000" en lugar de "$15.000" a secas.
--
-- Cuesta una columna y convierte un numero discutible en uno transparente: el
-- pasajero ve de donde sale ANTES de confirmar y el conductor ve lo mismo, asi
-- que si la aplicacion se equivoco de referencia se nota antes del viaje y no
-- despues, con el conductor y el pasajero discutiendo en la calle.
--
-- FUERA DE `rr_fare_all_or_nothing` a proposito: un viaje urbano tiene valor y
-- no tiene referencia, asi que meterla en ese grupo obligaria a inventarle una.
alter table public.ride_requests
  add column fare_reference text
    constraint rr_fare_reference_length check (
      fare_reference is null or length(trim(fare_reference)) between 1 and 120
    );

comment on column public.ride_requests.fare_reference is
  'Nombre del destino rural del que salio la tarifa. Nulo en los viajes urbanos.';

-- Una referencia sin tarifa rural no significa nada, y una tarifa rural sin
-- referencia esconde de donde salio el numero. Van juntas o no van.
alter table public.ride_requests
  add constraint rr_fare_reference_matches_rural check (
    fare_is_rural is null
    or (fare_is_rural and fare_reference is not null)
    or (not fare_is_rural and fare_reference is null)
  );


-- -----------------------------------------------------------------------------
-- quote_fare, con el punto mas cercano
-- -----------------------------------------------------------------------------

-- SE BORRA Y SE VUELVE A CREAR porque cambia el tipo de retorno, y eso
-- `create or replace` no lo admite. Al borrarla se pierden sus permisos, asi que
-- hay que volver a concederlos abajo. Mismo aviso que ya lleva `request_ride`
-- desde E30: quien la toque otra vez, que parta de la ULTIMA version aplicada.
drop function if exists public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  uuid, uuid[], smallint[], timestamptz
);

create function public.quote_fare(
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
  -- Nuevas. `reference` es el nombre que ve el pasajero; `reference_m` es a
  -- cuanto quedo, y sirve para que el panel pueda revisar despues si alguna
  -- referencia se esta usando demasiado lejos.
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

  -- La franja cruza la medianoche, asi que es una O y no una Y. Escrito de la
  -- otra forma no seria nunca cierto y el recargo no se aplicaria jamas.
  v_noche := case
    when v_inicio > v_fin then v_hora >= v_inicio or v_hora < v_fin
    else v_hora >= v_inicio and v_hora < v_fin
  end;

  v_destino := extensions.st_setsrid(
    extensions.st_makepoint(p_destination_lng, p_destination_lat), 4326
  )::extensions.geography;

  -- ------------------------------------------------------- la tarifa del viaje

  -- PRIMERO EL DESTINO EXACTO. Si el pasajero eligio Montanita de la lista, paga
  -- Montanita, sin buscar nada mas cerca. Un destino con precio propio no se
  -- redondea a otro.
  if p_destination_place_id is not null then
    select rf.amount, pl.name, 0
      into v_rural, v_ref, v_ref_m
    from public.rural_fares rf
      join public.places pl on pl.id = rf.place_id
    where rf.place_id = p_destination_place_id
      and rf.is_active;
  end if;

  -- Y SI NO, EL MAS CERCANO (D226). Vale para el punto medio entre dos destinos
  -- y para la chincheta que el pasajero solto al lado de uno.
  --
  -- Se aplica tambien cuando el destino SI es un lugar de la lista pero no tiene
  -- tarifa propia: cuanto cuesta llegar a un sitio no depende de si ese sitio
  -- esta o no en una tabla.
  if v_rural is null then
    v_limite := (public.get_setting('rural_snap_max_km', '2'))::double precision;

    select rf.amount,
           pl.name,
           round(extensions.st_distance(pl.location, v_destino))::integer
      into v_rural, v_ref, v_ref_m
    from public.rural_fares rf
      join public.places pl on pl.id = rf.place_id
    where rf.is_active
      and pl.is_active
      -- `st_dwithin` y no un `st_distance < x` en el WHERE: el primero usa el
      -- indice espacial de `places` y el segundo obliga a medir contra las 36
      -- filas. Con 36 da igual; el dia que la empresa tenga trescientos
      -- destinos, no.
      and extensions.st_dwithin(pl.location, v_destino, v_limite * 1000)
    order by extensions.st_distance(pl.location, v_destino)
    limit 1;
  end if;

  v_es_rural := v_rural is not null;

  if v_es_rural then
    -- Plana: no mira cuantos van ni que hora es (D222).
    v_viaje := v_rural;
    v_noche := false;
  else
    v_ref   := null;
    v_ref_m := null;

    -- D219. Solo para lo que NO viene de la lista de la empresa: un lugar de
    -- `places` sin tarifa rural cerca es urbano, aunque quede a 6 km.
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
  'Cuanto vale un servicio, con su desglose y de que destino rural salio la tarifa (D226).';

revoke all on function public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  uuid, uuid[], smallint[], timestamptz
) from public, anon;

grant execute on function public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  uuid, uuid[], smallint[], timestamptz
) to authenticated;
