-- =============================================================================
-- Bloque especial, paso 3: el calculo del valor
-- =============================================================================
--
-- Cierra el requisito 6 del encargo, la parte del servidor: determinar cuanto
-- vale un servicio. Ensenarselo al pasajero es la pantalla, y va despues.
--
-- EL CALCULO VIVE AQUI Y NO EN EL TELEFONO, por D83 y por algo mas concreto: el
-- recargo nocturno depende de la hora, y la hora del telefono la cambia
-- cualquiera desde los ajustes. Un pasajero podria pagar tarifa de dia a
-- medianoche adelantando el reloj. La hora que manda es la del servidor.
--
-- ESTA MIGRACION NO TOCA `request_ride`. Anade la funcion que calcula y las
-- columnas donde se guardara el resultado, nada mas. Enganchar las dos cosas es
-- el paso siguiente y va aparte a proposito: `request_ride` es la funcion mas
-- reescrita del proyecto y la que produjo E30. Mezclar una formula nueva sin
-- probar con la reescritura de esa funcion seria pedir el mismo error otra vez.
--
-- LA FORMULA, tal como quedo cerrada con el usuario el 2026-08-25 (D221, D222):
--
--   tarifa del viaje   rural  -> la fija del destino, PLANA, a cualquier hora
--                      urbana -> por cantidad de pasajeros, y de noche la
--                                nocturna SUSTITUYE a la diurna
--
--   valor              pasajero (con carga o sin ella) -> tarifa + cargas
--                      encomienda                      -> LA MAYOR de las dos
--
-- En la encomienda la tarifa base urbana es la de una persona, y **si paga el
-- recargo nocturno**: una encomienda urbana a medianoche vale 7.000 y no 4.000.
-- Confirmado por el usuario el 2026-08-25.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Parametros nuevos
-- -----------------------------------------------------------------------------

-- D219: un destino que no esta en la lista de la empresa y ademas queda lejos no
-- se puede cobrar, asi que no se deja pedir. Hace falta un centro desde el que
-- medir y una distancia.
--
-- EL CENTRO ES EL PARQUE, con las coordenadas de la tabla `places` y no las de
-- D122. **Es el hallazgo H17**: D122 documenta el parque en 6,9047 / -75,0767 y
-- la fila de `places` lo tiene en 6,907392 / -75,074987, a 353 metros. Se toma
-- la de `places` porque es la que usan las pruebas y la que el usuario verifico
-- en pantalla. Si H17 se resuelve al reves, se cambian estos dos numeros desde
-- el panel y ya esta: por eso son parametros y no constantes.
--
-- LOS 5 KM SON UN PUNTO DE PARTIDA, no una medida sagrada. Los 36 lugares de la
-- empresa estan casi todos a menos de 2 km, y el mas lejano, Vereda Guayabito,
-- a 6,3 km. **Ese no se ve afectado**: el umbral solo mira a los destinos que NO
-- vienen de la lista, y los de la lista los curo la empresa.
insert into public.app_settings (key, value, description) values
  ('fare_center_lng', '-75.074987',
   'Longitud desde la que se mide si un destino sin tarifa esta demasiado lejos.'),
  ('fare_center_lat', '6.907392',
   'Latitud del mismo punto. Es el parque segun places, ver hallazgo H17.'),
  ('unpriced_destination_max_km', '5',
   'D219. Un destino que no viene de la lista y esta mas lejos que esto no se puede cobrar.');


-- -----------------------------------------------------------------------------
-- Funcion: quote_fare
-- -----------------------------------------------------------------------------

-- Devuelve UNA fila con el desglose. La llama la pantalla del pasajero para
-- ensenar el valor antes de confirmar, y la llamara `request_ride` para
-- congelarlo. Que las dos usen la misma funcion es lo unico que garantiza que el
-- pasajero pague lo que vio: dos calculos separados se desincronizan el dia que
-- alguien toque uno.
--
-- SECURITY DEFINER, y no es por comodidad. `rural_fares` y `cargo_types` tienen
-- politica de solo activos, asi que un pasajero no puede ver una tarifa apagada;
-- pero el calculo si necesita distinguir "no existe" de "existe apagada" para
-- explicar el error. Ademas asi la funcion sigue valiendo cuando la llame el
-- panel con otro rol.
--
-- LA CARGA VIAJA EN DOS ARREGLOS EN PARALELO y no en un jsonb. Los tipos son
-- `uuid` y `smallint`, asi que un identificador mal formado o una cantidad con
-- coma rebotan en el borde de la funcion en vez de dentro, donde el error seria
-- mas dificil de explicar.
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
  total_amount integer
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_zona        text;
  v_inicio      integer;
  v_fin         integer;
  v_hora        integer;
  v_noche       boolean;
  v_rural       integer;
  v_es_rural    boolean;
  v_max         smallint;
  v_pc          smallint;
  v_viaje       integer;
  v_carga       integer := 0;
  v_total       integer;
  v_n           integer;
  v_km          double precision;
  v_limite      double precision;
