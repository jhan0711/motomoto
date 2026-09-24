-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `quote_fare` (paso 3, `20260826010000_fare_calculation.sql`, y su
-- correccion D233, `20260826090000_rural_fare_both_directions.sql`: la tarifa
-- rural cuenta en los dos sentidos).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_calculo_tarifa.sql
--
-- TODAS LAS COMPROBACIONES PASAN LA HORA A MANO, ninguna deja el valor por
-- defecto. Es deliberado: `quote_fare` mira el reloj, asi que una prueba que no
-- fije la hora pasaria por la tarde y fallaria a medianoche. Un archivo de
-- pruebas que depende de cuando se ejecuta no es una prueba.
--
-- LAS TARIFAS RURALES DE PRODUCCION NO SE TOCAN. Este archivo crea DOS LUGARES
-- DE PRUEBA con coordenadas elegidas a proposito y les pone los importes reales
-- de Montanita (15.000) y El Taparo (12.000). Lo que se prueba es la formula, no
-- el dato.
--
-- POR QUE LUGARES INVENTADOS Y NO DOS DE LOS QUE YA HAY. Se intento primero con
-- El hospital y El coliseo, y diecinueve comprobaciones se pusieron rojas de
-- golpe al entrar D226: esos dos estan a 431 y 467 metros del parque, y casi
-- todas las pruebas urbanas usan el parque como destino, asi que el parque se
-- pegaba a una tarifa rural y devolvia 15.000 donde tenia que devolver 4.000.
-- En la realidad ningun destino rural va a estar a cuatrocientos metros del
-- parque; el que fallaba ahi era el montaje de la prueba, no la funcion. Con los
-- dos lugares a 10 km, la geometria la decide este archivo y no el azar de donde
-- caen los lugares de Amalfi.
--
-- Y EL LIMITE DE D226/D230 SE FIJA AQUI DENTRO, sin leer el de produccion: ese
-- valor es provisional y va a cambiar cuando lleguen las coordenadas que faltan.
-- Una prueba que dependa de el se pondria roja el dia que se afine, sin que nada
-- este mal.
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
-- =============================================================================

begin;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- La formula
-- -----------------------------------------------------------------------------

