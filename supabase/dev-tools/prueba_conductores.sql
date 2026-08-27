-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260826220000_admin_driver_management.sql` (Fase 20, paso 4a:
-- gestion de los conductores que ya existen).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_conductores.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- Se aisla por identificador propio: los conductores de esta prueba empiezan por
-- `ae000000`. Hay dos conductores reales en la base y toda comprobacion que
-- cuente filas tiene que filtrar, o cuenta los suyos.
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
-- Montaje: un administrador, tres conductores y un pasajero
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin   uuid := 'ae000000-0000-4000-8000-0000000000a1';
  v_pas     uuid := 'ae000000-0000-4000-8000-0000000000b1';
  v_aprob   uuid := 'ae000000-0000-4000-8000-0000000000d1';  -- aprobado, libre
  v_pend    uuid := 'ae000000-0000-4000-8000-0000000000d2';  -- pendiente
  v_ocupado uuid := 'ae000000-0000-4000-8000-0000000000d3';  -- aprobado, con viaje
  v_veh     uuid := 'ae000000-0000-4000-8000-0000000000e1';
  v_req     uuid := 'ae000000-0000-4000-8000-000000000001';
  v_lng double precision;
  v_lat double precision;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.cond.admin@motomoto-qa.co', now(), now()),
    (v_pas,     '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.cond.pas@motomoto-qa.co', now(), now()),
    (v_aprob,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.cond.aprobado@motomoto-qa.co', now(), now()),
    (v_pend,    '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.cond.pendiente@motomoto-qa.co', now(), now()),
    (v_ocupado, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.cond.ocupado@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas, v_aprob, v_pend, v_ocupado);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin,   'Zz cond admin',     '3000000031', 'admin',     'active'),
    (v_pas,     'Zz cond pasajero',  '3000000032', 'passenger', 'active'),
    (v_aprob,   'Zz cond aprobado',  '3000000033', 'driver',    'active'),
    (v_pend,    'Zz cond pendiente', '3000000034', 'driver',    'active'),
    (v_ocupado, 'Zz cond ocupado',   '3000000035', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available) values
    (v_aprob,   'approved', now(), true),
    (v_pend,    'pending',  null,  false),
    (v_ocupado, 'approved', now(), true);

  insert into public.vehicles (id, unit_number, plate, model, max_passengers, status)
  values (v_veh, 9901, 'ZZP901', 'Motorraton de prueba 4a', 3, 'active');

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
  values (v_aprob, v_veh);

  -- Al ocupado se le monta un servicio en marcha, que es lo que hace falta para
  -- comprobar que no se le puede retirar la aprobacion a mitad de viaje.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  ) values (
    v_req, v_pas, 'in_progress', 1,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz origen',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz destino', '3000000032', now() - interval '5 minutes', now() + interval '10 minutes',
    'passenger', 4000, 4000, 0, false, false
  );

  insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at)
  values ('ae000000-0000-4000-8000-00000000c001', v_req, v_ocupado, v_veh, 'in_progress', 1,
          now() - interval '4 minutes');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- El listado
-- -----------------------------------------------------------------------------

do $listado$
declare
  v_admin   constant uuid := 'ae000000-0000-4000-8000-0000000000a1';
  v_aprob   constant uuid := 'ae000000-0000-4000-8000-0000000000d1';
  v_pend    constant uuid := 'ae000000-0000-4000-8000-0000000000d2';
  v_ocupado constant uuid := 'ae000000-0000-4000-8000-0000000000d3';
  v_n integer;
  v_row record;
  v_primero uuid;
  v_ocupacion text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Salen los tres conductores de la prueba.
  select count(*) into v_n from public.admin_list_drivers()
  where driver_id::text like 'ae000000%';
  insert into resultados values (1, 'El listado trae los conductores',
    '3', v_n::text, v_n = 3);

  -- 2. El que tiene vehiculo asignado trae su numero y su placa.
  select unit_number, plate, approval_status::text into v_row
  from public.admin_list_drivers() where driver_id = v_aprob;
  insert into resultados values (2, 'Trae el motorraton asignado',
    '9901, ZZP901, approved',
    coalesce(v_row.unit_number::text, 'nulo') || ', ' || coalesce(v_row.plate, 'nulo') ||
      ', ' || coalesce(v_row.approval_status, 'nulo'),
    v_row.unit_number = 9901 and v_row.plate = 'ZZP901' and v_row.approval_status = 'approved');

  -- 3. El que no tiene vehiculo sale igual, con el vehiculo en nulo. Un
  --    conductor sin motorraton es un caso real y el panel tiene que verlo para
  --    poder arreglarlo, no esconderlo.
  select unit_number, plate into v_row
  from public.admin_list_drivers() where driver_id = v_pend;
  insert into resultados values (3, 'Un conductor sin vehiculo sale, con el vehiculo vacio',
    'sin numero, sin placa',
    case when v_row.unit_number is null then 'sin numero' else 'trae numero' end || ', ' ||
      case when v_row.plate is null then 'sin placa' else 'trae placa' end,
    v_row.unit_number is null and v_row.plate is null);

  -- 4. Se sabe quien esta ocupado y quien no. Es el dato que decide si se puede
  --    retirar una aprobacion sin dejar a un pasajero tirado.
  select
    (select has_active_ride from public.admin_list_drivers() where driver_id = v_ocupado)::text
    || ', ' ||
    (select has_active_ride from public.admin_list_drivers() where driver_id = v_aprob)::text
  into v_ocupacion;
  insert into resultados values (4, 'Distingue al que va conduciendo del que esta libre',
    'true, false', coalesce(v_ocupacion, 'nulo'), v_ocupacion = 'true, false');

  -- 5. Los pendientes de aprobar salen primero: son los que esperan una decision.
  select driver_id into v_primero from public.admin_list_drivers()
  where driver_id::text like 'ae000000%' limit 1;
  insert into resultados values (5, 'Los pendientes de aprobar salen los primeros',
    v_pend::text, coalesce(v_primero::text, 'nulo'), v_primero = v_pend);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$listado$;


-- -----------------------------------------------------------------------------
-- Aprobar y retirar la aprobacion
-- -----------------------------------------------------------------------------

do $aprobacion$
declare
  v_admin   constant uuid := 'ae000000-0000-4000-8000-0000000000a1';
  v_aprob   constant uuid := 'ae000000-0000-4000-8000-0000000000d1';
  v_pend    constant uuid := 'ae000000-0000-4000-8000-0000000000d2';
  v_ocupado constant uuid := 'ae000000-0000-4000-8000-0000000000d3';
  v_row record;
  v_n integer;
  v_h text;
  v_disponible boolean;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 6. Aprobar a uno pendiente lo deja aprobado, con fecha y con autor.
  perform public.admin_set_driver_approval(v_pend, 'approved', 'Papeles en regla');

  select approval_status::text, approved_at is not null as con_fecha, approved_by
    into v_row
  from public.drivers where id = v_pend;
  insert into resultados values (6, 'Aprobar deja el estado, la fecha y quien aprobo',
    'approved, con fecha, ' || v_admin::text,
    coalesce(v_row.approval_status, 'nulo') || ', ' ||
      case when v_row.con_fecha then 'con fecha' else 'sin fecha' end || ', ' ||
      coalesce(v_row.approved_by::text, 'nulo'),
    v_row.approval_status = 'approved' and v_row.con_fecha and v_row.approved_by = v_admin);

  -- 7. Y deja auditoria, que es lo que hoy no pasaba.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_pend::text and action = 'approve_driver';
  insert into resultados values (7, 'Aprobar deja una entrada de auditoria',
    '1', v_n::text, v_n = 1);

  -- 8. Retirar la aprobacion a uno libre funciona Y LO DEJA NO DISPONIBLE. Sin
  --    apagar la disponibilidad, la restriccion
  --    `drivers_available_only_when_approved` haria fallar la operacion entera.
  perform public.admin_set_driver_approval(v_aprob, 'blocked', 'Prueba');

  select approval_status::text, is_available, approved_at is not null as con_fecha
    into v_row
  from public.drivers where id = v_aprob;
  insert into resultados values (8, 'Retirar la aprobacion apaga la disponibilidad',
    'blocked, false, con fecha',
    coalesce(v_row.approval_status, 'nulo') || ', ' || v_row.is_available::text || ', ' ||
      case when v_row.con_fecha then 'con fecha' else 'sin fecha' end,
    v_row.approval_status = 'blocked' and v_row.is_available = false and v_row.con_fecha);

  -- 9. LA REGLA QUE RESPONDE A D216. No se retira la aprobacion a quien va
  --    conduciendo: dejar a un pasajero dentro de un motorraton cuyo conductor
  --    acaba de perder el permiso no arregla nada.
  begin
    perform public.admin_set_driver_approval(v_ocupado, 'blocked', 'A mitad de viaje');
    insert into resultados values (9, 'NO se retira la aprobacion a quien va conduciendo',
      'DRIVER_HAS_ACTIVE_RIDE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (9, 'NO se retira la aprobacion a quien va conduciendo',
      'DRIVER_HAS_ACTIVE_RIDE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'DRIVER_HAS_ACTIVE_RIDE');
  end;

  -- 10. LO QUE SE BLOQUEA ES RETIRAR LA APROBACION, NO TOCAR A ESE CONDUCTOR.
  --     Al mismo conductor ocupado si se le puede corregir el contacto. Va con
  --     la 9 vigilandola por un lado -y la 8 por el otro, que retira la
  --     aprobacion a uno libre sin problema-: entre las tres queda claro que el
  --     rechazo de la 9 es por el viaje en marcha y no porque la funcion
  --     rechace todo lo que toque a ese conductor.
  --
  --     La primera version de esta comprobacion intentaba APROBARLO, y estaba
  --     mal pensada: `pending` tambien es retirar la aprobacion, asi que la
  --     regla la rechazaba con razon.
  perform public.admin_update_driver_contact(v_ocupado, 'Zz cond ocupado', '3444444444');
  select phone into v_row from public.profiles where id = v_ocupado;
  insert into resultados values (10, 'A quien conduce SI se le puede corregir el contacto',
    '3444444444', coalesce(v_row.phone, 'nulo'), v_row.phone = '3444444444');

  -- 11. Sin cambio no hay accion.
  begin
    perform public.admin_set_driver_approval(v_ocupado, 'approved', null);  -- ya lo esta
    insert into resultados values (11, 'Poner el estado que ya tenia se rechaza',
      'APPROVAL_UNCHANGED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (11, 'Poner el estado que ya tenia se rechaza',
      'APPROVAL_UNCHANGED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'APPROVAL_UNCHANGED');
  end;

  -- 12. Un conductor que no existe.
  begin
    perform public.admin_set_driver_approval(
      'ae000000-0000-4000-8000-0000000000ff'::uuid, 'approved', null);
    insert into resultados values (12, 'Un conductor inexistente se rechaza',
      'DRIVER_NOT_FOUND', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'Un conductor inexistente se rechaza',
      'DRIVER_NOT_FOUND', coalesce(nullif(v_h, ''), sqlstate), v_h = 'DRIVER_NOT_FOUND');
  end;

  -- 13. EL MISMO HUECO DEL PASO 2, MEDIDO EN ESTA TABLA. Un administrador
  --     intenta aprobar con UPDATE directo. Hasta esta migracion lo conseguia,
  --     porque `protect_driver_columns` empezaba por "si es administrador, puede
  --     cambiar cualquier cosa", y la auditoria se quedaba vacia.
  update public.drivers set approval_status = 'approved' where id = v_aprob;
  select approval_status::text into v_row from public.drivers where id = v_aprob;
  insert into resultados values (13,
    'Un UPDATE directo de la aprobacion NO surte efecto ni siendo administrador',
    'blocked', coalesce(v_row.approval_status, 'nulo'), v_row.approval_status = 'blocked');

  -- 13b. **LA POLITICA DE ESCRITURA DIRECTA, QUE SE QUEDO ABIERTA HASTA EL PASO
  --      6b.** En el 4a se apreto el disparador pero no se cerro
  --      `drivers_all_admin`, y el disparador solo protege cinco columnas: se
  --      podia poner o quitar de servicio a cualquier conductor -o borrarle la
  --      ficha- sin dejar rastro. No lo encontro ninguna prueba, sino comprobar
  --      que politicas `for all` quedaban vivas.
  begin
    update public.drivers set is_available = true where id = v_aprob;
    select is_available into v_disponible from public.drivers where id = v_aprob;
    insert into resultados values (25,
      'Un administrador NO cambia la disponibilidad con UPDATE directo',
      'false', v_disponible::text, v_disponible = false);
  exception when others then
    insert into resultados values (25,
      'Un administrador NO cambia la disponibilidad con UPDATE directo',
      'false', 'rechazado: ' || sqlstate, true);
  end;

  -- 13c. Ni borra una ficha de conductor.
  begin
    delete from public.drivers where id = v_aprob;
    select count(*) into v_n from public.drivers where id = v_aprob;
    insert into resultados values (26, 'Un administrador NO borra una ficha de conductor',
      '1', v_n::text, v_n = 1);
  exception when others then
    insert into resultados values (26, 'Un administrador NO borra una ficha de conductor',
      '1', 'rechazado: ' || sqlstate, true);
  end;

  -- 14. Y tampoco se sube la calificacion a mano, que es la otra mitad de lo que
  --     ese disparador protege.
  update public.drivers set rating_average = 5, rating_count = 999 where id = v_aprob;
  select rating_count into v_n from public.drivers where id = v_aprob;
  insert into resultados values (14, 'Un UPDATE directo de la calificacion tampoco pasa',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$aprobacion$;


-- -----------------------------------------------------------------------------
-- Editar los datos de contacto
-- -----------------------------------------------------------------------------

do $contacto$
declare
  v_admin constant uuid := 'ae000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'ae000000-0000-4000-8000-0000000000b1';
  v_pend  constant uuid := 'ae000000-0000-4000-8000-0000000000d2';
  v_row record;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 15. Se corrige nombre y telefono, y queda registrado con lo que habia antes.
  perform public.admin_update_driver_contact(v_pend, '  Zz cond corregido  ', '3111111111');

  select full_name, phone into v_row from public.profiles where id = v_pend;
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_pend::text and action = 'update_driver_contact';

  insert into resultados values (15, 'Corrige el contacto, recorta espacios y lo registra',
    'Zz cond corregido, 3111111111, 1',
    coalesce(v_row.full_name, 'nulo') || ', ' || coalesce(v_row.phone, 'nulo') || ', ' || v_n::text,
    v_row.full_name = 'Zz cond corregido' and v_row.phone = '3111111111' and v_n = 1);

  -- 16. Un telefono que no es un celular colombiano se rechaza. La validacion se
  --     repite en el servidor porque esta funcion se salta el cliente entero.
  begin
    perform public.admin_update_driver_contact(v_pend, 'Zz cond corregido', '123');
    insert into resultados values (16, 'Un telefono invalido se rechaza',
      'INVALID_PHONE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (16, 'Un telefono invalido se rechaza',
      'INVALID_PHONE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_PHONE');
  end;

  -- 17. Un nombre demasiado corto tambien.
  begin
    perform public.admin_update_driver_contact(v_pend, 'Zz', '3111111111');
    insert into resultados values (17, 'Un nombre demasiado corto se rechaza',
      'NAME_TOO_SHORT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (17, 'Un nombre demasiado corto se rechaza',
      'NAME_TOO_SHORT', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NAME_TOO_SHORT');
  end;

  -- 18. LA PUERTA LATERAL QUE SE CIERRA. Esta funcion es la de los conductores;
  --     si dejara editar cualquier perfil, seria una via para tocar los datos de
  --     un pasajero -o de otro administrador- sin que el nombre de la accion lo
  --     dijera, y la auditoria diria "update_driver_contact" sobre alguien que
  --     no es conductor.
  begin
    perform public.admin_update_driver_contact(v_pas, 'Zz otro nombre', '3111111112');
    insert into resultados values (18, 'NO se puede editar a un pasajero por esta via',
      'NOT_A_DRIVER', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (18, 'NO se puede editar a un pasajero por esta via',
      'NOT_A_DRIVER', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_A_DRIVER');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$contacto$;


-- -----------------------------------------------------------------------------
-- Lo que no puede hacer quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_pas   constant uuid := 'ae000000-0000-4000-8000-0000000000b1';
  v_pend  constant uuid := 'ae000000-0000-4000-8000-0000000000d2';
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 19. Un pasajero no aprueba conductores.
  begin
    perform public.admin_set_driver_approval(v_pend, 'blocked', null);
    insert into resultados values (19, 'Un pasajero NO puede cambiar aprobaciones',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (19, 'Un pasajero NO puede cambiar aprobaciones',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 20. Ni edita los datos de un conductor.
  begin
    perform public.admin_update_driver_contact(v_pend, 'Zz secuestrado', '3222222222');
    insert into resultados values (20, 'Un pasajero NO puede editar a un conductor',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (20, 'Un pasajero NO puede editar a un conductor',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 21. El listado es `security invoker` (D242): un pasajero puede llamarlo,
  --     pero las politicas se aplican con SU identidad, asi que NO ve la flota.
  --
  --     VE EXACTAMENTE UNO: el conductor de su propio viaje en curso. No es un
  --     fallo, es `drivers_select_ride_counterpart` de la Fase 5, que existe
  --     para que el pasajero pueda ver la calificacion de quien lo lleva.
  --
  --     **La primera version de esta comprobacion esperaba cero y se puso roja.
  --     La equivocada era la expectativa, no el codigo**, igual que le paso a la
  --     comprobacion 57 de prueba_calculo_tarifa con D234. Escrita asi mide algo
  --     mejor que "no ve nada": mide que ve SOLO al suyo.
  select count(*) into v_n from public.admin_list_drivers()
  where driver_id::text like 'ae000000%';
  insert into resultados values (21, 'Un pasajero solo ve al conductor de su propio viaje',
    '1', v_n::text, v_n = 1);

  -- 21b. Y para que la anterior no quede en verde por casualidad, se comprueba
  --      CUAL es el que ve: el de su viaje, no otro cualquiera.
  select count(*) into v_n from public.admin_list_drivers()
  where driver_id = 'ae000000-0000-4000-8000-0000000000d3';
  insert into resultados values (23, 'Y el que ve es justo el conductor que lo lleva',
    '1', v_n::text, v_n = 1);

  -- 21c. A los otros dos conductores, que no tienen nada que ver con el, no los
  --      ve. Esta es la que de verdad prueba que no hay fuga de la flota.
  select count(*) into v_n from public.admin_list_drivers()
  where driver_id in ('ae000000-0000-4000-8000-0000000000d1',
                      'ae000000-0000-4000-8000-0000000000d2');
  insert into resultados values (24, 'NO ve a los conductores con los que no tiene viaje',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 22. Sin sesion, nada.
  execute 'set local role anon';
  begin
    perform public.admin_set_driver_approval(v_pend, 'blocked', null);
    insert into resultados values (22, 'Sin sesion NO se cambian aprobaciones',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (22, 'Sin sesion NO se cambian aprobaciones',
      'rechaza', sqlstate, true);
  end;
  execute 'reset role';
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
  case when bool_and(x.ok) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not x.ok) || ' fallando'
from resultados x
order by 1;

rollback;