begin
  -- ------------------------------------------------------------ los argumentos

  if p_service_type = 'parcel' then
    if p_passenger_count <> 0 then
      raise exception 'Una encomienda no lleva pasajeros'
        using errcode = 'P0001', hint = 'PARCEL_HAS_NO_PASSENGERS';
    end if;

    -- La regla que la migracion anterior dejo apuntada porque un CHECK no puede
    -- cruzar tablas. Sin carga declarada, el valor caeria a la tarifa base y
    -- saldria una encomienda de contenido desconocido cobrada como minima.
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

  -- Mismo criterio que la restriccion `rrc_one_line_per_type`: dos lineas del
  -- mismo tipo son una linea con cantidad dos. Se rechaza aqui tambien para que
  -- la vista previa no de un numero que luego `request_ride` no pueda guardar.
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

  -- Con el reloj de Amalfi, no con el del servidor ni con el del telefono.
  v_hora := extract(hour from (p_at at time zone v_zona));

  -- La franja cruza la medianoche, asi que es una O y no una Y. Escrito de la
  -- otra forma —hora >= 22 and hora < 5— no seria nunca cierto y el recargo no
  -- se aplicaria jamas, en silencio.
  v_noche := case
    when v_inicio > v_fin then v_hora >= v_inicio or v_hora < v_fin
    else v_hora >= v_inicio and v_hora < v_fin
  end;

  -- ------------------------------------------------------- la tarifa del viaje

  -- D218: ser rural es tener fila activa aqui. Ni poligono ni radio.
  select rf.amount into v_rural
  from public.rural_fares rf
  where rf.place_id = p_destination_place_id
    and rf.is_active;

  v_es_rural := v_rural is not null;

  if v_es_rural then
    -- Plana: no mira cuantos van ni que hora es (D222). Tres personas a
    -- Montanita pagan 15.000 entre todas.
    v_viaje := v_rural;
    v_noche := false;
  else
    -- D219. Solo para lo que NO viene de la lista de la empresa: un lugar de
    -- `places` sin tarifa rural es urbano y punto, aunque quede a 6 km.
    if p_destination_place_id is null then
      v_limite := (public.get_setting('unpriced_destination_max_km', '5'))::double precision;

      select extensions.st_distance(
               extensions.st_setsrid(extensions.st_makepoint(
                 (public.get_setting('fare_center_lng', '-75.074987'))::double precision,
                 (public.get_setting('fare_center_lat', '6.907392'))::double precision
               ), 4326)::extensions.geography,
               extensions.st_setsrid(extensions.st_makepoint(
                 p_destination_lng, p_destination_lat
               ), 4326)::extensions.geography
             ) / 1000.0
        into v_km;

      if v_km > v_limite then
        raise exception 'Ese destino no tiene tarifa. Elige uno de la lista'
          using errcode = 'P0001', hint = 'DESTINATION_NOT_PRICED';
      end if;
    end if;

    -- En la encomienda, la base urbana es la de una persona, y de noche es la
    -- nocturna de una persona.
    v_pc := case when p_service_type = 'parcel' then 1::smallint else p_passenger_count end;

    select uf.amount into v_viaje
    from public.urban_fares uf
    where uf.passenger_count = v_pc
      and uf.is_night = v_noche;

    -- NO SE INVENTA UN VALOR POR DEFECTO. Si alguien sube
    -- `max_passengers_per_request` sin anadir las filas, cobrar cero o cobrar lo
    -- de tres a cuatro seria un numero fabricado en la pantalla de un pasajero.
    -- Mejor un error que se entiende y se arregla en un minuto desde el panel.
    if v_viaje is null then
      raise exception 'No hay tarifa configurada para % pasajeros', v_pc
        using errcode = 'P0001', hint = 'URBAN_FARE_NOT_CONFIGURED';
    end if;
  end if;

  -- ------------------------------------------------------------------ la carga

  if array_length(p_cargo_type_ids, 1) is not null then
    -- `join` y no `left join` a proposito: si un tipo no existe o esta apagado,
    -- la cuenta sale distinta y se avisa abajo. Sumar solo los que existen
    -- devolveria un total mas barato sin decir nada.
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

  -- Las dos mitades de D221. La encomienda paga la mayor de las dos porque
  -- llevar un bulto de cafe cuesta lo que cuesta llevarlo, aunque el trayecto
  -- sea corto; y el pasajero con carga paga las dos cosas porque son dos cosas.
  v_total := case p_service_type
    when 'parcel' then greatest(v_viaje, v_carga)
    when 'passenger' then v_viaje + v_carga
  end;

  return query select v_es_rural, v_noche, v_viaje, v_carga, v_total;