do $formula$
declare
  -- El parque, que hace de "pueblo": origen o destino en la mayoria de las
  -- comprobaciones, porque la mayoria de los viajes reales tienen un extremo en
  -- el casco urbano.
  v_lng   double precision;
  v_lat   double precision;

  v_rural15 uuid;   -- lugar de prueba a 10 km, hace de Montanita, 15.000
  v_rural12 uuid;   -- lugar de prueba a 11,5 km, hace de El Taparo, 12.000
  v_r15_lng double precision;
  v_r15_lat double precision;
  v_r12_lng double precision;
  v_r12_lat double precision;

  v_guayab  uuid;   -- Vereda Guayabito, a 6,3 km del parque y SIN tarifa rural
  v_gl      double precision;
  v_gt      double precision;

  v_caja  uuid;     -- Caja pequena, 1.700
  v_cafe  uuid;     -- Bulto de cafe, 4.900
  v_bici  uuid;     -- Bicicleta, 2.300

  -- Un martes cualquiera. Las horas van con el desfase de Colombia escrito, para
  -- que se lea lo que significan sin tener que convertir mentalmente.
  c_dia   constant timestamptz := '2026-08-25 14:00:00-05';
  c_noche constant timestamptz := '2026-08-25 23:30:00-05';

  v_total integer;
  v_viaje integer;
  v_carga integer;
  v_rural boolean;
  v_noche boolean;
  v_ref   text;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';

  select id,
         extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_guayab, v_gl, v_gt
  from public.places where name = 'Vereda Guayabito';

  -- SE DESACTIVAN LAS TARIFAS RURALES REALES, DENTRO DE ESTA TRANSACCION.
  --
  -- Esta prueba se escribio cuando `rural_fares` estaba vacia, y daba por
  -- hecho que ningun destino real quedaba cerca del parque. Ese supuesto dejo
  -- de ser cierto en cuanto se cargaron los primeros destinos rurales de
  -- verdad: Alto del Rio esta a 1.432 m del parque, DENTRO del radio de D230,
  -- asi que "el parque" pasado como coordenada suelta -sin `place_id`, que es
  -- como casi todas las comprobaciones de aqui abajo lo usan- empezo a
  -- pegarsele a Alto del Rio y a devolver 10.800 en vez de 4.000.
  --
  -- La aplicacion real nunca comete este error: cuando el pasajero elige "El
  -- parque" de la lista, el `place_id` viaja siempre (`CreateRequestPoint`), y
  -- eso ya se comprobo con los datos reales fuera de este archivo, en
  -- `verificar_real.sql` de la sesion en que se cargaron. El error era de este
  -- archivo, que simulaba una eleccion de la lista con una coordenada suelta.
  --
  -- Se corrige de raiz para que la prueba no vuelva a romperse cada vez que se
  -- cargue una tarifa rural nueva: se apagan TODAS las reales, se rehidratan
  -- solo las dos sinteticas de aqui abajo, y como todo esto vive dentro de la
  -- transaccion que termina en `rollback`, la produccion no se entera.
  update public.rural_fares set is_active = false;

  -- El limite de D226/D230, fijado aqui y no leido de produccion.
  update public.app_settings set value = '2' where key = 'rural_snap_max_km';

  -- Los dos lugares de prueba, en la misma longitud que el parque y al norte:
  -- uno a 10 km y otro a 11,5. Un grado de latitud son 110,6 km, de ahi los
  -- numeros. `sort_order` alto para que no se cuelen en los `order by` de los
  -- otros bloques, que eligen el primero de la lista.
  insert into public.places (name, location, sort_order) values
    ('Zz prueba rural cercana',
     extensions.st_setsrid(extensions.st_makepoint(-75.074987, 6.997792), 4326)::extensions.geography,
     999),
    ('Zz prueba rural lejana',
     extensions.st_setsrid(extensions.st_makepoint(-75.074987, 7.011352), 4326)::extensions.geography,
     999);

  select id, extensions.st_x(location::extensions.geometry), extensions.st_y(location::extensions.geometry)
    into v_rural15, v_r15_lng, v_r15_lat
  from public.places where name = 'Zz prueba rural cercana';
  select id, extensions.st_x(location::extensions.geometry), extensions.st_y(location::extensions.geometry)
    into v_rural12, v_r12_lng, v_r12_lat
  from public.places where name = 'Zz prueba rural lejana';

  insert into public.rural_fares (place_id, amount) values
    (v_rural15, 15000), (v_rural12, 12000);

  select id into v_caja from public.cargo_types where name = 'Caja pequeña';
  select id into v_cafe from public.cargo_types where name = 'Bulto de café';
  select id into v_bici from public.cargo_types where name = 'Bicicleta';

  -- ------------------------------------------------------------- urbana de dia

  select total_amount into v_total from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}', c_dia);
  insert into resultados values (1, 'Urbano, 1 persona, de dia',
    '4000', v_total::text, v_total = 4000);

  select total_amount into v_total from public.quote_fare(
    'passenger', 2::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}', c_dia);
  insert into resultados values (2, 'Urbano, 2 personas, de dia',
    '6200', v_total::text, v_total = 6200);

  select total_amount into v_total from public.quote_fare(
    'passenger', 3::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}', c_dia);
  insert into resultados values (3, 'Urbano, 3 personas, de dia',
    '8500', v_total::text, v_total = 8500);

  -- ----------------------------------------------------------- urbana de noche

  -- SUSTITUYE, NO SE SUMA (D222). Si alguien lo cambiara a suma, aqui saldria
  -- 11.000 y la comprobacion lo diria.
  select total_amount into v_total from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}', c_noche);
  insert into resultados values (4, 'Urbano, 1 persona, de noche: sustituye, no suma',
    '7000', v_total::text, v_total = 7000);

  select total_amount into v_total from public.quote_fare(
    'passenger', 2::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}', c_noche);
  insert into resultados values (5, 'Urbano, 2 personas, de noche',
    '12000', v_total::text, v_total = 12000);

  select total_amount into v_total from public.quote_fare(
    'passenger', 3::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}', c_noche);
  insert into resultados values (6, 'Urbano, 3 personas, de noche',
    '17000', v_total::text, v_total = 17000);

  -- ------------------------------------------------------------------- rurales

  -- EL EJEMPLO QUE DIO LA EMPRESA CON SUS PALABRAS: tres personas a Montanita
  -- pagan 15.000 entre todas, no 15.000 cada una. Parque -> rural.
  select total_amount, is_rural into v_total, v_rural from public.quote_fare(
    'passenger', 3::smallint, v_lng, v_lat, v_r15_lng, v_r15_lat, null, v_rural15, '{}', '{}', c_dia);
  insert into resultados values (7, 'Rural, 3 personas: se cobra plana, no por cabeza',
    '15000 y rural', v_total::text || ' y ' || case when v_rural then 'rural' else 'urbano' end,
    v_total = 15000 and v_rural);

  select total_amount, is_night into v_total, v_noche from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_r15_lng, v_r15_lat, null, v_rural15, '{}', '{}', c_noche);
  insert into resultados values (8, 'Rural de noche cuesta lo mismo (D222)',
    '15000 y sin recargo', v_total::text || ' y ' ||
      case when v_noche then 'CON recargo' else 'sin recargo' end,
    v_total = 15000 and not v_noche);

  -- D233: EL MISMO VIAJE AL REVES, RURAL -> PARQUE, cuesta lo mismo. Es la
  -- comprobacion que hizo falta cuando el usuario probo la aplicacion de
  -- verdad: antes de esta correccion, esto daba 4.000 en vez de 15.000, porque
  -- solo se miraba el destino.
  select total_amount, is_rural, reference into v_total, v_rural, v_ref
  from public.quote_fare(
    'passenger', 1::smallint, v_r15_lng, v_r15_lat, v_lng, v_lat, v_rural15, null, '{}', '{}', c_dia);
  insert into resultados values (9, 'D233: el mismo viaje al reves cuesta lo mismo',
    '15000 y rural, por el cercano',
    v_total::text || ' y ' || case when v_rural then 'rural' else 'urbano' end ||
      ', por ' || coalesce(v_ref, 'nada'),
    v_total = 15000 and v_rural and v_ref = 'Zz prueba rural cercana');

  -- Y el ejemplo de la empresa, tambien al reves: de Montanita al parque con
  -- tres personas siguen siendo 15.000 entre todas, no por cabeza.
  select total_amount into v_total from public.quote_fare(
    'passenger', 3::smallint, v_r15_lng, v_r15_lat, v_lng, v_lat, v_rural15, null, '{}', '{}', c_dia);
  insert into resultados values (10, 'D233: tres personas de vuelta del rural, tambien plana',
    '15000', v_total::text, v_total = 15000);

  -- D233, EL CASO QUE NO TIENE TARIFA DE LA EMPRESA: entre dos rurales
  -- distintos gana el mas caro. 15.000 contra 12.000, gana 15.000.
  select total_amount, reference into v_total, v_ref
  from public.quote_fare(
    'passenger', 1::smallint, v_r15_lng, v_r15_lat, v_r12_lng, v_r12_lat, v_rural15, v_rural12, '{}', '{}', c_dia);
  insert into resultados values (11, 'D233: entre dos rurales distintos, gana el mas caro',
    '15000 por el cercano',
    v_total::text || ' por ' || coalesce(v_ref, 'nada'),
    v_total = 15000 and v_ref = 'Zz prueba rural cercana');

  -- --------------------------------------------------------- pasajero + carga

  select total_amount into v_total from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
    array[v_bici], array[1::smallint], c_dia);
  insert into resultados values (12, 'Urbano, 1 persona + bicicleta: 4.000 + 2.300',
    '6300', v_total::text, v_total = 6300);

  select total_amount into v_total from public.quote_fare(
    'passenger', 3::smallint, v_lng, v_lat, v_r15_lng, v_r15_lat, null, v_rural15,
    array[v_cafe], array[1::smallint], c_dia);
  insert into resultados values (13, 'Rural 15.000, 3 personas + bulto de cafe',
    '19900', v_total::text, v_total = 19900);

  select total_amount into v_total from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
    array[v_caja, v_bici], array[2::smallint, 1::smallint], c_dia);
  insert into resultados values (14, 'Urbano, 1 persona + 2 cajas + bicicleta',
    '9700', v_total::text, v_total = 9700);

  -- ---------------------------------------------------------------- encomienda

  -- LA MAYOR DE LAS DOS. Aqui gana la tarifa.
  select total_amount, trip_amount, cargo_amount into v_total, v_viaje, v_carga
  from public.quote_fare('parcel', 0::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
    array[v_caja], array[1::smallint], c_dia);
  insert into resultados values (15, 'Encomienda urbana, caja pequena: gana la tarifa',
    '4000 (viaje 4000, carga 1700)',
    v_total::text || ' (viaje ' || v_viaje || ', carga ' || v_carga || ')',
    v_total = 4000 and v_viaje = 4000 and v_carga = 1700);

  -- Y aqui gana la carga.
  select total_amount, trip_amount, cargo_amount into v_total, v_viaje, v_carga
  from public.quote_fare('parcel', 0::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
    array[v_cafe], array[1::smallint], c_dia);
  insert into resultados values (16, 'Encomienda urbana, bulto de cafe: gana la carga',
    '4900 (viaje 4000, carga 4900)',
    v_total::text || ' (viaje ' || v_viaje || ', carga ' || v_carga || ')',
    v_total = 4900 and v_viaje = 4000 and v_carga = 4900);

  -- EL EJEMPLO EXACTO DEL USUARIO EL 2026-08-26: tres bultos de cafe a un
  -- rural de 12.000 cuestan 14.700 -3 x 4.900-, no los 12.000 de la carrera.
  select total_amount, trip_amount, cargo_amount into v_total, v_viaje, v_carga
  from public.quote_fare('parcel', 0::smallint, v_lng, v_lat, v_r12_lng, v_r12_lat, null, v_rural12,
    array[v_cafe], array[3::smallint], c_dia);
  insert into resultados values (17, 'Tres bultos de cafe a un rural de 12.000: ganan los bultos',
    '14700 (viaje 12000, carga 14700)',
    v_total::text || ' (viaje ' || v_viaje || ', carga ' || v_carga || ')',
    v_total = 14700 and v_viaje = 12000 and v_carga = 14700);

  -- LO QUE EL USUARIO CONFIRMO EL 2026-08-25: la encomienda urbana SI paga el
  -- recargo nocturno. Su base pasa a 7.000, que ya le gana al bulto de cafe.
  select total_amount, trip_amount into v_total, v_viaje
  from public.quote_fare('parcel', 0::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
    array[v_cafe], array[1::smallint], c_noche);
  insert into resultados values (18, 'Encomienda urbana de noche: la base sube a 7.000',
    '7000', v_total::text, v_total = 7000 and v_viaje = 7000);

  select total_amount into v_total from public.quote_fare(
    'parcel', 0::smallint, v_lng, v_lat, v_r12_lng, v_r12_lat, null, v_rural12,
    array[v_bici], array[1::smallint], c_dia);
  insert into resultados values (19, 'Encomienda rural 12.000 con bicicleta: gana la tarifa',
    '12000', v_total::text, v_total = 12000);

  -- Varias cargas distintas en una encomienda: 1.700 x 2 + 4.900 = 8.300, que ya
  -- le gana a los 4.000 de la tarifa.
  select total_amount into v_total from public.quote_fare(
    'parcel', 0::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
    array[v_caja, v_cafe], array[2::smallint, 1::smallint], c_dia);
  insert into resultados values (20, 'Encomienda con dos tipos de carga: 3.400 + 4.900',
    '8300', v_total::text, v_total = 8300);

  -- Encomienda saliendo de un rural HACIA el parque: mismo criterio de D233,
  -- probado tambien con carga.
  select total_amount, trip_amount into v_total, v_viaje
  from public.quote_fare('parcel', 0::smallint, v_r15_lng, v_r15_lat, v_lng, v_lat, v_rural15, null,
    array[v_caja], array[1::smallint], c_dia);
  insert into resultados values (21, 'D233: encomienda desde un rural hacia el parque',
    '15000 (viaje 15000, gana la tarifa)', v_total::text || ' (viaje ' || v_viaje || ')',
    v_total = 15000 and v_viaje = 15000);

  -- --------------------------------------------------- los bordes de la noche

  -- LOS CUATRO BORDES, y son los que de verdad protegen la franja. Un `>` donde
  -- va un `>=` desplaza el recargo una hora entera sin que nada mas se note.
  select is_night into v_noche from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}',
    '2026-08-25 21:59:00-05');
  insert into resultados values (22, 'A las 21:59 todavia es de dia',
    'dia', case when v_noche then 'noche' else 'dia' end, not v_noche);

  select is_night into v_noche from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}',
    '2026-08-25 22:00:00-05');
  insert into resultados values (23, 'A las 22:00 en punto ya es de noche',
    'noche', case when v_noche then 'noche' else 'dia' end, v_noche);

  select is_night into v_noche from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}',
    '2026-08-26 04:59:00-05');
  insert into resultados values (24, 'A las 04:59 sigue siendo de noche',
    'noche', case when v_noche then 'noche' else 'dia' end, v_noche);

  select is_night into v_noche from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}',
    '2026-08-26 05:00:00-05');
  insert into resultados values (25, 'A las 05:00 en punto ya es de dia',
    'dia', case when v_noche then 'noche' else 'dia' end, not v_noche);

  -- LA MISMA HORA ESCRITA EN UTC. Si alguien quitara la conversion de zona, las
  -- cuatro de arriba podrian seguir en verde y esta se pondria roja: las 03:00
  -- UTC son las 22:00 en Amalfi.
  select is_night into v_noche from public.quote_fare(
    'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null, '{}', '{}',
    '2026-08-26 03:00:00+00');
  insert into resultados values (26, 'Las 03:00 UTC son las 22:00 en Amalfi: noche',
    'noche', case when v_noche then 'noche' else 'dia' end, v_noche);

  -- ------------------------------------------------------------ D219, los km

  -- Vereda Guayabito esta a 6,3 km y NO tiene tarifa rural. Como viene de la
  -- lista de la empresa, tiene que cobrarse como urbano y no rebotar. Es el caso
  -- que habria roto la aplicacion si el umbral se hubiera aplicado a todo.
  begin
    select total_amount into v_total from public.quote_fare(
      'passenger', 1::smallint, v_lng, v_lat, v_gl, v_gt, null, v_guayab, '{}', '{}', c_dia);
    insert into resultados values (27,
      'Un lugar de la lista a 6,3 km sin tarifa rural se cobra urbano',
      '4000', v_total::text, v_total = 4000);
  exception when others then
    insert into resultados values (27,
      'Un lugar de la lista a 6,3 km sin tarifa rural se cobra urbano',
      '4000', 'LO RECHAZO ' || sqlstate, false);
  end;
