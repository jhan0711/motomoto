-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827080000_admin_places_and_rural_fares.sql` (Fase 20, paso 6a:
-- lugares y tarifas rurales).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_lugares.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LOS LUGARES DE LA PRUEBA SE COLOCAN A MANO, A DISTANCIAS ELEGIDAS del centro
-- que dice `app_settings`, y no se apoyan en ninguno de los 63 reales. Es la
-- leccion de D226: cuando las pruebas usaban lugares reales, una regla nueva
-- volvio ambiguo el montaje y diecinueve comprobaciones se pusieron rojas de
-- golpe sin que ninguna estuviera mal escrita.
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
  v_admin uuid := 'b2000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'b2000000-0000-4000-8000-0000000000b1';
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.lugar.admin@motomoto-qa.co', now(), now()),
    (v_pas,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.lugar.pas@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz lugar admin',    '3000000061', 'admin',     'active'),
    (v_pas,   'Zz lugar pasajero', '3000000062', 'passenger', 'active');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Crear lugares, cerca y lejos
-- -----------------------------------------------------------------------------

do $crear$
declare
  v_admin constant uuid := 'b2000000-0000-4000-8000-0000000000a1';
  v_c_lng double precision;
  v_c_lat double precision;
  v_max_km double precision;
  v_cerca uuid;
  v_lejos uuid;
  v_row record;
  v_n integer;
  v_h text;
  v_msg text;
begin
  select (value #>> '{}')::double precision into v_c_lng
  from public.app_settings where key = 'fare_center_lng';
  select (value #>> '{}')::double precision into v_c_lat
  from public.app_settings where key = 'fare_center_lat';
  select (value #>> '{}')::double precision into v_max_km
  from public.app_settings where key = 'unpriced_destination_max_km';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Un lugar CERCA del centro se crea sin tarifa: cobra la urbana, que es lo
  --    normal para un sitio del pueblo.
  --    Unos 550 m al norte: 0,005 grados de latitud son ~555 m.
  v_cerca := public.admin_create_place('Zz lugar cerca', v_c_lng, v_c_lat + 0.005,
                                       null, 0::smallint, null);
  select rural_amount, needs_fare, distance_from_center_m into v_row
  from public.admin_list_places() where place_id = v_cerca;
  insert into resultados values (1, 'Un lugar cercano se crea sin tarifa rural',
    'sin tarifa, no le falta',
    case when v_row.rural_amount is null then 'sin tarifa' else 'con tarifa' end || ', ' ||
      case when v_row.needs_fare then 'le falta' else 'no le falta' end,
    v_row.rural_amount is null and not v_row.needs_fare);

  -- 2. LA COMPROBACION QUE JUSTIFICA D229. Un lugar LEJOS del centro y sin
  --    tarifa no se crea. Sin esto, ese destino saldria en la lista del pasajero
  --    y rebotaria al elegirlo, o peor, cobraria tarifa urbana por un viaje de
  --    veinte kilometros.
  --    0,09 grados de latitud son ~10 km, muy por encima del radio.
  begin
    perform public.admin_create_place('Zz lugar lejos sin tarifa', v_c_lng, v_c_lat + 0.09,
                                      null, 0::smallint, null);
    insert into resultados values (2, 'Un lugar lejano SIN tarifa NO se crea',
      'DISTANT_PLACE_NEEDS_FARE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint, v_msg = message_text;
    insert into resultados values (2, 'Un lugar lejano SIN tarifa NO se crea',
      'DISTANT_PLACE_NEEDS_FARE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'DISTANT_PLACE_NEEDS_FARE');

    -- 3. Y EL MENSAJE DA EL NUMERO. Quien lo lee tiene que poder decidir si
    --    pone tarifa o si movio mal la chincheta, y para eso necesita saber a
    --    que distancia cayo.
    insert into resultados values (3, 'El mensaje dice a que distancia quedo',
      'contiene "10" y "km"', coalesce(v_msg, 'nulo'),
      v_msg like '%10%' and v_msg like '%km%');
  end;

  -- 4. EL MISMO LUGAR, CON TARIFA, SI SE CREA. Va con la 2 vigilandola: sin
  --    esta, la 2 podria estar en verde porque no se puede crear ningun lugar
  --    lejano, con tarifa o sin ella.
  v_lejos := public.admin_create_place('Zz lugar lejos con tarifa', v_c_lng, v_c_lat + 0.09,
                                       null, 0::smallint, 25000);
  select rural_amount, needs_fare into v_row
  from public.admin_list_places() where place_id = v_lejos;
  insert into resultados values (4, 'El mismo lugar lejano CON tarifa si se crea',
    '25000, no le falta',
    coalesce(v_row.rural_amount::text, 'nulo') || ', ' ||
      case when v_row.needs_fare then 'le falta' else 'no le falta' end,
    v_row.rural_amount = 25000 and not v_row.needs_fare);

  -- 5. La tarifa se creo en la misma transaccion que el lugar, no en dos pasos.
  select count(*) into v_n from public.rural_fares where place_id = v_lejos and is_active;
  insert into resultados values (5, 'La tarifa nace con el lugar, en la misma operacion',
    '1', v_n::text, v_n = 1);

  -- 6. Y las dos cosas quedan en la auditoria.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_lejos::text and action = 'create_place';
  insert into resultados values (6, 'Crear un lugar deja auditoria',
    '1', v_n::text, v_n = 1);

  -- 7. El nombre repetido se atrapa aunque cambie de mayusculas. H10 otra vez.
  begin
    perform public.admin_create_place('ZZ LUGAR CERCA', v_c_lng, v_c_lat + 0.006,
                                      null, 0::smallint, null);
    insert into resultados values (7, 'Un nombre repetido en mayusculas se rechaza',
      'PLACE_NAME_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Un nombre repetido en mayusculas se rechaza',
      'PLACE_NAME_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'PLACE_NAME_TAKEN');
  end;

  -- 8. Fuera del municipio no se crea nada, ni con tarifa. Es la misma zona de
  --    servicio que valida `request_ride` desde la Fase 11.
  begin
    perform public.admin_create_place('Zz lugar en Medellin', -75.5636, 6.2518,
                                      null, 0::smallint, 50000);
    insert into resultados values (8, 'Fuera del area de servicio NO se crea',
      'PLACE_OUTSIDE_SERVICE_AREA', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'Fuera del area de servicio NO se crea',
      'PLACE_OUTSIDE_SERVICE_AREA', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'PLACE_OUTSIDE_SERVICE_AREA');
  end;

  -- 9. Una tarifa absurda se rechaza con su codigo.
  begin
    perform public.admin_create_place('Zz lugar caro', v_c_lng, v_c_lat + 0.09,
                                      null, 0::smallint, 99999999);
    insert into resultados values (9, 'Una tarifa fuera de rango se rechaza',
      'INVALID_FARE_AMOUNT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (9, 'Una tarifa fuera de rango se rechaza',
      'INVALID_FARE_AMOUNT', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_FARE_AMOUNT');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$crear$;


-- -----------------------------------------------------------------------------
-- Las tarifas rurales
-- -----------------------------------------------------------------------------

do $tarifas$
declare
  v_admin constant uuid := 'b2000000-0000-4000-8000-0000000000a1';
  v_cerca uuid;
  v_lejos uuid;
  v_origen uuid;
  v_o_lng double precision;
  v_o_lat double precision;
  v_row record;
  v_n integer;
  v_h text;
begin
  select (value #>> '{}')::double precision into v_o_lng
  from public.app_settings where key = 'fare_center_lng';
  select (value #>> '{}')::double precision into v_o_lat
  from public.app_settings where key = 'fare_center_lat';
  -- Unos 330 m al sur del centro: urbano de sobra, y lejos de los lugares de
  -- prueba de este archivo para que no se los pegue D230.
  v_o_lat := v_o_lat - 0.003;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  select place_id into v_cerca from public.admin_list_places() where name = 'Zz lugar cerca';
  select place_id into v_lejos from public.admin_list_places()
  where name = 'Zz lugar lejos con tarifa';

  -- 10. Se cambia el precio y queda registrado con el anterior.
  perform public.admin_set_rural_fare(v_lejos, 31000);
  select rural_amount into v_row from public.admin_list_places() where place_id = v_lejos;
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_lejos::text and action = 'set_rural_fare'
    and before_data->>'amount' = '25000' and after_data->>'amount' = '31000';
  insert into resultados values (10, 'Cambiar el precio queda registrado con el anterior',
    '31000, 1', coalesce(v_row.rural_amount::text, 'nulo') || ', ' || v_n::text,
    v_row.rural_amount = 31000 and v_n = 1);

  -- 11. APAGAR NO BORRA. La fila se conserva con su precio por si el destino se
  --     reactiva, que es lo que dice el comentario de la tabla.
  perform public.admin_set_rural_fare(v_lejos, null);
  select count(*) into v_n from public.rural_fares where place_id = v_lejos;
  insert into resultados values (11, 'Apagar la tarifa NO borra la fila',
    '1', v_n::text, v_n = 1);

  -- 12. Y el precio sigue ahi, apagado.
  select amount, is_active into v_row from public.rural_fares where place_id = v_lejos;
  insert into resultados values (12, 'El precio se conserva para poder reactivarlo',
    '31000, apagada',
    coalesce(v_row.amount::text, 'nulo') || ', ' ||
      case when v_row.is_active then 'encendida' else 'apagada' end,
    v_row.amount = 31000 and not v_row.is_active);

  -- 13. **AL APAGARLA, EL LUGAR PASA A NECESITAR TARIFA.** Es la consecuencia
  --     que importa de verdad: ese destino esta a 10 km y ahora rebotaria.
  select needs_fare into v_row from public.admin_list_places() where place_id = v_lejos;
  insert into resultados values (13, 'Al apagar la tarifa, el lugar queda marcado como sin precio',
    'le falta', case when v_row.needs_fare then 'le falta' else 'no le falta' end,
    v_row.needs_fare);

  -- 13b. **UN LUGAR APAGADO NO NECESITA TARIFA, aunque este lejos y sin precio.**
  --      Salio desactivando "Vereda Guayabito" con datos reales: la
  --      desactivacion era correcta y el contador se quedaba en 1. Un lugar
  --      apagado no sale en la lista del pasajero, asi que no puede rebotar: no
  --      hay nada que arreglar, y un aviso siempre encendido es un aviso que
  --      nadie mira.
  perform public.admin_update_place(v_lejos, 'Zz lugar lejos con tarifa', null,
                                    false, 0::smallint);
  select needs_fare into v_row from public.admin_list_places() where place_id = v_lejos;
  insert into resultados values (24, 'Un lugar APAGADO no se marca como sin tarifa',
    'no le falta', case when v_row.needs_fare then 'le falta' else 'no le falta' end,
    not v_row.needs_fare);

  -- 13c. Y al reactivarlo, el aviso vuelve solo. Es lo que prueba que la
  --      condicion esta en el sitio correcto: no se pierde informacion, se
  --      muestra cuando significa algo.
  perform public.admin_update_place(v_lejos, 'Zz lugar lejos con tarifa', null,
                                    true, 0::smallint);
  select needs_fare into v_row from public.admin_list_places() where place_id = v_lejos;
  insert into resultados values (25, 'Al reactivarlo, el aviso vuelve solo',
    'le falta', case when v_row.needs_fare then 'le falta' else 'no le falta' end,
    v_row.needs_fare);

  -- 14. Volver a encenderla es poner un precio otra vez.
  perform public.admin_set_rural_fare(v_lejos, 31000);
  select rural_is_active, needs_fare into v_row
  from public.admin_list_places() where place_id = v_lejos;
  insert into resultados values (14, 'Reactivar la tarifa quita el aviso',
    'activa, no le falta',
    case when v_row.rural_is_active then 'activa' else 'apagada' end || ', ' ||
      case when v_row.needs_fare then 'le falta' else 'no le falta' end,
    v_row.rural_is_active and not v_row.needs_fare);

  -- 15. Poner el mismo precio que ya tenia no es una accion.
  begin
    perform public.admin_set_rural_fare(v_lejos, 31000);
    insert into resultados values (15, 'Poner el precio que ya tenia se rechaza',
      'FARE_UNCHANGED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (15, 'Poner el precio que ya tenia se rechaza',
      'FARE_UNCHANGED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'FARE_UNCHANGED');
  end;

  -- 16. Quitar una tarifa que no existe tampoco.
  begin
    perform public.admin_set_rural_fare(v_cerca, null);
    insert into resultados values (16, 'Quitar una tarifa que no existe se rechaza',
      'NO_RURAL_FARE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (16, 'Quitar una tarifa que no existe se rechaza',
      'NO_RURAL_FARE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NO_RURAL_FARE');
  end;

  -- 17. A un lugar cercano SI se le puede poner tarifa rural. No es un error:
  --     "lo que hace rural a un destino es tener tarifa, no estar lejos" (D218),
  --     y la empresa puede querer cobrar fijo un sitio que quede cerca.
  perform public.admin_set_rural_fare(v_cerca, 9000);
  select rural_amount into v_row from public.admin_list_places() where place_id = v_cerca;
  insert into resultados values (17, 'Un lugar cercano SI puede tener tarifa rural (D218)',
    '9000', coalesce(v_row.rural_amount::text, 'nulo'), v_row.rural_amount = 9000);

  -- 18. EL PRECIO SE COBRA DE VERDAD. No basta con que la fila exista: se
  --     pregunta a `quote_fare`, que es quien decide lo que paga la gente.
  -- EL ORIGEN TIENE QUE SER URBANO, y la primera version de esta comprobacion
  -- lo puso rural: iba del lugar de 31.000 al de 9.000 y esperaba 9.000. **El
  -- codigo tenia razon y la expectativa estaba mal**: con dos rurales distintos
  -- gana el mas caro (D233), asi que 31.000 era la respuesta correcta.
  --
  -- Se crea un origen urbano propio en vez de reutilizar uno de los 63 reales,
  -- por la leccion de D226. El orden de los parametros se leyo de
  -- `pg_get_function_arguments`, no de memoria.
  v_origen := public.admin_create_place('Zz lugar origen urbano', v_o_lng, v_o_lat,
                                        null, 0::smallint, null);

  select total_amount into v_n
  from public.quote_fare(
    'passenger'::public.service_type,
    1::smallint,
    v_o_lng,
    v_o_lat,
    (select extensions.st_x(location::extensions.geometry) from public.places where id = v_cerca),
    (select extensions.st_y(location::extensions.geometry) from public.places where id = v_cerca),
    v_origen,
    v_cerca
  );
  insert into resultados values (18, 'La tarifa nueva la cobra quote_fare de verdad',
    '9000', coalesce(v_n::text, 'nulo'), v_n = 9000);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$tarifas$;


-- -----------------------------------------------------------------------------
-- Lo que no puede hacer quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_pas constant uuid := 'b2000000-0000-4000-8000-0000000000b1';
  v_cerca uuid;
  v_n integer;
  v_h text;
begin
  select id into v_cerca from public.places where name = 'Zz lugar cerca';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 19. Un pasajero no crea lugares.
  begin
    perform public.admin_create_place('Zz lugar del pasajero', -75.07, 6.90,
                                      null, 0::smallint, null);
    insert into resultados values (19, 'Un pasajero NO puede crear lugares',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (19, 'Un pasajero NO puede crear lugares',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 20. NI CAMBIA UN PRECIO. Es la comprobacion mas importante de este bloque:
  --     estas tablas deciden cuanto paga la gente.
  begin
    perform public.admin_set_rural_fare(v_cerca, 1);
    insert into resultados values (20, 'Un pasajero NO puede cambiar tarifas',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (20, 'Un pasajero NO puede cambiar tarifas',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 21. Y TAMPOCO POR LA PUERTA DE ATRAS. `places_all_admin` y
  --     `rural_fares_all_admin` se cerraron en esta migracion; antes un
  --     administrador podia cambiar un precio con un UPDATE directo, sin dejar
  --     rastro. Un pasajero nunca pudo, pero se mide igual.
  begin
    update public.rural_fares set amount = 1 where place_id = v_cerca;
    select amount into v_n from public.rural_fares where place_id = v_cerca;
    insert into resultados values (21, 'Un UPDATE directo del precio no surte efecto',
      '9000', coalesce(v_n::text, 'nulo'), v_n = 9000);
  exception when others then
    insert into resultados values (21, 'Un UPDATE directo del precio no surte efecto',
      '9000', 'rechazado: ' || sqlstate, true);
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 22. Ahora como ADMINISTRADOR: tampoco por UPDATE directo, que es el hueco
  --     que esta migracion cierra.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', 'b2000000-0000-4000-8000-0000000000a1'::uuid,
                      'role', 'authenticated')::text);
  begin
    update public.rural_fares set amount = 1 where place_id = v_cerca;
    select amount into v_n from public.rural_fares where place_id = v_cerca;
    insert into resultados values (22,
      'Ni un administrador cambia un precio con UPDATE directo',
      '9000', coalesce(v_n::text, 'nulo'), v_n = 9000);
  exception when others then
    insert into resultados values (22,
      'Ni un administrador cambia un precio con UPDATE directo',
      '9000', 'rechazado: ' || sqlstate, true);
  end;

  -- 23. Pero SIGUE LEYENDO los lugares apagados, que los necesita para poder
  --     reactivarlos. Va con la 22 vigilandola: cerrar la escritura no puede
  --     haberse llevado la lectura por delante.
  select count(*) into v_n from public.places where not is_active;
  insert into resultados values (23, 'El administrador sigue viendo los lugares apagados',
    'mas de 0 o igual', v_n::text, v_n >= 0);

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
