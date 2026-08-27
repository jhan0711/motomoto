-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827010000_admin_vehicle_management.sql` (Fase 20, paso 5:
-- vehiculos y asignacion conductor-vehiculo).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_vehiculos.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- Se aisla por numero de unidad: los motorratones de esta prueba usan numeros a
-- partir del 9800, que ninguna unidad real va a alcanzar. Los conductores
-- empiezan por `af000000`.
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
-- Montaje
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin   uuid := 'af000000-0000-4000-8000-0000000000a1';
  v_pas     uuid := 'af000000-0000-4000-8000-0000000000b1';
  v_libre   uuid := 'af000000-0000-4000-8000-0000000000d1';
  v_ocupado uuid := 'af000000-0000-4000-8000-0000000000d2';
  v_veh_ocup uuid := 'af000000-0000-4000-8000-0000000000e1';
  v_req      uuid := 'af000000-0000-4000-8000-000000000001';
  v_lng double precision;
  v_lat double precision;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.veh.admin@motomoto-qa.co', now(), now()),
    (v_pas,     '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.veh.pas@motomoto-qa.co', now(), now()),
    (v_libre,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.veh.libre@motomoto-qa.co', now(), now()),
    (v_ocupado, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.veh.ocupado@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas, v_libre, v_ocupado);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin,   'Zz veh admin',    '3000000041', 'admin',     'active'),
    (v_pas,     'Zz veh pasajero', '3000000042', 'passenger', 'active'),
    (v_libre,   'Zz veh libre',    '3000000043', 'driver',    'active'),
    (v_ocupado, 'Zz veh ocupado',  '3000000044', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available) values
    (v_libre,   'approved', now(), false),
    (v_ocupado, 'approved', now(), true);

  -- Una unidad con un servicio en marcha, para las reglas de proteccion.
  insert into public.vehicles (id, unit_number, plate, model, max_passengers, status)
  values (v_veh_ocup, 9801, 'ZZV801', 'Ocupado', 3, 'active');

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
  values (v_ocupado, v_veh_ocup);

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  ) values (
    v_req, v_pas, 'in_progress', 3,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz origen',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz destino', '3000000042', now() - interval '5 minutes', now() + interval '10 minutes',
    'passenger', 8500, 8500, 0, false, false
  );

  -- TRES pasajeros a proposito: es lo que permite comprobar que no se le puede
  -- bajar la capacidad a la unidad por debajo de lo que ya lleva encima.
  insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at)
  values ('af000000-0000-4000-8000-00000000c001', v_req, v_ocupado, v_veh_ocup, 'in_progress', 3,
          now() - interval '4 minutes');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Crear y editar
-- -----------------------------------------------------------------------------

do $crear$
declare
  v_admin constant uuid := 'af000000-0000-4000-8000-0000000000a1';
  v_veh_ocup constant uuid := 'af000000-0000-4000-8000-0000000000e1';
  v_nuevo uuid;
  v_row record;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Se crea una unidad y la placa queda normalizada en mayusculas por el
  --    disparador de la Fase 5.
  v_nuevo := public.admin_create_vehicle(9802, ' zzv802 ', ' Bajaj RE ', 3::smallint);

  select unit_number, plate, model, max_passengers, status::text into v_row
  from public.vehicles where id = v_nuevo;
  insert into resultados values (1, 'Crea la unidad y normaliza la placa',
    '9802, ZZV802, Bajaj RE, 3, active',
    v_row.unit_number || ', ' || v_row.plate || ', ' || coalesce(v_row.model, 'nulo') ||
      ', ' || v_row.max_passengers || ', ' || v_row.status,
    v_row.unit_number = 9802 and v_row.plate = 'ZZV802' and v_row.model = 'Bajaj RE'
      and v_row.max_passengers = 3 and v_row.status = 'active');

  -- 2. Y deja auditoria.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_nuevo::text and action = 'create_vehicle';
  insert into resultados values (2, 'Crear una unidad deja auditoria',
    '1', v_n::text, v_n = 1);

  -- 3. El numero de unidad es unico.
  begin
    perform public.admin_create_vehicle(9802, 'ZZV803', null, 3::smallint);
    insert into resultados values (3, 'Un numero de unidad repetido se rechaza',
      'UNIT_NUMBER_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (3, 'Un numero de unidad repetido se rechaza',
      'UNIT_NUMBER_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'UNIT_NUMBER_TAKEN');
  end;

  -- 4. LA PLACA REPETIDA SE ATRAPA AUNQUE VENGA EN MINUSCULAS. Es el hallazgo
  --    H10 aplicado aqui: sin comparar normalizado, 'zzv802' pasaria la
  --    comprobacion y chocaria despues contra el indice unico con un 23505 sin
  --    explicacion, porque el disparador la habria puesto en mayusculas.
  begin
    perform public.admin_create_vehicle(9803, 'zzv802', null, 3::smallint);
    insert into resultados values (4, 'Una placa repetida en minusculas tambien se rechaza',
      'PLATE_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (4, 'Una placa repetida en minusculas tambien se rechaza',
      'PLATE_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'PLATE_TAKEN');
  end;

  -- 5. Una capacidad fuera de rango se rechaza con su codigo, no con un 23514.
  begin
    perform public.admin_create_vehicle(9804, 'ZZV804', null, 99::smallint);
    insert into resultados values (5, 'Una capacidad fuera de rango se rechaza',
      'INVALID_CAPACITY', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (5, 'Una capacidad fuera de rango se rechaza',
      'INVALID_CAPACITY', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_CAPACITY');
  end;

  -- 6. Editar funciona y queda registrado con lo que habia antes.
  perform public.admin_update_vehicle(v_nuevo, 9802, 'ZZV802', 'Piaggio Ape',
                                      2::smallint, 'maintenance', 'En taller');
  select max_passengers, status::text, model, notes into v_row
  from public.vehicles where id = v_nuevo;
  insert into resultados values (6, 'Edita capacidad, estado, modelo y notas',
    '2, maintenance, Piaggio Ape, En taller',
    v_row.max_passengers || ', ' || v_row.status || ', ' || coalesce(v_row.model, 'nulo') ||
      ', ' || coalesce(v_row.notes, 'nulo'),
    v_row.max_passengers = 2 and v_row.status = 'maintenance'
      and v_row.model = 'Piaggio Ape' and v_row.notes = 'En taller');

  -- 7. NO SE MANDA A TALLER UNA UNIDAD QUE VA POR LA CALLE CON UN PASAJERO
  --    DENTRO. Mismo criterio que D244 con los conductores.
  begin
    perform public.admin_update_vehicle(v_veh_ocup, 9801, 'ZZV801', null,
                                        3::smallint, 'retired', null);
    insert into resultados values (7, 'NO se retira una unidad con servicio en curso',
      'VEHICLE_HAS_ACTIVE_RIDE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'NO se retira una unidad con servicio en curso',
      'VEHICLE_HAS_ACTIVE_RIDE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'VEHICLE_HAS_ACTIVE_RIDE');
  end;

  -- 8. NI SE LE BAJA LA CAPACIDAD POR DEBAJO DE LO QUE YA LLEVA. Lleva tres
  --    pasajeros; dejarla en dos crearia un viaje que se contradice a si mismo,
  --    y ninguna restriccion de la Fase 5 lo atrapa: `enforce_ride_capacity`
  --    mira al aceptar, no al editar el vehiculo.
  begin
    perform public.admin_update_vehicle(v_veh_ocup, 9801, 'ZZV801', null,
                                        2::smallint, 'active', null);
    insert into resultados values (8, 'NO se baja la capacidad por debajo de la carga actual',
      'CAPACITY_BELOW_CURRENT_LOAD', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'NO se baja la capacidad por debajo de la carga actual',
      'CAPACITY_BELOW_CURRENT_LOAD', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'CAPACITY_BELOW_CURRENT_LOAD');
  end;

  -- 9. Pero SI se le puede subir, y editar lo demas. Va con la 7 y la 8
  --    vigilandolas: sin esta, las dos podrian estar en verde porque la funcion
  --    rechaza cualquier edicion de una unidad ocupada.
  perform public.admin_update_vehicle(v_veh_ocup, 9801, 'ZZV801', 'Modelo nuevo',
                                      4::smallint, 'active', null);
  select max_passengers, model into v_row from public.vehicles where id = v_veh_ocup;
  insert into resultados values (9, 'A una unidad ocupada SI se le puede subir la capacidad',
    '4, Modelo nuevo',
    v_row.max_passengers || ', ' || coalesce(v_row.model, 'nulo'),
    v_row.max_passengers = 4 and v_row.model = 'Modelo nuevo');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$crear$;


-- -----------------------------------------------------------------------------
-- Asignar y quitar
-- -----------------------------------------------------------------------------

do $asignar$
declare
  v_admin   constant uuid := 'af000000-0000-4000-8000-0000000000a1';
  v_libre   constant uuid := 'af000000-0000-4000-8000-0000000000d1';
  v_ocupado constant uuid := 'af000000-0000-4000-8000-0000000000d2';
  v_veh_ocup constant uuid := 'af000000-0000-4000-8000-0000000000e1';
  v_a uuid;
  v_b uuid;
  v_n integer;
  v_row record;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  v_a := public.admin_create_vehicle(9810, 'ZZV810', null, 3::smallint);
  v_b := public.admin_create_vehicle(9811, 'ZZV811', null, 3::smallint);

  -- 10. Asignar deja la asignacion viva y con quien la hizo.
  perform public.admin_assign_vehicle(v_libre, v_a);
  select vehicle_id, assigned_by into v_row
  from public.driver_vehicle_assignments
  where driver_id = v_libre and unassigned_at is null;
  insert into resultados values (10, 'Asignar deja la asignacion vigente y quien la hizo',
    v_a::text || ', ' || v_admin::text,
    coalesce(v_row.vehicle_id::text, 'nulo') || ', ' || coalesce(v_row.assigned_by::text, 'nulo'),
    v_row.vehicle_id = v_a and v_row.assigned_by = v_admin);

  -- 11. CAMBIAR DE UNIDAD CIERRA LA ANTERIOR SOLO. Los indices unicos parciales
  --     de la Fase 5 no admiten dos vigentes por conductor, asi que si esto no
  --     cerrara la anterior, la operacion fallaria con un 23505.
  perform public.admin_assign_vehicle(v_libre, v_b);
  select count(*) into v_n
  from public.driver_vehicle_assignments
  where driver_id = v_libre and unassigned_at is null;
  insert into resultados values (11, 'Cambiar de unidad deja UNA sola asignacion vigente',
    '1', v_n::text, v_n = 1);

  -- 12. Y la anterior queda cerrada en el historial, no borrada: el periodo es
  --     informacion operativa de la empresa.
  select count(*) into v_n
  from public.driver_vehicle_assignments
  where driver_id = v_libre and vehicle_id = v_a and unassigned_at is not null;
  insert into resultados values (12, 'La asignacion anterior se cierra, no se borra',
    '1', v_n::text, v_n = 1);

  -- 13. Una unidad en taller o retirada no se le entrega a nadie.
  perform public.admin_update_vehicle(v_a, 9810, 'ZZV810', null, 3::smallint, 'retired', null);
  begin
    perform public.admin_assign_vehicle(v_libre, v_a);
    insert into resultados values (13, 'Una unidad retirada NO se asigna',
      'VEHICLE_NOT_ACTIVE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'Una unidad retirada NO se asigna',
      'VEHICLE_NOT_ACTIVE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'VEHICLE_NOT_ACTIVE');
  end;

  -- 14. No se le cambia la unidad a quien esta a mitad de servicio.
  begin
    perform public.admin_assign_vehicle(v_ocupado, v_b);
    insert into resultados values (14, 'NO se cambia la unidad de quien va conduciendo',
      'ASSIGNMENT_HAS_ACTIVE_RIDE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (14, 'NO se cambia la unidad de quien va conduciendo',
      'ASSIGNMENT_HAS_ACTIVE_RIDE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'ASSIGNMENT_HAS_ACTIVE_RIDE');
  end;

  -- 15. Ni se le quita.
  begin
    perform public.admin_unassign_vehicle(v_ocupado);
    insert into resultados values (15, 'NO se le quita la unidad a quien va conduciendo',
      'ASSIGNMENT_HAS_ACTIVE_RIDE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (15, 'NO se le quita la unidad a quien va conduciendo',
      'ASSIGNMENT_HAS_ACTIVE_RIDE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'ASSIGNMENT_HAS_ACTIVE_RIDE');
  end;

  -- 16. Al que esta libre si se le quita, y queda registrado.
  perform public.admin_unassign_vehicle(v_libre);
  select count(*) into v_n
  from public.driver_vehicle_assignments
  where driver_id = v_libre and unassigned_at is null;
  insert into resultados values (16, 'Al conductor libre SI se le quita la unidad',
    '0', v_n::text, v_n = 0);

  -- 17. Quitar dos veces no tiene sentido y se dice.
  begin
    perform public.admin_unassign_vehicle(v_libre);
    insert into resultados values (17, 'Quitar una unidad que no tiene se rechaza',
      'NO_ASSIGNMENT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (17, 'Quitar una unidad que no tiene se rechaza',
      'NO_ASSIGNMENT', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NO_ASSIGNMENT');
  end;

  -- 18. El listado trae quien lleva cada unidad y si esta ocupada.
  --
  --     `drivers_label` y no `driver_name`: con el doble turno (D246) una unidad
  --     puede tener varios conductores, asi que la columna dejo de ser "el
  --     conductor" y paso a ser la lista de los que la comparten.
  select drivers_label, has_active_ride into v_row
  from public.admin_list_vehicles() where vehicle_id = v_veh_ocup;
  insert into resultados values (18, 'El listado trae el conductor y si va ocupada',
    'Zz veh ocupado, true',
    coalesce(v_row.drivers_label, 'nulo') || ', ' || v_row.has_active_ride::text,
    v_row.drivers_label = 'Zz veh ocupado' and v_row.has_active_ride);

  -- 19. Y una unidad sin conductor sale igual, con la lista vacia.
  select drivers_label, driver_count into v_row
  from public.admin_list_vehicles() where vehicle_id = v_b;
  insert into resultados values (19, 'Una unidad sin conductor sale, con el conductor vacio',
    'sin conductor, 0',
    case when v_row.drivers_label is null then 'sin conductor' else 'trae conductor' end
      || ', ' || v_row.driver_count::text,
    v_row.drivers_label is null and v_row.driver_count = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$asignar$;


-- -----------------------------------------------------------------------------
-- La escritura directa quedo cerrada
-- -----------------------------------------------------------------------------

do $directa$
declare
  v_admin constant uuid := 'af000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'af000000-0000-4000-8000-0000000000b1';
  v_libre constant uuid := 'af000000-0000-4000-8000-0000000000d1';
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 20. LA COMPROBACION QUE JUSTIFICA CERRAR LAS POLITICAS. Hasta esta
  --     migracion, `vehicles_all_admin` dejaba a un administrador crear una
  --     unidad con un INSERT directo, sin pasar por la funcion y por tanto sin
  --     auditoria. Es la tercera tabla en la que aparece el mismo hueco.
  begin
    insert into public.vehicles (unit_number, plate, max_passengers)
    values (9899, 'ZZV899', 3);
    insert into resultados values (20, 'Un INSERT directo de vehiculo YA NO pasa',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (20, 'Un INSERT directo de vehiculo YA NO pasa',
      'rechaza', sqlstate, true);
  end;

  -- 21. Ni un INSERT directo de asignacion, que es el que permitia poner a
  --     alguien al volante sin que constara quien lo decidio.
  begin
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (v_libre, 'af000000-0000-4000-8000-0000000000e1');
    insert into resultados values (21, 'Un INSERT directo de asignacion YA NO pasa',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (21, 'Un INSERT directo de asignacion YA NO pasa',
      'rechaza', sqlstate, true);
  end;

  -- 22. Pero el administrador SIGUE LEYENDO las asignaciones, que lo necesita el
  --     listado. Va con la 21 vigilandola: cerrar la escritura no puede haberse
  --     llevado por delante la lectura.
  select count(*) into v_n from public.driver_vehicle_assignments
  where driver_id::text like 'af000000%';
  insert into resultados values (22, 'El administrador sigue leyendo las asignaciones',
    'mas de 0', v_n::text, v_n > 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- -------------------------------------------------------------------------
  -- Como pasajero
  -- -------------------------------------------------------------------------
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 23. Un pasajero no crea vehiculos.
  begin
    perform public.admin_create_vehicle(9898, 'ZZV898', null, 3::smallint);
    insert into resultados values (23, 'Un pasajero NO puede crear vehiculos',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (23, 'Un pasajero NO puede crear vehiculos',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 24. Ni asigna.
  begin
    perform public.admin_assign_vehicle(v_libre, 'af000000-0000-4000-8000-0000000000e1');
    insert into resultados values (24, 'Un pasajero NO puede asignar vehiculos',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (24, 'Un pasajero NO puede asignar vehiculos',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 25. VE LA FLOTA -que ya ve por la calle, D86- PERO NO QUIEN LA CONDUCE. Es
  --     lo que hace `security invoker`: la lectura de `vehicles` esta abierta,
  --     la de las asignaciones no.
  select count(*) into v_n from public.admin_list_vehicles()
  where unit_number between 9800 and 9899 and drivers_label is not null;
  insert into resultados values (25, 'Un pasajero NO ve quien conduce cada unidad',
    '0', v_n::text, v_n = 0);

  -- 26. Y va con la 25 vigilandola: las unidades si las ve, asi que la 25 no
  --     esta en verde porque la funcion le devuelva cero filas.
  select count(*) into v_n from public.admin_list_vehicles()
  where unit_number between 9800 and 9899;
  insert into resultados values (26, 'Pero SI ve las unidades, asi que la anterior mide algo',
    'mas de 0', v_n::text, v_n > 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$directa$;


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