end
$formula$;


-- -----------------------------------------------------------------------------
-- Lo que tiene que rechazar
-- -----------------------------------------------------------------------------

do $errores$
declare
  v_lng  double precision;
  v_lat  double precision;
  v_caja uuid;
  v_bici uuid;
  v_n    integer;
  v_h    text;

  c_dia constant timestamptz := '2026-08-25 14:00:00-05';
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';

  select id into v_caja from public.cargo_types where name = 'Caja pequeña';
  select id into v_bici from public.cargo_types where name = 'Bicicleta';

  begin
    perform public.quote_fare('parcel', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array[v_caja], array[1::smallint], c_dia);
    insert into resultados values (28, 'Encomienda con pasajeros',
      'PARCEL_HAS_NO_PASSENGERS', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (28, 'Encomienda con pasajeros',
      'PARCEL_HAS_NO_PASSENGERS', v_h, v_h = 'PARCEL_HAS_NO_PASSENGERS');
  end;

  -- La regla que un CHECK no podia cruzar. Sin carga, el valor caeria a la
  -- tarifa base y saldria una encomienda de contenido desconocido.
  begin
    perform public.quote_fare('parcel', 0::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      '{}', '{}', c_dia);
    insert into resultados values (29, 'Encomienda sin ninguna carga declarada',
      'PARCEL_NEEDS_CARGO', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (29, 'Encomienda sin ninguna carga declarada',
      'PARCEL_NEEDS_CARGO', v_h, v_h = 'PARCEL_NEEDS_CARGO');
  end;

  begin
    perform public.quote_fare('passenger', 0::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      '{}', '{}', c_dia);
    insert into resultados values (30, 'Viaje de pasajeros con cero personas',
      'PASSENGER_COUNT_OUT_OF_RANGE', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (30, 'Viaje de pasajeros con cero personas',
      'PASSENGER_COUNT_OUT_OF_RANGE', v_h, v_h = 'PASSENGER_COUNT_OUT_OF_RANGE');
  end;

  begin
    perform public.quote_fare('passenger', 4::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      '{}', '{}', c_dia);
    insert into resultados values (31, 'Cuatro pasajeros, por encima de R11',
      'PASSENGER_COUNT_OUT_OF_RANGE', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (31, 'Cuatro pasajeros, por encima de R11',
      'PASSENGER_COUNT_OUT_OF_RANGE', v_h, v_h = 'PASSENGER_COUNT_OUT_OF_RANGE');
  end;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array[v_caja, v_bici], array[1::smallint], c_dia);
    insert into resultados values (32, 'Dos cargas y una sola cantidad',
      'CARGO_ARRAYS_MISMATCH', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (32, 'Dos cargas y una sola cantidad',
      'CARGO_ARRAYS_MISMATCH', v_h, v_h = 'CARGO_ARRAYS_MISMATCH');
  end;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array[v_caja, v_caja], array[1::smallint, 1::smallint], c_dia);
    insert into resultados values (33, 'El mismo tipo de carga dos veces',
      'CARGO_TYPE_REPEATED', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (33, 'El mismo tipo de carga dos veces',
      'CARGO_TYPE_REPEATED', v_h, v_h = 'CARGO_TYPE_REPEATED');
  end;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array['00000000-0000-4000-8000-000000000000'::uuid], array[1::smallint], c_dia);
    insert into resultados values (34, 'Una carga de un tipo que no existe',
      'CARGO_TYPE_NOT_AVAILABLE', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (34, 'Una carga de un tipo que no existe',
      'CARGO_TYPE_NOT_AVAILABLE', v_h, v_h = 'CARGO_TYPE_NOT_AVAILABLE');
  end;

  -- Un tipo apagado desde el panel no se puede seguir cobrando. Sumarlo igual
  -- seria cobrar por algo que la empresa retiro; ignorarlo en silencio seria
  -- devolver un total mas barato sin avisar.
  update public.cargo_types set is_active = false where id = v_bici;
  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array[v_bici], array[1::smallint], c_dia);
    insert into resultados values (35, 'Una carga de un tipo apagado',
      'CARGO_TYPE_NOT_AVAILABLE', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (35, 'Una carga de un tipo apagado',
      'CARGO_TYPE_NOT_AVAILABLE', v_h, v_h = 'CARGO_TYPE_NOT_AVAILABLE');
  end;
  update public.cargo_types set is_active = true where id = v_bici;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array[v_caja], array[0::smallint], c_dia);
    insert into resultados values (36, 'Una carga con cantidad cero',
      'CARGO_QUANTITY_OUT_OF_RANGE', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (36, 'Una carga con cantidad cero',
      'CARGO_QUANTITY_OUT_OF_RANGE', v_h, v_h = 'CARGO_QUANTITY_OUT_OF_RANGE');
  end;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      array[v_caja], array[21::smallint], c_dia);
    insert into resultados values (37, 'Una carga con cantidad 21',
      'CARGO_QUANTITY_OUT_OF_RANGE', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (37, 'Una carga con cantidad 21',
      'CARGO_QUANTITY_OUT_OF_RANGE', v_h, v_h = 'CARGO_QUANTITY_OUT_OF_RANGE');
  end;

  -- D219. Una chincheta lejos, sin lugar de la lista detras, COMO DESTINO. Es
  -- el caso que habria ensenado 4.000 por un viaje que la empresa cobra a
  -- 30.000.
  --
  -- Se elige un punto a unos 20 km al norte del parque, dentro del municipio
  -- —Amalfi mide 1206 km2— para que lo que rechace sea D219 y no la zona de
  -- servicio, que es otra cosa y esta en `request_ride`.
  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat + 0.18, null, null,
      '{}', '{}', c_dia);
    insert into resultados values (38, 'Chincheta a 20 km sin tarifa, como destino: no se puede cobrar',
      'DESTINATION_NOT_PRICED', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (38, 'Chincheta a 20 km sin tarifa, como destino: no se puede cobrar',
      'DESTINATION_NOT_PRICED', v_h, v_h = 'DESTINATION_NOT_PRICED');
  end;

  -- D233: LO MISMO, PERO COMO ORIGEN. Antes de esta correccion el origen no se
  -- miraba en absoluto, asi que esta chincheta se habria cobrado urbano sin
  -- avisar. El codigo es distinto -ORIGIN_NOT_PRICED- para que el mensaje no le
  -- diga "el destino" a quien penso en el punto de recogida.
  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat + 0.18, v_lng, v_lat, null, null,
      '{}', '{}', c_dia);
    insert into resultados values (39, 'Chincheta a 20 km sin tarifa, como origen: no se puede cobrar',
      'ORIGIN_NOT_PRICED', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (39, 'Chincheta a 20 km sin tarifa, como origen: no se puede cobrar',
      'ORIGIN_NOT_PRICED', v_h, v_h = 'ORIGIN_NOT_PRICED');
  end;

  -- Y una cerca si vale: el umbral no puede estorbar al caso normal. A 1,1 km
  -- del parque, y lejos de los dos lugares rurales de prueba (a 10 km), asi
  -- que lo unico que se mide aqui es el umbral de D219.
  begin
    select total_amount into v_n from public.quote_fare(
      'passenger', 1::smallint, v_lng, v_lat, v_lng, v_lat + 0.01, null, null, '{}', '{}', c_dia);
    insert into resultados values (40, 'Chincheta a 1 km sin tarifa: se cobra urbano',
      '4000', v_n::text, v_n = 4000);
  exception when others then
    insert into resultados values (40, 'Chincheta a 1 km sin tarifa: se cobra urbano',
      '4000', 'LO RECHAZO ' || sqlstate, false);
  end;

  -- Sin la rejilla completa no se inventa un numero: se avisa.
  delete from public.urban_fares where passenger_count = 2 and not is_night;
  begin
    perform public.quote_fare('passenger', 2::smallint, v_lng, v_lat, v_lng, v_lat, null, null,
      '{}', '{}', c_dia);
    insert into resultados values (41, 'Sin tarifa configurada NO se inventa un valor',
      'URBAN_FARE_NOT_CONFIGURED', 'DEVOLVIO UN NUMERO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (41, 'Sin tarifa configurada NO se inventa un valor',
      'URBAN_FARE_NOT_CONFIGURED', v_h, v_h = 'URBAN_FARE_NOT_CONFIGURED');
  end;
end
$errores$;


-- -----------------------------------------------------------------------------
-- Las restricciones de las columnas de valor
-- -----------------------------------------------------------------------------

do $columnas$
declare
  v_pas uuid;
  v_org extensions.geography;
  v_dst extensions.geography;

begin
  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;

  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  select location into v_org from public.places order by sort_order, name limit 1;
  select location into v_dst from public.places order by sort_order desc, name limit 1;

  -- 42. Un total distinto de la suma de sus partes, en viaje de pasajeros.
  --
  --     D277: antes se rechazaba (`rr_fare_matches_parts`). Ahora ENTRA, a
  --     proposito: el pasajero propone el valor, `fare_amount` es lo acordado y
  --     el desglose es el de la tarifa oficial de referencia. Aqui 9.999 es la
  --     oferta sobre una oficial de 4.000 + 2.300. Los limites de la oferta los
  --     pone `request_ride` y los prueba `prueba_oferta_precio.sql`.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      9999, 4000, 2300, false, false
    );
    insert into resultados values (42, 'Total distinto de sus partes (oferta, D277) entra',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (42, 'Total distinto de sus partes (oferta, D277) entra',
      'entra', 'LO RECHAZO ' || sqlstate, false);
  end;

  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  -- 43. El que si cuadra entra: 4.000 + 2.300.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      6300, 4000, 2300, false, false
    );
    insert into resultados values (43, 'Total que si cuadra: 4.000 + 2.300',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (43, 'Total que si cuadra: 4.000 + 2.300',
      'entra', 'LO RECHAZO ' || sqlstate, false);
  end;

  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  -- 44. En la encomienda el desglose de referencia es la mayor, no la suma; y
  --     desde D277 el total guardado puede apartarse de el (la oferta). 8.900
  --     sobre 4.000 y 4.900 entra.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count, parcel_description,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_pas, 'parcel', 0, 'Bulto de cafe',
      v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      8900, 4000, 4900, false, false
    );
    insert into resultados values (44, 'Encomienda con total distinto de la mayor (oferta, D277) entra',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (44, 'Encomienda con total distinto de la mayor (oferta, D277) entra',
      'entra', 'LO RECHAZO ' || sqlstate, false);
  end;

  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  -- 45. Media tarifa guardada.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      6300, 4000
    );
    insert into resultados values (45, 'Guardar solo dos de las cinco columnas de valor',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (45, 'Guardar solo dos de las cinco columnas de valor',
      'rechaza', sqlstate, true);
  end;

  -- 46. Un rural con recargo nocturno no existe (D222).
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      15000, 15000, 0, true, true
    );
    insert into resultados values (46, 'Un destino rural marcado ademas como nocturno',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (46, 'Un destino rural marcado ademas como nocturno',
      'rechaza', sqlstate, true);
  end;

  -- 47. Y una solicitud sin valor sigue entrando: son las de antes de D217.
  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (47, 'Una solicitud sin valor sigue siendo valida',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (47, 'Una solicitud sin valor sigue siendo valida',
      'entra', 'LA RECHAZO ' || sqlstate, false);
  end;
end
$columnas$;


-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------

do $permisos2$
declare
  v_ok boolean;
  v_firma constant text := 'public.quote_fare(' ||
    'public.service_type,smallint,double precision,double precision,' ||
    'double precision,double precision,uuid,uuid,uuid[],smallint[],timestamptz)';
begin
  select has_function_privilege('anon', v_firma, 'execute') into v_ok;
  insert into resultados values (48, 'Sin sesion no se puede consultar una tarifa',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('authenticated', v_firma, 'execute') into v_ok;
  insert into resultados values (49, 'El pasajero SI puede consultar una tarifa',
    'true', v_ok::text, v_ok = true);
end
$permisos2$;


-- -----------------------------------------------------------------------------
-- D230: la tarifa del punto nombrado mas cercano
-- -----------------------------------------------------------------------------

-- LA GEOMETRIA DE ESTAS PRUEBAS LA FIJA ESTE ARCHIVO, no los lugares de Amalfi.
-- Los dos destinos rurales de prueba estan en la misma longitud que el parque,
-- al norte, a 10 y a 11,5 km: separados 1,5 km entre si y lejisimos de todo lo
-- demas. Eso da lo que hace falta: dos destinos lo bastante juntos como para
-- disputarse un punto intermedio, y ningun otro lugar dentro del limite.
--
-- Los puntos intermedios se calculan interpolando sobre la recta que los une,
-- asi que "cual esta mas cerca" lo decide la construccion y no la funcion que se
-- esta probando. Una prueba que calcula su respuesta esperada igual que el
-- codigo probado no prueba nada.
--
-- TODAS ESTAS COMPROBACIONES USAN EL PUNTO MEDIO COMO DESTINO Y EL PARQUE COMO
-- ORIGEN, para que lo unico que varie sea lo que se esta probando -D230- y no
-- se mezcle con D233, que ya tiene su propio bloque arriba.
do $cercano$
declare
  v_cerca  uuid;
  v_lejos  uuid;
  v_hosp   uuid;
  v_lng    double precision;
  v_lat    double precision;
  v_pa     extensions.geometry;
  v_pb     extensions.geometry;
  v_ph     extensions.geometry;
  v_punto  extensions.geometry;
  v_caja   uuid;

  v_centro  extensions.geography;
  v_vecino  extensions.geography;
  v_vec_id  uuid;

  c_dia constant timestamptz := '2026-08-25 14:00:00-05';

  v_total integer;
  v_rural boolean;
  v_ref   text;
  v_refm  integer;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';

  -- Las tarifas rurales de prueba y los dos lugares ya los creo el bloque de la
  -- formula, mas arriba y en esta misma transaccion. Aqui solo se usan.
  select id, location::extensions.geometry into v_cerca, v_pa
  from public.places where name = 'Zz prueba rural cercana';
  select id, location::extensions.geometry into v_lejos, v_pb
  from public.places where name = 'Zz prueba rural lejana';
  select id, location::extensions.geometry into v_hosp, v_ph
  from public.places where name = 'El hospital';
  select id into v_caja from public.cargo_types where name = 'Caja pequeña';

  -- 50. A la cuarta parte del camino: a unos 375 m del de 15.000 y a 1.125 m del
  --     de 12.000, asi que tiene que cobrar 15.000.
  v_punto := extensions.st_lineinterpolatepoint(
    extensions.st_makeline(v_pa, v_pb), 0.25);

  select total_amount, is_rural, reference, reference_m
    into v_total, v_rural, v_ref, v_refm
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_punto), extensions.st_y(v_punto), null, null, '{}', '{}', c_dia);

  insert into resultados values (50, 'Punto medio, mas cerca del de 15.000: cobra 15.000',
    '15000 por el cercano',
    coalesce(v_total::text, 'nulo') || ' por ' || coalesce(v_ref, 'nada'),
    v_total = 15000 and v_rural and v_ref = 'Zz prueba rural cercana');

  insert into resultados values (51, 'Y dice a que distancia quedo la referencia',
    'entre 300 y 450 m', coalesce(v_refm::text, 'nulo') || ' m',
    v_refm between 300 and 450);

  -- 52. LA MISMA RECTA, AL OTRO LADO. Aqui gana el de 12.000. Es la que de
  --     verdad prueba "el mas cercano": sin ella, la 50 podria estar en verde
  --     porque la funcion elige siempre la primera fila que encuentra.
  v_punto := extensions.st_lineinterpolatepoint(
    extensions.st_makeline(v_pa, v_pb), 0.75);

  select total_amount, reference into v_total, v_ref
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_punto), extensions.st_y(v_punto), null, null, '{}', '{}', c_dia);

  insert into resultados values (52, 'El mismo tramo del otro lado: gana el de 12.000',
    '12000 por el lejano',
    coalesce(v_total::text, 'nulo') || ' por ' || coalesce(v_ref, 'nada'),
    v_total = 12000 and v_ref = 'Zz prueba rural lejana');

  -- 53. EL DESTINO EXACTO NO SE REDONDEA. Se elige el de 12.000 de la lista
  --     teniendo el de 15.000 a 1,5 km. Paga el suyo.
  select total_amount, reference, reference_m into v_total, v_ref, v_refm
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_pb), extensions.st_y(v_pb), null, v_lejos, '{}', '{}', c_dia);

  insert into resultados values (53, 'Un destino con precio propio no se redondea a otro',
    '12000 por el lejano, a 0 m',
    coalesce(v_total::text, 'nulo') || ' por ' || coalesce(v_ref, 'nada') ||
      ', a ' || coalesce(v_refm::text, 'nulo') || ' m',
    v_total = 12000 and v_ref = 'Zz prueba rural lejana' and v_refm = 0);

  -- 54. FUERA DEL LIMITE NO SE PEGA. El hospital esta en la lista, no tiene
  --     tarifa rural y queda a 10 km de los dos destinos de prueba. Sigue siendo
  --     urbano, o sea que D230 no cambia lo que ya funcionaba.
  select total_amount, is_rural, reference into v_total, v_rural, v_ref
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_ph), extensions.st_y(v_ph), null, v_hosp, '{}', '{}', c_dia);

  insert into resultados values (54, 'Un lugar lejos de todo rural sigue siendo urbano',
    '4000 y sin referencia',
    coalesce(v_total::text, 'nulo') || ' y ' || coalesce(v_ref, 'sin referencia'),
    v_total = 4000 and not v_rural and v_ref is null);

  -- 55. Un urbano normal tampoco trae referencia.
  select reference into v_ref
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_ph), extensions.st_y(v_ph), null, null, '{}', '{}', c_dia);
  insert into resultados values (55, 'El viaje urbano no trae referencia de tarifa',
    'nulo', coalesce(v_ref, 'nulo'), v_ref is null);

  -- 56. Y el punto pegado suma la carga como cualquier rural: 15.000 + 1.700.
  v_punto := extensions.st_lineinterpolatepoint(
    extensions.st_makeline(v_pa, v_pb), 0.25);

  select total_amount into v_total
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_punto), extensions.st_y(v_punto), null, null,
    array[v_caja], array[1::smallint], c_dia);
  insert into resultados values (56, 'El punto pegado suma la carga como cualquier rural',
    '16700', coalesce(v_total::text, 'nulo'), v_total = 16700);

  -- 62. D234: "TU UBICACION ACTUAL" JUNTO AL PUEBLO NO SE PEGA A UN RURAL
  --     VECINO. Reproduce el error que reporto el usuario probando en la
  --     tablet y en el emulador: un punto sin `place_id` -exactamente lo que
  --     manda "Tu ubicacion actual"- en las coordenadas del parque mismo, con
  --     un lugar rural de prueba a solo 1,5 km (dentro del radio de 2 km de
  --     esta prueba). Antes de D234, `rural_fare_for_point` buscaba el rural
  --     mas cercano SIN comparar contra los urbanos, y este punto se pegaba a
  --     los 9.500 del vecino aunque el parque mismo -urbano, a 0 m- fuera mucho
  --     mas cercano. Con D234 vuelve a ganar el punto nombrado mas cercano de
  --     TODOS, y aqui el mas cercano es el parque: 4.000, urbano.
  v_centro := extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography;
  v_vecino := extensions.st_project(v_centro, 1500, radians(0));

  insert into public.places (name, location, sort_order) values
    ('Zz prueba rural del pueblo', v_vecino, 999);
  select id into v_vec_id from public.places where name = 'Zz prueba rural del pueblo';
  insert into public.rural_fares (place_id, amount) values (v_vec_id, 9500);

  select total_amount, is_rural, reference into v_total, v_rural, v_ref
  from public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
    extensions.st_x(v_ph), extensions.st_y(v_ph), null, v_hosp, '{}', '{}', c_dia);

  insert into resultados values (62,
    'D234: la ubicacion actual junto al pueblo no se pega a un rural vecino a 1,5 km',
    '4000 y sin referencia',
    coalesce(v_total::text, 'nulo') || ' y ' || coalesce(v_ref, 'sin referencia'),
    v_total = 4000 and not v_rural and v_ref is null);

  -- 57. D234 CORRIGE OTRA VEZ LA EXPECTATIVA DE ESTA COMPROBACION -esta si es
  --     la segunda vez, y esta si la causa D234-. D230 dice "gana el punto
  --     nombrado mas cercano, urbano o rural", sin condicion de que tenga
  --     tarifa activa: si el mas cercano se queda sin tarifa, ESO es "urbano"
  --     desde su perspectiva, y decide D219 -la distancia al centro del
  --     pueblo-, no un segundo lugar rural que este mas lejos. No hay cascada
  --     al "siguiente que siga activo": eso era un efecto secundario de la
  --     misma regresion que rompio la 62, no la regla real de D230.
  --
  --     Este punto queda a 10,375 km del parque, muy por encima de los 5 km de
  --     D219, asi que apagar el mas cercano tiene que rechazar el viaje entero,
  --     no cobrarle el lejano.
  update public.rural_fares set is_active = false where place_id = v_cerca;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
      extensions.st_x(v_punto), extensions.st_y(v_punto), null, null, '{}', '{}', c_dia);
    insert into resultados values (57, 'Apagar el mas cercano NO cae al siguiente: rechaza (D234)',
      'DESTINATION_NOT_PRICED', 'LO ACEPTO', false);
  exception when others then
    declare v_h text;
    begin
      get stacked diagnostics v_h = pg_exception_hint;
      insert into resultados values (57, 'Apagar el mas cercano NO cae al siguiente: rechaza (D234)',
        'DESTINATION_NOT_PRICED', coalesce(v_h, sqlstate), v_h = 'DESTINATION_NOT_PRICED');
    end;
  end;

  -- 58. LA COMPROBACION QUE DE VERDAD PRUEBA "SIN PRECIO": se apagan LOS DOS,
  --     y ahora si no queda nadie a quien pegarse. El punto rebota por D219,
  --     que es el caso que la 57 nunca pudo probar con solo un lugar apagado.
  update public.rural_fares set is_active = false where place_id = v_lejos;

  begin
    perform public.quote_fare('passenger', 1::smallint, v_lng, v_lat,
      extensions.st_x(v_punto), extensions.st_y(v_punto), null, null, '{}', '{}', c_dia);
    insert into resultados values (58, 'Apagar los dos SI deja el punto sin precio',
      'DESTINATION_NOT_PRICED', 'LO ACEPTO', false);
  exception when others then
    declare v_h text;
    begin
      get stacked diagnostics v_h = pg_exception_hint;
      insert into resultados values (58, 'Apagar los dos SI deja el punto sin precio',
        'DESTINATION_NOT_PRICED', coalesce(v_h, sqlstate), v_h = 'DESTINATION_NOT_PRICED');
    end;
  end;
