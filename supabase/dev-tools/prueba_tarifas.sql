-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de las tres tablas de tarifas creadas en
-- `20260825223000_fare_tables.sql` (bloque especial, paso 1).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_tarifas.sql
--
-- NO PRUEBA NINGUNA FORMULA, porque todavia no hay ninguna: esta migracion solo
-- guarda precios. Lo que se comprueba aqui es que la estructura aguante lo que
-- un panel administrativo mal usado le va a mandar el dia de manana, y que la
-- politica deje leer al pasajero y no escribir.
--
-- La comprobacion 21 es la mas importante del archivo y no parece gran cosa: es
-- la que dice si la franja nocturna se decide con el reloj de Amalfi o con el de
-- UTC. Sin ella, el recargo entraria a las cinco de la tarde y nadie lo notaria
-- hasta tener a un pasajero delante.
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

-- A los DOS roles, no solo a `authenticated`. Este archivo tambien suplanta a
-- `anon` al final, y sin su permiso sobre la tabla temporal la prueba se cae con
-- un 42501 que no tiene nada que ver con lo que se esta probando.
do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Intentos de romper: urban_fares
-- -----------------------------------------------------------------------------

do $urbanas$
begin
  -- La rejilla ES la clave. Un segundo precio para la misma casilla dejaria el
  -- calculo eligiendo uno de los dos al azar.
  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (3, true, 9999);
    insert into resultados values (1, 'Dos tarifas para tres pasajeros de noche',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (1, 'Dos tarifas para tres pasajeros de noche',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (4, false, 0);
    insert into resultados values (2, 'Tarifa urbana de cero pesos',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (2, 'Tarifa urbana de cero pesos',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (4, false, -1);
    insert into resultados values (3, 'Tarifa urbana negativa',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (3, 'Tarifa urbana negativa',
      'rechaza', sqlstate, true);
  end;

  -- El cero de mas escrito en el panel. Es el error que mas facil se comete y el
  -- que peor se ve: 40.000 en la pantalla de quien iba a pagar 4.000.
  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (4, false, 1000001);
    insert into resultados values (4, 'Tarifa urbana por encima del techo',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (4, 'Tarifa urbana por encima del techo',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (0, false, 4000);
    insert into resultados values (5, 'Tarifa para cero pasajeros',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (5, 'Tarifa para cero pasajeros',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (11, false, 4000);
    insert into resultados values (6, 'Tarifa para once pasajeros',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (6, 'Tarifa para once pasajeros',
      'rechaza', sqlstate, true);
  end;

  -- Al reves que las anteriores: el techo tiene que dejar pasar su propio valor.
  -- Un limite escrito con `<` en vez de `<=` rechazaria exactamente 1.000.000, y
  -- eso no se descubre probando solo lo que debe fallar.
  begin
    insert into public.urban_fares (passenger_count, is_night, amount) values (9, false, 1000000);
    insert into resultados values (7, 'El techo justo, 1.000.000, si entra',
      'acepta', 'la acepto', true);
    delete from public.urban_fares where passenger_count = 9;
  exception when others then
    insert into resultados values (7, 'El techo justo, 1.000.000, si entra',
      'acepta', 'LA RECHAZO ' || sqlstate, false);
  end;
end
$urbanas$;


-- -----------------------------------------------------------------------------
-- Intentos de romper: rural_fares
-- -----------------------------------------------------------------------------

do $rurales$
declare
  v_lugar uuid;
  v_msg   text;
begin
  select id into v_lugar from public.places order by sort_order, name limit 1;

  begin
    insert into public.rural_fares (place_id, amount)
    values ('00000000-0000-4000-8000-000000000000', 12000);
    insert into resultados values (8, 'Tarifa rural para un lugar que no existe',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (8, 'Tarifa rural para un lugar que no existe',
      'rechaza', sqlstate, true);
  end;

  insert into public.rural_fares (place_id, amount) values (v_lugar, 12000);

  begin
    insert into public.rural_fares (place_id, amount) values (v_lugar, 30000);
    insert into resultados values (9, 'Dos precios para el mismo destino rural',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (9, 'Dos precios para el mismo destino rural',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.rural_fares (place_id, amount)
    values ((select id from public.places where id <> v_lugar order by name limit 1), 0);
    insert into resultados values (10, 'Tarifa rural de cero pesos',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (10, 'Tarifa rural de cero pesos',
      'rechaza', sqlstate, true);
  end;

  -- El caso que motiva el `on delete restrict`. Si esto pasara, el destino
  -- seguiria existiendo en las solicitudes viejas y los nuevos viajes alli
  -- cobrarian tarifa urbana sin que nadie se enterara.
  --
  -- No basta con que falle: tiene que fallar POR ESTO. Se comprueba que el
  -- mensaje nombre a `rural_fares` y no a otra cosa, porque un fallo por otra
  -- causa dejaria la prueba en verde por el motivo equivocado, que es E12.
  begin
    delete from public.places where id = v_lugar;
    insert into resultados values (11, 'Borrar un lugar que tiene tarifa rural',
      'rechaza por rural_fares', 'LO BORRO', false);
  exception when others then
    get stacked diagnostics v_msg = message_text;
    insert into resultados values (11, 'Borrar un lugar que tiene tarifa rural',
      'rechaza por rural_fares',
      sqlstate || ' ' || case when v_msg ilike '%rural_fares%' then 'rural_fares' else v_msg end,
      sqlstate = '23503' and v_msg ilike '%rural_fares%');
  end;
end
$rurales$;


-- -----------------------------------------------------------------------------
-- Intentos de romper: cargo_types
-- -----------------------------------------------------------------------------

do $cargas$
declare
  v_n integer;
begin
  begin
    insert into public.cargo_types (name, amount) values ('Bicicleta', 5000);
    insert into resultados values (12, 'Tipo de carga con nombre repetido',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (12, 'Tipo de carga con nombre repetido',
      'rechaza', sqlstate, true);
  end;

  -- El indice normaliza mayusculas y espacios de los extremos. Sin el, el panel
  -- acabaria con dos bultos de cafe a precios distintos y el calculo eligiendo
  -- uno al azar.
  begin
    insert into public.cargo_types (name, amount) values ('   BULTO DE CAFÉ   ', 9000);
    insert into resultados values (13, 'Mismo nombre en mayusculas y con espacios alrededor',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (13, 'Mismo nombre en mayusculas y con espacios alrededor',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.cargo_types (name, amount) values ('X', 1000);
    insert into resultados values (14, 'Tipo de carga con nombre de una letra',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (14, 'Tipo de carga con nombre de una letra',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.cargo_types (name, amount) values ('Nevera', 0);
    insert into resultados values (15, 'Tipo de carga de cero pesos',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (15, 'Tipo de carga de cero pesos',
      'rechaza', sqlstate, true);
  end;

  -- ESTA SE ESPERA EN VERDE ENTRANDO, no rechazando, y no es un descuido.
  --
  -- Es el hallazgo H10 visto en la tabla nueva: el indice normaliza los espacios
  -- de los extremos y no los del medio, asi que "Caja  grande" con dos espacios
  -- convive con "Caja grande". Se deja escrito aqui para que quede medido y no
  -- se descubra el dia que el panel permita crear tipos de carga (Fase 20).
  begin
    insert into public.cargo_types (name, amount) values ('Caja  grande', 2800);
    get diagnostics v_n = row_count;
    insert into resultados values (16, 'H10 conocido: doble espacio en medio si entra',
      'entra (hallazgo abierto)', 'entro', v_n = 1);
  exception when others then
    insert into resultados values (16, 'H10 conocido: doble espacio en medio si entra',
      'entra (hallazgo abierto)', 'lo rechazo ' || sqlstate, false);
  end;
end
$cargas$;


-- -----------------------------------------------------------------------------
-- Los valores que dio la empresa
-- -----------------------------------------------------------------------------

do $datos$
declare
  v_n       integer;
  v_max     smallint;
  v_hora    integer;
  v_noche   integer;
  v_zona    text;
begin
  select count(*) into v_n
  from public.urban_fares
  where (passenger_count, is_night, amount) in (
    (1, false, 4000), (2, false, 6200), (3, false, 8500),
    (1, true, 7000), (2, true, 12000), (3, true, 17000)
  );
  insert into resultados values (17, 'Las seis tarifas urbanas son las de la empresa',
    '6', v_n::text, v_n = 6);

  -- La rejilla tiene que cubrir todo lo que el pasajero puede elegir. Si alguien
  -- sube `max_passengers_per_request` a cuatro sin anadir filas, este numero
  -- deja de cuadrar y el fallo se ve aqui y no en la pantalla de un pasajero.
  v_max := (public.get_setting('max_passengers_per_request', '3'))::smallint;
  select count(*) into v_n
  from generate_series(1, v_max) g
    cross join (values (false), (true)) f(noche)
  where not exists (
    select 1 from public.urban_fares u
    where u.passenger_count = g and u.is_night = f.noche
  );
  insert into resultados values (18, 'La rejilla urbana cubre de 1 a ' || v_max || ' en las dos franjas',
    '0 huecos', v_n || ' huecos', v_n = 0);

  select count(*) into v_n
  from public.cargo_types
  where (name, amount) in (
    ('Caja pequeña', 1700), ('Caja grande', 2800), ('Bicicleta', 2300),
    ('Bulto de cemento', 2800), ('Bulto de café', 4900), ('Domicilios y encomiendas', 3800)
  );
  insert into resultados values (19, 'Los seis tipos de carga son los de la empresa',
    '6', v_n::text, v_n = 6);

  -- Que la zona horaria exista de verdad. Un nombre mal escrito no falla al
  -- guardarse en `app_settings`, porque ahi cabe cualquier texto: falla mas
  -- tarde, al convertir, y para entonces ya esta en produccion.
  v_zona := (public.get_setting('fare_timezone', '"America/Bogota"')) #>> '{}';
  select count(*) into v_n from pg_timezone_names where name = v_zona;
  insert into resultados values (20, 'La zona horaria ' || v_zona || ' existe en el servidor',
    '1', v_n::text, v_n = 1);

  -- LA COMPROBACION QUE JUSTIFICA TODO EL PARRAFO DE LA MIGRACION.
  --
  -- Las 03:00 UTC son las 22:00 del dia anterior en Amalfi, o sea el primer
  -- minuto de la franja nocturna. Y las 22:00 UTC son las 17:00 en Amalfi, o sea
  -- pleno dia. Si alguien quita la conversion, la primera sigue en verde por
  -- casualidad y la segunda se pone roja: por eso van las dos.
  v_hora := extract(hour from (timestamptz '2026-08-25 03:00:00+00' at time zone v_zona));
  v_noche := (public.get_setting('night_fare_start_hour', '22'))::integer;
  insert into resultados values (21, 'Las 03:00 UTC son las 22:00 en Amalfi, inicio de la noche',
    v_noche::text, v_hora::text, v_hora = v_noche);

  v_hora := extract(hour from (timestamptz '2026-08-25 22:00:00+00' at time zone v_zona));
  insert into resultados values (22, 'Las 22:00 UTC son las 17:00 en Amalfi, todavia de dia',
    '17', v_hora::text, v_hora = 17);
end
$datos$;


-- -----------------------------------------------------------------------------
-- Las politicas, suplantando a un pasajero de verdad
-- -----------------------------------------------------------------------------

-- Con el rol privilegiado las politicas ni se evaluan, asi que probarlas asi
-- daria todo por bueno. Es la regla 4 de las aprendidas en la Fase 5.
do $rls$
declare
  v_pasajero uuid;
  v_lugar    uuid;
  v_n        integer;
begin
  select p.id into v_pasajero
  from public.profiles p
  where p.role = 'passenger' and p.status = 'active'
  order by p.created_at
  limit 1;

  if v_pasajero is null then
    insert into resultados values (23, 'No hay ningun pasajero activo con el que probar',
      'un pasajero', 'ninguno', false);
    return;
  end if;

  -- Un tipo de carga y un destino rural apagados, para comprobar que el pasajero
  -- no los ve. Se apagan aqui y desaparecen con el rollback.
  update public.cargo_types set is_active = false where name = 'Bicicleta';

  select id into v_lugar from public.places order by sort_order, name limit 1;
  update public.rural_fares set is_active = false where place_id = v_lugar;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pasajero, 'role', 'authenticated')::text);

  select count(*) into v_n from public.urban_fares;
  insert into resultados values (23, 'El pasajero lee las seis tarifas urbanas',
    '6', v_n::text, v_n = 6);

  select count(*) into v_n from public.cargo_types where name = 'Bicicleta';
  insert into resultados values (24, 'El pasajero NO ve un tipo de carga apagado',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.rural_fares where place_id = v_lugar;
  insert into resultados values (25, 'El pasajero NO ve una tarifa rural apagada',
    '0', v_n::text, v_n = 0);

  begin
    insert into public.cargo_types (name, amount) values ('Piano', 1000);
    insert into resultados values (26, 'El pasajero NO puede crear un tipo de carga',
      'rechaza', 'LO CREO', false);
  exception when others then
    insert into resultados values (26, 'El pasajero NO puede crear un tipo de carga',
      'rechaza', sqlstate, true);
  end;

  -- Un UPDATE sin politica que lo permita NO lanza excepcion: simplemente no
  -- toca ninguna fila. Por eso aqui se cuenta y no se atrapa un error, que es
  -- justo el sitio donde una prueba mal escrita saldria verde sin probar nada.
  update public.urban_fares set amount = 1 where passenger_count = 1 and not is_night;
  get diagnostics v_n = row_count;
  insert into resultados values (27, 'El pasajero NO puede cambiar un precio urbano',
    '0 filas', v_n || ' filas', v_n = 0);

  delete from public.cargo_types where name = 'Caja grande';
  get diagnostics v_n = row_count;
  insert into resultados values (28, 'El pasajero NO puede borrar un tipo de carga',
    '0 filas', v_n || ' filas', v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$rls$;


-- -----------------------------------------------------------------------------
-- Sin sesion
-- -----------------------------------------------------------------------------

do $anonimo$
declare
  v_n integer;
begin
  execute 'set local role anon';
  execute format('set local request.jwt.claims to %L', '{"role":"anon"}');

  select count(*) into v_n from public.urban_fares;
  insert into resultados values (29, 'Sin sesion no se lee la tarifa urbana',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.cargo_types;
  insert into resultados values (30, 'Sin sesion no se lee el catalogo de carga',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.rural_fares;
  insert into resultados values (31, 'Sin sesion no se leen las tarifas rurales',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$anonimo$;


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
  case when bool_and(x.ok) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not x.ok) || ' fallando'
from resultados x
order by 1;

rollback;
