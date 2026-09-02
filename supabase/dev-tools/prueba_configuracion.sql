-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827120000_admin_fares_cargo_and_settings.sql` (Fase 20, paso
-- 6b: tarifas urbanas, tipos de carga y parametros).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_configuracion.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- **ESTE ARCHIVO TOCA LOS PRECIOS Y LOS PARAMETROS REALES**, a diferencia de los
-- demas, que montan sus propios datos. No hay alternativa: la rejilla urbana son
-- seis filas fijas y `app_settings` tiene una fila por clave, asi que no se
-- pueden inventar copias. El `rollback` del final es lo unico que lo hace
-- seguro, y por eso este archivo **no debe ejecutarse con `--dry-run` desactivado
-- de ninguna otra forma ni partirse en trozos**.
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


do $montaje$
declare
  v_admin uuid := 'b3000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'b3000000-0000-4000-8000-0000000000b1';
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.conf.admin@motomoto-qa.co', now(), now()),
    (v_pas,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.conf.pas@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz conf admin',    '3000000071', 'admin',     'active'),
    (v_pas,   'Zz conf pasajero', '3000000072', 'passenger', 'active');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- La rejilla urbana
-- -----------------------------------------------------------------------------

do $urbanas$
declare
  v_admin constant uuid := 'b3000000-0000-4000-8000-0000000000a1';
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. La rejilla tiene sus seis casillas: tres cantidades por dos franjas.
  select count(*) into v_n from public.admin_list_urban_fares();
  insert into resultados values (1, 'La rejilla urbana tiene seis casillas',
    '6', v_n::text, v_n = 6);

  -- 2. Se cambia una y queda registrado con el valor anterior.
  perform public.admin_set_urban_fare(1::smallint, false, 4500);
  select amount into v_n from public.urban_fares
  where passenger_count = 1 and not is_night;
  insert into resultados values (2, 'Cambiar una tarifa urbana funciona',
    '4500', v_n::text, v_n = 4500);

  select count(*) into v_n from public.admin_audit_logs
  where action = 'set_urban_fare' and before_data->>'amount' = '4000'
    and after_data->>'amount' = '4500';
  insert into resultados values (3, 'Queda registrado con el valor anterior',
    '1', v_n::text, v_n = 1);

  -- 4. **EL PRECIO NUEVO LO COBRA `quote_fare` DE VERDAD.** No basta con que la
  --    fila cambie: se pregunta a quien decide lo que paga la gente.
  select total_amount into v_n
  from public.quote_fare(
    'passenger'::public.service_type, 1::smallint,
    (select (value #>> '{}')::double precision from public.app_settings where key = 'fare_center_lng'),
    (select (value #>> '{}')::double precision from public.app_settings where key = 'fare_center_lat'),
    (select (value #>> '{}')::double precision from public.app_settings where key = 'fare_center_lng'),
    (select (value #>> '{}')::double precision from public.app_settings where key = 'fare_center_lat'),
    null, null, '{}'::uuid[], '{}'::smallint[],
    -- Mediodia en Amalfi, para que no entre el recargo nocturno.
    '2026-08-27 17:00:00+00'::timestamptz
  );
  insert into resultados values (4, 'El precio nuevo lo cobra quote_fare de verdad',
    '4500', coalesce(v_n::text, 'nulo'), v_n = 4500);

  -- 5. Una casilla que no existe se rechaza. La rejilla no se amplia desde aqui:
  --    su forma la decidio la empresa.
  begin
    perform public.admin_set_urban_fare(7::smallint, false, 20000);
    insert into resultados values (5, 'Una casilla inexistente se rechaza',
      'URBAN_FARE_NOT_FOUND', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (5, 'Una casilla inexistente se rechaza',
      'URBAN_FARE_NOT_FOUND', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'URBAN_FARE_NOT_FOUND');
  end;

  -- 6. Un importe absurdo tambien.
  begin
    perform public.admin_set_urban_fare(1::smallint, false, 0);
    insert into resultados values (6, 'Una tarifa de cero se rechaza',
      'INVALID_FARE_AMOUNT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Una tarifa de cero se rechaza',
      'INVALID_FARE_AMOUNT', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_FARE_AMOUNT');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$urbanas$;


-- -----------------------------------------------------------------------------
-- Tipos de carga
-- -----------------------------------------------------------------------------

do $carga$
declare
  v_admin constant uuid := 'b3000000-0000-4000-8000-0000000000a1';
  v_id uuid;
  v_row record;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 7. Se crea uno nuevo.
  v_id := public.admin_upsert_cargo_type(null, '  Zz   bulto   de prueba  ', 5500,
                                         true, 9::smallint);
  select name, amount into v_row from public.cargo_types where id = v_id;
  insert into resultados values (7, 'Crea un tipo de carga y normaliza los espacios',
    'Zz bulto de prueba, 5500',
    coalesce(v_row.name, 'nulo') || ', ' || coalesce(v_row.amount::text, 'nulo'),
    v_row.name = 'Zz bulto de prueba' and v_row.amount = 5500);

  -- 8. EL HALLAZGO H10, APRETADO. En el bloque especial se midio que
  --    "Caja  grande" con dos espacios convivia con "Caja grande". Ahora que
  --    alguien puede teclearlo desde una pantalla, se rechaza.
  begin
    perform public.admin_upsert_cargo_type(null, 'Zz  bulto  de  prueba', 6000,
                                           true, 0::smallint);
    insert into resultados values (8, 'Un nombre igual con otros espacios se rechaza',
      'CARGO_NAME_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'Un nombre igual con otros espacios se rechaza',
      'CARGO_NAME_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'CARGO_NAME_TAKEN');
  end;

  -- 9. Se edita el que ya existe, y editarse a si mismo no cuenta como choque
  --    de nombre. Sin el `id <> p_cargo_type_id` de la funcion, cambiar solo el
  --    precio seria imposible.
  perform public.admin_upsert_cargo_type(v_id, 'Zz bulto de prueba', 6100,
                                         true, 9::smallint);
  select amount into v_n from public.cargo_types where id = v_id;
  insert into resultados values (9, 'Editar el mismo tipo no choca consigo mismo',
    '6100', coalesce(v_n::text, 'nulo'), v_n = 6100);

  -- 10. Apagar uno lo saca del catalogo del pasajero pero no lo borra: los
  --     servicios pasados lo referencian, y el precio de cada uno esta congelado
  --     en su propia linea (D225).
  perform public.admin_upsert_cargo_type(v_id, 'Zz bulto de prueba', 6100,
                                         false, 9::smallint);
  select count(*) into v_n from public.cargo_types where id = v_id and not is_active;
  insert into resultados values (10, 'Apagar un tipo de carga no lo borra',
    '1', v_n::text, v_n = 1);

  -- 11. El listado del panel trae tambien los apagados, que los necesita para
  --     poder reactivarlos.
  select count(*) into v_n from public.admin_list_cargo_types() where cargo_type_id = v_id;
  insert into resultados values (11, 'El administrador ve los tipos apagados',
    '1', v_n::text, v_n = 1);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$carga$;


-- -----------------------------------------------------------------------------
-- Los parametros
-- -----------------------------------------------------------------------------

do $parametros$
declare
  v_admin constant uuid := 'b3000000-0000-4000-8000-0000000000a1';
  v_valor text;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 12. Se cambia un numero y se guarda como numero, no como texto.
  perform public.admin_set_setting('offer_response_seconds', '45');
  select value #>> '{}' into v_valor from public.app_settings
  where key = 'offer_response_seconds';
  insert into resultados values (12, 'Un parametro numerico se guarda y se lee bien',
    '45', coalesce(v_valor, 'nulo'), v_valor = '45');

  -- 13. Y la zona horaria se guarda como texto, con sus comillas dentro del
  --     jsonb. Va con la 12 vigilandola: los dos tipos tienen que funcionar.
  perform public.admin_set_setting('fare_timezone', 'America/Lima');
  select value #>> '{}' into v_valor from public.app_settings where key = 'fare_timezone';
  insert into resultados values (13, 'La zona horaria se guarda como texto',
    'America/Lima', coalesce(v_valor, 'nulo'), v_valor = 'America/Lima');

  -- 14. Una zona horaria inventada se rechaza, comprobada contra el catalogo de
  --     PostgreSQL y no contra una lista escrita a mano.
  begin
    perform public.admin_set_setting('fare_timezone', 'America/Amalfi');
    insert into resultados values (14, 'Una zona horaria inventada se rechaza',
      'INVALID_TIMEZONE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (14, 'Una zona horaria inventada se rechaza',
      'INVALID_TIMEZONE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_TIMEZONE');
  end;

  -- 15. LA VALIDACION QUE MAS IMPORTA. Cero segundos de ventana de oferta
  --     caducaria cada oferta antes de que el conductor la viera, y la
  --     aplicacion dejaria de repartir servicios sin que nada pareciera roto.
  begin
    perform public.admin_set_setting('offer_response_seconds', '0');
    insert into resultados values (15, 'Una ventana de oferta de cero se rechaza',
      'INVALID_OFFER_WINDOW', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (15, 'Una ventana de oferta de cero se rechaza',
      'INVALID_OFFER_WINDOW', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'INVALID_OFFER_WINDOW');
  end;

  -- 16. Una hora fuera del reloj.
  begin
    perform public.admin_set_setting('night_fare_start_hour', '25');
    insert into resultados values (16, 'Una hora fuera de 0..23 se rechaza',
      'INVALID_HOUR', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (16, 'Una hora fuera de 0..23 se rechaza',
      'INVALID_HOUR', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_HOUR');
  end;

  -- 17. Y el maximo de pasajeros de R11 en cero, que dejaria la aplicacion sin
  --     poder pedir un solo viaje.
  begin
    perform public.admin_set_setting('max_passengers_per_request', '0');
    insert into resultados values (17, 'Un maximo de pasajeros de cero se rechaza',
      'INVALID_PASSENGER_MAX', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (17, 'Un maximo de pasajeros de cero se rechaza',
      'INVALID_PASSENGER_MAX', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'INVALID_PASSENGER_MAX');
  end;

  -- 18. Un texto donde va un numero.
  begin
    perform public.admin_set_setting('request_expiry_seconds', 'muchos');
    insert into resultados values (18, 'Un texto donde va un numero se rechaza',
      'SETTING_MUST_BE_NUMBER', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (18, 'Un texto donde va un numero se rechaza',
      'SETTING_MUST_BE_NUMBER', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'SETTING_MUST_BE_NUMBER');
  end;

  -- 19. Una clave que no existe: el panel no inventa parametros, porque una
  --     clave nueva no la lee ningun codigo.
  begin
    perform public.admin_set_setting('parametro_inventado', '1');
    insert into resultados values (19, 'No se pueden crear parametros nuevos',
      'SETTING_NOT_FOUND', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (19, 'No se pueden crear parametros nuevos',
      'SETTING_NOT_FOUND', coalesce(nullif(v_h, ''), sqlstate), v_h = 'SETTING_NOT_FOUND');
  end;

  -- 20. Un valor valido dentro de rango SI pasa. Va vigilando a las cinco
  --     anteriores: sin esta, todas podrian estar en verde porque la funcion
  --     rechaza absolutamente todo.
  perform public.admin_set_setting('night_fare_start_hour', '21');
  select value #>> '{}' into v_valor from public.app_settings
  where key = 'night_fare_start_hour';
  insert into resultados values (20, 'Un valor dentro de rango SI se acepta',
    '21', coalesce(v_valor, 'nulo'), v_valor = '21');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$parametros$;


-- -----------------------------------------------------------------------------
-- Quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_pas constant uuid := 'b3000000-0000-4000-8000-0000000000b1';
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 21. Un pasajero no cambia precios.
  begin
    perform public.admin_set_urban_fare(1::smallint, false, 1);
    insert into resultados values (21, 'Un pasajero NO puede cambiar la tarifa urbana',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (21, 'Un pasajero NO puede cambiar la tarifa urbana',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 22. Ni parametros.
  begin
    perform public.admin_set_setting('offer_response_seconds', '999');
    insert into resultados values (22, 'Un pasajero NO puede cambiar la configuracion',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (22, 'Un pasajero NO puede cambiar la configuracion',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 23. NI POR LA PUERTA DE ATRAS. Las tres politicas `_all_admin` se cerraron
  --     en esta migracion; con ellas abiertas, un UPDATE directo cambiaba un
  --     precio sin dejar rastro.
  update public.urban_fares set amount = 1 where passenger_count = 1 and not is_night;
  select amount into v_n from public.urban_fares where passenger_count = 1 and not is_night;
  insert into resultados values (23, 'Un UPDATE directo de la tarifa urbana no surte efecto',
    '4500', coalesce(v_n::text, 'nulo'), v_n = 4500);

  -- 24. Pero la aplicacion SIGUE LEYENDO las tarifas: las necesita en cada
  --     servicio. Va con la 23 vigilandola.
  select count(*) into v_n from public.urban_fares;
  insert into resultados values (24, 'Un pasajero sigue leyendo las tarifas',
    '6', v_n::text, v_n = 6);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 25. Y ni siquiera el ADMINISTRADOR puede por UPDATE directo, que es el hueco
  --     que esta migracion cierra: es la cuarta vez que aparece el mismo.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', 'b3000000-0000-4000-8000-0000000000a1'::uuid,
                      'role', 'authenticated')::text);
  update public.app_settings set value = to_jsonb(999) where key = 'offer_response_seconds';
  select (value #>> '{}')::integer into v_n from public.app_settings
  where key = 'offer_response_seconds';
  insert into resultados values (25,
    'Ni un administrador cambia un parametro con UPDATE directo',
    '45', coalesce(v_n::text, 'nulo'), v_n = 45);
  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$privacidad$;


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