end
$cercano$;


-- -----------------------------------------------------------------------------
-- Las restricciones de la referencia
-- -----------------------------------------------------------------------------

do $refcol$
declare
  v_pas uuid;
  v_org extensions.geography;
  v_dst extensions.geography;
begin
  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;

  select location into v_org from public.places order by sort_order, name limit 1;
  select location into v_dst from public.places order by sort_order desc, name limit 1;

  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  -- 59. Una tarifa rural sin decir de donde salio esconde el numero.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      15000, 15000, 0, false, true
    );
    insert into resultados values (59, 'Tarifa rural guardada sin referencia',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (59, 'Tarifa rural guardada sin referencia',
      'rechaza', sqlstate, true);
  end;

  -- 60. Y una referencia en un viaje urbano no significa nada.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural,
      fare_reference
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      4000, 4000, 0, false, false, 'El hospital'
    );
    insert into resultados values (60, 'Referencia guardada en un viaje urbano',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (60, 'Referencia guardada en un viaje urbano',
      'rechaza', sqlstate, true);
  end;

  -- 61. La combinacion buena si entra.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label, contact_phone, expires_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural,
      fare_reference
    ) values (
      v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
      15000, 15000, 0, false, true, 'El hospital'
    );
    insert into resultados values (61, 'Tarifa rural con su referencia',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (61, 'Tarifa rural con su referencia',
      'entra', 'LA RECHAZO ' || sqlstate, false);
  end;
end
$refcol$;

select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion,
  r.esperado,
  r.obtenido
from resultados r
union all
select
  999,
  -- `coalesce` A PROPOSITO: una comprobacion cuyo `ok` salga NULL -pasa cuando se
  -- compara contra un `select ... into` que no encontro fila- se veia FALLA en su
  -- linea pero **no contaba en el total**, porque `bool_and` ignora los NULL. El
  -- total podia decir "0 fallando" con comprobaciones en rojo. Un NULL es un fallo.
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