end;
$$;

comment on function public.quote_fare is
  'Cuanto vale un servicio, con su desglose. La misma que usara request_ride, para que el pasajero pague lo que vio.';

revoke all on function public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  uuid, uuid[], smallint[], timestamptz
) from public, anon;

grant execute on function public.quote_fare(
  public.service_type, smallint, double precision, double precision,
  uuid, uuid[], smallint[], timestamptz
) to authenticated;


-- -----------------------------------------------------------------------------
-- Donde se guarda el valor
-- -----------------------------------------------------------------------------

-- Admiten nulo porque las 45 solicitudes anteriores a D217 no tienen valor y no
-- se les puede inventar uno: se pidieron cuando la aplicacion no cobraba. Un
-- cero ahi seria peor que un vacio, porque un cero parece un dato.
--
-- SE GUARDA EL DESGLOSE Y NO SOLO EL TOTAL. Con los precios cambiando desde el
-- panel, un total suelto no se puede volver a explicar: dentro de seis meses
-- nadie podria decir si aquellos 19.900 eran tarifa rural mas bulto de cafe o
-- tarifa urbana nocturna mas dos cajas. Son tres enteros y dos booleanos.
alter table public.ride_requests
  add column fare_amount integer
    constraint rr_fare_amount_range check (
      fare_amount is null or (fare_amount > 0 and fare_amount <= 10000000)
    ),
  add column fare_trip_amount integer
    constraint rr_fare_trip_range check (
      fare_trip_amount is null or (fare_trip_amount > 0 and fare_trip_amount <= 1000000)
    ),
  add column fare_cargo_amount integer
    constraint rr_fare_cargo_range check (
      fare_cargo_amount is null or (fare_cargo_amount >= 0 and fare_cargo_amount <= 10000000)
    ),
  add column fare_is_night boolean,
  add column fare_is_rural boolean;

comment on column public.ride_requests.fare_amount is
  'Lo que el pasajero vio antes de confirmar. La aplicacion NO cobra: cobra el conductor, en efectivo (D217).';
comment on column public.ride_requests.fare_trip_amount is
  'La parte del trayecto, sin la carga.';
comment on column public.ride_requests.fare_cargo_amount is
  'La suma de las cargas. Cero cuando no lleva.';

-- O estan las cinco o no esta ninguna. Media tarifa guardada es un dato que
-- miente a medias, y de esos no se recupera nadie leyendo el historial.
alter table public.ride_requests
  add constraint rr_fare_all_or_nothing check (
    num_nonnulls(fare_amount, fare_trip_amount, fare_cargo_amount,
                 fare_is_night, fare_is_rural) in (0, 5)
  );

-- LA FORMULA, GARANTIZADA POR LA BASE DE DATOS Y NO POR EL CODIGO.
--
-- Es la misma idea que el indice unico de las ofertas aceptadas de la Fase 5: la
-- regla deja de ser algo que hay que acordarse de cumplir. Si manana alguien
-- escribe un total que no cuadra con sus partes —desde una funcion nueva, desde
-- el panel, desde una correccion a mano—, la fila no entra.
alter table public.ride_requests
  add constraint rr_fare_matches_parts check (
    fare_amount is null
    or (service_type = 'parcel'
        and fare_amount = greatest(fare_trip_amount, fare_cargo_amount))
    or (service_type = 'passenger'
        and fare_amount = fare_trip_amount + fare_cargo_amount)
  );

-- Un destino rural no se cobra de noche mas caro (D222). Tambien queda escrito
-- en la estructura y no solo en el comentario de la funcion.
alter table public.ride_requests
  add constraint rr_fare_rural_is_never_night check (
    fare_is_rural is null or not (fare_is_rural and fare_is_night)
  );
