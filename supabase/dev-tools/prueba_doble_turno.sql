-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827040000_shared_vehicle_shifts.sql` (doble turno: un
-- motorraton lo pueden llevar varias personas, pero solo una conectada a la vez).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_doble_turno.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LO QUE SE INTENTA ROMPER. La regla nueva sustituye a un indice unico que
-- llevaba vigente desde la Fase 5, asi que la mitad de las comprobaciones no
-- miran el caso feliz: miran que lo que el indice protegia **siga protegido por
-- otra via**. Si esa parte falla, el doble turno funcionaria y de paso dejaria a
-- dos conductores aceptando viajes con un solo motorraton.
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
-- Montaje: una unidad y tres conductores que se la reparten
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin uuid := 'b1000000-0000-4000-8000-0000000000a1';
  v_manana uuid := 'b1000000-0000-4000-8000-0000000000d1';
  v_tarde  uuid := 'b1000000-0000-4000-8000-0000000000d2';
  v_noche  uuid := 'b1000000-0000-4000-8000-0000000000d3';
  v_veh    uuid := 'b1000000-0000-4000-8000-0000000000e1';
  v_otra   uuid := 'b1000000-0000-4000-8000-0000000000e2';
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.turno.admin@motomoto-qa.co', now(), now()),
    (v_manana, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.turno.manana@motomoto-qa.co', now(), now()),
    (v_tarde,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.turno.tarde@motomoto-qa.co', now(), now()),
    (v_noche,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.turno.noche@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_manana, v_tarde, v_noche);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin,  'Zz turno admin',  '3000000051', 'admin',  'active'),
    (v_manana, 'Zz turno manana', '3000000052', 'driver', 'active'),
    (v_tarde,  'Zz turno tarde',  '3000000053', 'driver', 'active'),
    (v_noche,  'Zz turno noche',  '3000000054', 'driver', 'active');

  insert into public.drivers (id, approval_status, approved_at, is_available) values
    (v_manana, 'approved', now(), false),
    (v_tarde,  'approved', now(), false),
    (v_noche,  'approved', now(), false);

  insert into public.vehicles (id, unit_number, plate, model, max_passengers, status) values
    (v_veh,  9820, 'ZZT820', 'Compartido', 3, 'active'),
    (v_otra, 9821, 'ZZT821', 'Aparte',     3, 'active');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Varios conductores en la misma unidad
-- -----------------------------------------------------------------------------

do $compartir$
declare
  v_admin  constant uuid := 'b1000000-0000-4000-8000-0000000000a1';
  v_manana constant uuid := 'b1000000-0000-4000-8000-0000000000d1';
  v_tarde  constant uuid := 'b1000000-0000-4000-8000-0000000000d2';
  v_noche  constant uuid := 'b1000000-0000-4000-8000-0000000000d3';
  v_veh    constant uuid := 'b1000000-0000-4000-8000-0000000000e1';
  v_otra   constant uuid := 'b1000000-0000-4000-8000-0000000000e2';
  v_n integer;
  v_row record;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. LO QUE ANTES ERA IMPOSIBLE: tres conductores en la misma unidad.
  perform public.admin_assign_vehicle(v_manana, v_veh);
  perform public.admin_assign_vehicle(v_tarde, v_veh);
  perform public.admin_assign_vehicle(v_noche, v_veh);

  select count(*) into v_n
  from public.driver_vehicle_assignments
  where vehicle_id = v_veh and unassigned_at is null;
  insert into resultados values (1, 'Tres conductores comparten la misma unidad',
    '3', v_n::text, v_n = 3);

  -- 2. ASIGNAR AL SEGUNDO NO EXPULSA AL PRIMERO. Es justo lo que hacia la
  --    version anterior de la funcion, y lo que hacia imposible el doble turno.
  select count(*) into v_n
  from public.driver_vehicle_assignments
  where driver_id = v_manana and unassigned_at is null and vehicle_id = v_veh;
  insert into resultados values (2, 'Asignar al segundo NO le quita la unidad al primero',
    '1', v_n::text, v_n = 1);

  -- 3. PERO UN CONDUCTOR SIGUE TENIENDO UNA SOLA UNIDAD. El doble turno es que
  --    una unidad tenga varios conductores, no al reves, y esa mitad de la
  --    regla de la Fase 5 sigue en pie.
  perform public.admin_assign_vehicle(v_noche, v_otra);
  select count(*) into v_n
  from public.driver_vehicle_assignments
  where driver_id = v_noche and unassigned_at is null;
  insert into resultados values (3, 'Un conductor sigue teniendo UNA sola unidad',
    '1', v_n::text, v_n = 1);

  -- 4. Y la unidad compartida se queda con dos, porque el de noche se fue.
  select count(*) into v_n
  from public.driver_vehicle_assignments
  where vehicle_id = v_veh and unassigned_at is null;
  insert into resultados values (4, 'Al irse uno, la unidad se queda con los otros dos',
    '2', v_n::text, v_n = 2);

  -- 5. El listado del panel cuenta los que comparten, sin repetir la unidad.
  --    Con el `left join` de antes, una unidad compartida habria salido tres
  --    veces en el panel.
  select count(*) into v_n from public.admin_list_vehicles() where vehicle_id = v_veh;
  insert into resultados values (5, 'La unidad compartida sale UNA vez en el listado',
    '1', v_n::text, v_n = 1);

  -- 6. Y trae a los dos, con sus nombres.
  select driver_count, drivers_label into v_row
  from public.admin_list_vehicles() where vehicle_id = v_veh;
  insert into resultados values (6, 'El listado trae cuantos la comparten y quienes son',
    '2, Zz turno manana, Zz turno tarde',
    coalesce(v_row.driver_count::text, 'nulo') || ', ' || coalesce(v_row.drivers_label, 'nulo'),
    v_row.driver_count = 2 and v_row.drivers_label = 'Zz turno manana, Zz turno tarde');

  -- 7. Nadie conectado todavia, asi que nadie va al volante. Nulo aqui significa
  --    "la unidad esta parada", que es distinto de "no tiene conductores".
  select active_driver_name into v_row
  from public.admin_list_vehicles() where vehicle_id = v_veh;
  insert into resultados values (7, 'Sin nadie conectado, la unidad no tiene quien la lleve',
    'sin nadie',
    case when v_row.active_driver_name is null then 'sin nadie' else v_row.active_driver_name end,
    v_row.active_driver_name is null);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$compartir$;


-- -----------------------------------------------------------------------------
-- LA REGLA NUEVA: uno solo conectado a la vez
-- -----------------------------------------------------------------------------

do $turnos$
declare
  v_manana constant uuid := 'b1000000-0000-4000-8000-0000000000d1';
  v_tarde  constant uuid := 'b1000000-0000-4000-8000-0000000000d2';
  v_noche  constant uuid := 'b1000000-0000-4000-8000-0000000000d3';
  v_veh    constant uuid := 'b1000000-0000-4000-8000-0000000000e1';
  v_row record;
  v_ok boolean;
  v_h text;
  v_msg text;
begin
  -- 8. El de la manana se conecta. Escribe directo en `drivers`, que es una de
  --    las seis excepciones de D83: es lo que hace su aplicacion de verdad.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_manana, 'role', 'authenticated')::text);

  update public.drivers set is_available = true where id = v_manana;
  select is_available into v_ok from public.drivers where id = v_manana;
  insert into resultados values (8, 'El primero del turno SI se puede conectar',
    'true', v_ok::text, v_ok);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 9. LA COMPROBACION CENTRAL. El de la tarde intenta conectarse con el de la
  --    manana todavia dentro. Sin esto, los dos recibirian ofertas y los dos
  --    podrian aceptar con un solo motorraton fisico.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_tarde, 'role', 'authenticated')::text);

  begin
    update public.drivers set is_available = true where id = v_tarde;
    insert into resultados values (9, 'El companero NO se puede conectar a la vez',
      'COMPANION_ALREADY_AVAILABLE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint, v_msg = message_text;
    insert into resultados values (9, 'El companero NO se puede conectar a la vez',
      'COMPANION_ALREADY_AVAILABLE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'COMPANION_ALREADY_AVAILABLE');

    -- 10. Y EL MENSAJE DICE QUIEN Y CON QUE UNIDAD. Sin el nombre, el conductor
    --     tendria que llamar a la oficina para averiguar quien esta conectado;
    --     con el nombre, llama a su companero y lo resuelve.
    insert into resultados values (10, 'El mensaje nombra al companero y la unidad',
      'contiene "Zz turno manana" y "9820"', coalesce(v_msg, 'nulo'),
      v_msg like '%Zz turno manana%' and v_msg like '%9820%');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 11. EL RELEVO SI FUNCIONA: el de la manana se va y entonces el de la tarde
  --     entra. Va con la 9 vigilandola: sin esta, la 9 podria estar en verde
  --     porque nadie puede conectarse nunca, que romperia la aplicacion entera.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_manana, 'role', 'authenticated')::text);
  update public.drivers set is_available = false where id = v_manana;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_tarde, 'role', 'authenticated')::text);
  update public.drivers set is_available = true where id = v_tarde;
  select is_available into v_ok from public.drivers where id = v_tarde;
  insert into resultados values (11, 'Tras el relevo, el de la tarde SI entra',
    'true', v_ok::text, v_ok);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 12. Un conductor de OTRA unidad no estorba a nadie. Sin esta, la regla
  --     podria estar bloqueando por algo que no es compartir motorraton.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_noche, 'role', 'authenticated')::text);
  update public.drivers set is_available = true where id = v_noche;
  select is_available into v_ok from public.drivers where id = v_noche;
  insert into resultados values (12, 'Un conductor de otra unidad se conecta sin problema',
    'true', v_ok::text, v_ok);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 13. Y ahora el listado si dice quien va al volante de la compartida.
  select active_driver_name into v_row
  from public.admin_list_vehicles() where vehicle_id = v_veh;
  insert into resultados values (13, 'El listado dice quien lleva la unidad ahora',
    'Zz turno tarde', coalesce(v_row.active_driver_name, 'nulo'),
    v_row.active_driver_name = 'Zz turno tarde');

  -- 14. Apagarse nunca falla, aunque el companero este dentro. La regla solo
  --     mira al ENCENDER: apagar jamas crea un conflicto, y si tambien lo
  --     comprobara, un conductor podria quedarse atrapado sin poder desconectarse.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_tarde, 'role', 'authenticated')::text);
  begin
    update public.drivers set is_available = false where id = v_tarde;
    select is_available into v_ok from public.drivers where id = v_tarde;
    insert into resultados values (14, 'Desconectarse siempre funciona',
      'false', v_ok::text, v_ok = false);
  exception when others then
    insert into resultados values (14, 'Desconectarse siempre funciona',
      'false', 'fallo: ' || sqlstate, false);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$turnos$;


-- -----------------------------------------------------------------------------
-- Lo que el indice viejo protegia sigue protegido
-- -----------------------------------------------------------------------------

do $regresion$
declare
  v_manana constant uuid := 'b1000000-0000-4000-8000-0000000000d1';
  v_tarde  constant uuid := 'b1000000-0000-4000-8000-0000000000d2';
  v_veh    constant uuid := 'b1000000-0000-4000-8000-0000000000e1';
  v_n integer;
begin
  -- 15. `find_available_drivers` ve UNO SOLO de los que comparten unidad. Es la
  --     consecuencia que de verdad importa: es la funcion que reparte las
  --     ofertas, y si viera a los dos, los dos recibirian el mismo servicio.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_manana, 'role', 'authenticated')::text);
  update public.drivers set is_available = true where id = v_manana;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  select count(*) into v_n
  from public.drivers d
  join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  where dva.vehicle_id = v_veh and d.is_available;
  insert into resultados values (15,
    'De los que comparten unidad, solo uno queda disponible para recibir ofertas',
    '1', v_n::text, v_n = 1);

  -- 16. El indice que sobrevive: un conductor, una unidad. Se intenta violarlo
  --     directamente para comprobar que sigue ahi y no se cayo con el otro.
  begin
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (v_tarde, 'b1000000-0000-4000-8000-0000000000e2');
    insert into resultados values (16, 'Un conductor NO puede tener dos unidades vigentes',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (16, 'Un conductor NO puede tener dos unidades vigentes',
      'rechaza', sqlstate, sqlstate = '23505');
  end;
end
$regresion$;


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
