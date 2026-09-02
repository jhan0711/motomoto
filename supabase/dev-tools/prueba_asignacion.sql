-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260828070000_admin_assign_driver.sql` (Fase 20, paso 9:
-- asignacion manual de conductor, D7).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_asignacion.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- **ESTA FUNCION ESCRIBE EN LA OPERACION**, no en un catalogo: crea un viaje,
-- cambia el estado de una solicitud y apaga la disponibilidad de un conductor.
-- Por eso la mitad de las comprobaciones no miran que funcione, sino **que no se
-- pueda usar donde no debe**: sobre una solicitud ya tomada, vencida, con un
-- conductor sin aprobar, bloqueado, sin motorraton, ya ocupado, o cuyo companero
-- de turno esta conectado.
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
-- Montaje: conductores en cada situacion posible
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin uuid := 'b8000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'b8000000-0000-4000-8000-0000000000b1';
  v_pas2  uuid := 'b8000000-0000-4000-8000-0000000000b2';
  v_pas3  uuid := 'b8000000-0000-4000-8000-0000000000b3';

  v_bueno    uuid := 'b8000000-0000-4000-8000-0000000000d1';  -- asignable
  v_pendiente uuid := 'b8000000-0000-4000-8000-0000000000d2'; -- sin aprobar
  v_sin_veh  uuid := 'b8000000-0000-4000-8000-0000000000d3';  -- sin motorraton
  v_ocupado  uuid := 'b8000000-0000-4000-8000-0000000000d4';  -- con viaje encima
  v_companero uuid := 'b8000000-0000-4000-8000-0000000000d5'; -- comparte unidad

  v_veh    uuid := 'b8000000-0000-4000-8000-0000000000e1';
  v_veh2   uuid := 'b8000000-0000-4000-8000-0000000000e2';
  v_veh_p  uuid := 'b8000000-0000-4000-8000-0000000000e3';  -- pequeno, 1 plaza

  v_buscando uuid := 'b8000000-0000-4000-8000-000000000001';
  v_vencido  uuid := 'b8000000-0000-4000-8000-000000000002';
  v_tomado   uuid := 'b8000000-0000-4000-8000-000000000003';
  v_lng double precision;
  v_lat double precision;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  select x.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         x.correo, now(), now()
  from (values
    (v_admin, 'zz.asig.admin@motomoto-qa.co'), (v_pas, 'zz.asig.pas@motomoto-qa.co'),
    (v_pas2, 'zz.asig.pas2@motomoto-qa.co'),  (v_pas3, 'zz.asig.pas3@motomoto-qa.co'),
    (v_bueno, 'zz.asig.bueno@motomoto-qa.co'), (v_pendiente, 'zz.asig.pend@motomoto-qa.co'),
    (v_sin_veh, 'zz.asig.sinveh@motomoto-qa.co'), (v_ocupado, 'zz.asig.ocup@motomoto-qa.co'),
    (v_companero, 'zz.asig.comp@motomoto-qa.co')
  ) as x(id, correo);

  delete from public.profiles where id::text like 'b8000000%';
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin,     'Zz asig admin',     '3000000121', 'admin',     'active'),
    (v_pas,       'Zz asig pasajero',  '3000000122', 'passenger', 'active'),
    (v_pas2,      'Zz asig pasajero2', '3000000123', 'passenger', 'active'),
    (v_pas3,      'Zz asig pasajero3', '3000000124', 'passenger', 'active'),
    (v_bueno,     'Zz asig bueno',     '3000000125', 'driver',    'active'),
    (v_pendiente, 'Zz asig pendiente', '3000000126', 'driver',    'active'),
    (v_sin_veh,   'Zz asig sin veh',   '3000000127', 'driver',    'active'),
    (v_ocupado,   'Zz asig ocupado',   '3000000128', 'driver',    'active'),
    (v_companero, 'Zz asig companero', '3000000129', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available) values
    (v_bueno,     'approved', now(), false),   -- desconectado a proposito (D256)
    (v_pendiente, 'pending',  null,  false),
    (v_sin_veh,   'approved', now(), true),
    (v_ocupado,   'approved', now(), true),
    (v_companero, 'approved', now(), false);

  insert into public.vehicles (id, unit_number, plate, max_passengers, status) values
    (v_veh,   9870, 'ZZG870', 3, 'active'),
    (v_veh2,  9871, 'ZZG871', 3, 'active'),
    (v_veh_p, 9872, 'ZZG872', 1, 'active');

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id) values
    (v_bueno, v_veh),
    (v_ocupado, v_veh2),
    -- El companero comparte la unidad del bueno: es el doble turno de D246.
    (v_companero, v_veh);

  -- Tres solicitudes: una viva, una vencida y una ya tomada.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  )
  select
    x.id, x.pas, x.est, 2,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz asig origen',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz asig destino', '3000000122', x.pedido, x.vence,
    'passenger', 6200, 6200, 0, false, false
  from (values
    (v_buscando, v_pas,  'searching'::public.ride_request_status,
     now() - interval '2 minutes', now() + interval '10 minutes'),
    (v_vencido,  v_pas2, 'searching'::public.ride_request_status,
     now() - interval '30 minutes', now() - interval '25 minutes'),
    (v_tomado,   v_pas3, 'assigned'::public.ride_request_status,
     now() - interval '5 minutes', now() + interval '10 minutes')
  ) as x(id, pas, est, pedido, vence);

  -- El ocupado esta metido en el servicio ya tomado.
  insert into public.rides (request_id, driver_id, vehicle_id, status, passenger_count, accepted_at)
  values (v_tomado, v_ocupado, v_veh2, 'assigned', 2, now() - interval '4 minutes');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- A quien se puede asignar
-- -----------------------------------------------------------------------------

do $candidatos$
declare
  v_admin  constant uuid := 'b8000000-0000-4000-8000-0000000000a1';
  v_buscando constant uuid := 'b8000000-0000-4000-8000-000000000001';
  v_bueno  constant uuid := 'b8000000-0000-4000-8000-0000000000d1';
  v_sin_veh constant uuid := 'b8000000-0000-4000-8000-0000000000d3';
  v_ocupado constant uuid := 'b8000000-0000-4000-8000-0000000000d4';
  v_pendiente constant uuid := 'b8000000-0000-4000-8000-0000000000d2';
  v_row record;
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. **EL QUE NO ESTA APROBADO NO SALE SIQUIERA.** No es que no se pueda
  --    asignar: es que no es un conductor de la empresa todavia.
  select count(*) into v_n from public.admin_list_assignable_drivers(v_buscando)
  where driver_id = v_pendiente;
  insert into resultados values (1, 'Un conductor sin aprobar no aparece en la lista',
    '0', v_n::text, v_n = 0);

  -- 2. **LOS QUE NO SE PUEDEN ASIGNAR SI SALEN, CON SU MOTIVO.** Esconderlos
  --    haria que el administrador se preguntara donde esta alguien que sabe que
  --    existe.
  select can_assign, blocked_reason into v_row
  from public.admin_list_assignable_drivers(v_buscando) where driver_id = v_sin_veh;
  insert into resultados values (2, 'El que no tiene motorraton sale, apagado y con su motivo',
    'false, Sin motorraton activo asignado',
    coalesce(v_row.can_assign::text, 'nulo') || ', ' || coalesce(v_row.blocked_reason, 'nulo'),
    v_row.can_assign = false and v_row.blocked_reason = 'Sin motorraton activo asignado');

  -- 3. Y el que ya lleva un servicio, igual.
  select can_assign, blocked_reason into v_row
  from public.admin_list_assignable_drivers(v_buscando) where driver_id = v_ocupado;
  insert into resultados values (3, 'El que ya tiene un servicio sale con su motivo',
    'false, Ya tiene un servicio en curso',
    coalesce(v_row.can_assign::text, 'nulo') || ', ' || coalesce(v_row.blocked_reason, 'nulo'),
    v_row.can_assign = false and v_row.blocked_reason = 'Ya tiene un servicio en curso');

  -- 4. **EL BUENO SE PUEDE ASIGNAR AUNQUE ESTE DESCONECTADO (D256).** Es el
  --    punto entero de la anulacion manual: si bastara con los conectados,
  --    bastaria con el reparto automatico.
  select can_assign, is_available into v_row
  from public.admin_list_assignable_drivers(v_buscando) where driver_id = v_bueno;
  insert into resultados values (4, 'Un conductor desconectado SI se puede asignar',
    'true, false',
    coalesce(v_row.can_assign::text, 'nulo') || ', ' || coalesce(v_row.is_available::text, 'nulo'),
    v_row.can_assign and not v_row.is_available);

  -- 5. Los asignables van primero en la lista.
  select can_assign into v_row
  from public.admin_list_assignable_drivers(v_buscando) limit 1;
  insert into resultados values (5, 'Los asignables salen antes que los que no',
    'true', coalesce(v_row.can_assign::text, 'nulo'), v_row.can_assign);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$candidatos$;


-- -----------------------------------------------------------------------------
-- La asignacion
-- -----------------------------------------------------------------------------

do $asignar$
declare
  v_admin  constant uuid := 'b8000000-0000-4000-8000-0000000000a1';
  v_buscando constant uuid := 'b8000000-0000-4000-8000-000000000001';
  v_vencido  constant uuid := 'b8000000-0000-4000-8000-000000000002';
  v_tomado   constant uuid := 'b8000000-0000-4000-8000-000000000003';
  v_bueno  constant uuid := 'b8000000-0000-4000-8000-0000000000d1';
  v_sin_veh constant uuid := 'b8000000-0000-4000-8000-0000000000d3';
  v_pendiente constant uuid := 'b8000000-0000-4000-8000-0000000000d2';
  v_ride uuid;
  v_row record;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 6. Una solicitud vencida no se asigna: el pasajero ya la dio por perdida.
  begin
    perform public.admin_assign_driver(v_vencido, v_bueno, 'Prueba');
    insert into resultados values (6, 'Una solicitud vencida NO se asigna',
      'REQUEST_EXPIRED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Una solicitud vencida NO se asigna',
      'REQUEST_EXPIRED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'REQUEST_EXPIRED');
  end;

  -- 7. Ni una que ya tomo otro.
  begin
    perform public.admin_assign_driver(v_tomado, v_bueno, 'Prueba');
    insert into resultados values (7, 'Una solicitud ya asignada NO se reasigna',
      'REQUEST_NOT_SEARCHING', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Una solicitud ya asignada NO se reasigna',
      'REQUEST_NOT_SEARCHING', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'REQUEST_NOT_SEARCHING');
  end;

  -- 8. Ni a un conductor sin aprobar.
  begin
    perform public.admin_assign_driver(v_buscando, v_pendiente, 'Prueba');
    insert into resultados values (8, 'No se asigna a un conductor sin aprobar',
      'DRIVER_NOT_APPROVED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'No se asigna a un conductor sin aprobar',
      'DRIVER_NOT_APPROVED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'DRIVER_NOT_APPROVED');
  end;

  -- 9. Ni a uno sin motorraton.
  begin
    perform public.admin_assign_driver(v_buscando, v_sin_veh, 'Prueba');
    insert into resultados values (9, 'No se asigna a un conductor sin motorraton',
      'NO_VEHICLE_ASSIGNED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (9, 'No se asigna a un conductor sin motorraton',
      'NO_VEHICLE_ASSIGNED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NO_VEHICLE_ASSIGNED');
  end;

  -- 10. **LA ASIGNACION QUE SI FUNCIONA.** Va vigilando a las cuatro anteriores:
  --     sin esta, todas podrian estar en verde porque la funcion rechaza todo.
  v_ride := public.admin_assign_driver(v_buscando, v_bueno, 'Nadie la tomo y el pasajero espera');
  select status::text, assigned_at is not null as con_fecha into v_row
  from public.ride_requests where id = v_buscando;
  insert into resultados values (10, 'La asignacion manual deja la solicitud asignada',
    'assigned, con fecha',
    coalesce(v_row.status, 'nulo') || ', ' ||
      case when v_row.con_fecha then 'con fecha' else 'sin fecha' end,
    v_row.status = 'assigned' and v_row.con_fecha);

  -- 11. Y crea el viaje con su conductor y su motorraton.
  select driver_id, vehicle_id is not null as con_vehiculo, passenger_count into v_row
  from public.rides where id = v_ride;
  insert into resultados values (11, 'Crea el viaje con el conductor y el motorraton',
    v_bueno::text || ', con vehiculo, 2',
    coalesce(v_row.driver_id::text, 'nulo') || ', ' ||
      case when v_row.con_vehiculo then 'con vehiculo' else 'sin vehiculo' end || ', ' ||
      coalesce(v_row.passenger_count::text, 'nulo'),
    v_row.driver_id = v_bueno and v_row.con_vehiculo and v_row.passenger_count = 2);

  -- 12. **CREA LA OFERTA ACEPTADA, y eso no es un detalle.** El historial del
  --     conductor sale de `ride_offers` y no de `rides` (D196): sin esta fila, el
  --     servicio no le apareceria nunca en su historial.
  select count(*) into v_n from public.ride_offers
  where request_id = v_buscando and driver_id = v_bueno and response = 'accepted';
  insert into resultados values (12, 'Deja la oferta aceptada, para que salga en su historial',
    '1', v_n::text, v_n = 1);

  -- 13. Y lo deja no disponible, igual que si hubiera aceptado el solo.
  select is_available into v_row from public.drivers where id = v_bueno;
  insert into resultados values (13, 'El conductor queda no disponible',
    'false', coalesce(v_row.is_available::text, 'nulo'), v_row.is_available = false);

  -- 14. Queda en la auditoria, con el motivo y con quien.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_buscando::text and action = 'assign_driver'
    and after_data->>'driver_id' = v_bueno::text
    and after_data->>'reason' = 'Nadie la tomo y el pasajero espera';
  insert into resultados values (14, 'La asignacion queda registrada con su motivo',
    '1', v_n::text, v_n = 1);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 15 y 16 SE MIRAN SIN EL ROL DEL ADMIN, Y NO ES UN ATAJO: `notifications`
  -- solo tiene la politica `notifications_select_own`, asi que **el admin no ve
  -- las notificaciones del conductor** ni debe verlas. Preguntadas con su rol
  -- las dos daban cero, que es lo que hizo que la 15 dijera FALLA cuando el
  -- aviso si se estaba mandando. Se preguntan con el rol privilegiado, igual
  -- que `auth.users` en `prueba_alta_conductor`.

  -- 15. **EL AVISO AL CONDUCTOR DICE LO QUE PASA DE VERDAD.** El disparador de
  --     ofertas nuevas habria dicho "tienes un servicio disponible cerca de ti",
  --     que aqui seria mentira: no hay nada que aceptar.
  select type, title into v_row from public.notifications
  where user_id = v_bueno order by created_at desc limit 1;
  insert into resultados values (15, 'Se avisa al conductor con el texto correcto',
    'admin_assigned, La empresa te asigno un servicio',
    coalesce(v_row.type, 'nulo') || ', ' || coalesce(v_row.title, 'nulo'),
    coalesce(v_row.type = 'admin_assigned' and v_row.title = 'La empresa te asigno un servicio', false));

  -- 16. Y NO se le mando ademas el aviso de oferta nueva. Va con la 15
  --     vigilandola: sin esta, podrian estar llegando los dos.
  select count(*) into v_n from public.notifications
  where user_id = v_bueno and type = 'new_offer'
    and data->>'offerId' in (select id::text from public.ride_offers where request_id = v_buscando);
  insert into resultados values (16, 'No se manda ademas el aviso de oferta nueva',
    '0', v_n::text, v_n = 0);
end
$asignar$;


-- -----------------------------------------------------------------------------
-- El companero de turno y quien no es administrador
-- -----------------------------------------------------------------------------

do $resto$
declare
  v_admin constant uuid := 'b8000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'b8000000-0000-4000-8000-0000000000b1';
  v_companero constant uuid := 'b8000000-0000-4000-8000-0000000000d5';
  v_bueno constant uuid := 'b8000000-0000-4000-8000-0000000000d1';
  v_lng double precision;
  v_lat double precision;
  v_nueva uuid := 'b8000000-0000-4000-8000-000000000009';
  v_pas4  uuid := 'b8000000-0000-4000-8000-0000000000b4';
  v_h text;
begin
  -- Un pasajero propio para esta solicitud: los tres del montaje ya tienen una
  -- viva o asignada, y R6 no admite dos.
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  values (v_pas4, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'zz.asig.pas4@motomoto-qa.co', now(), now());
  delete from public.profiles where id = v_pas4;
  insert into public.profiles (id, full_name, phone, role, status)
  values (v_pas4, 'Zz asig pasajero4', '3000000130', 'passenger', 'active');

  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  -- Una solicitud nueva, porque la anterior ya se asigno.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  ) values (
    -- El TERCER pasajero, no el segundo: el segundo tiene la solicitud vencida
    -- del montaje, que sigue en `searching`, y R6 solo admite una viva por
    -- persona. El tercero tiene la suya ya asignada, asi que tampoco vale...
    -- por eso esta prueba usa uno propio, creado aqui.
    v_nueva, 'b8000000-0000-4000-8000-0000000000b4'::uuid, 'searching', 1,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz asig origen dos',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz asig destino dos', '3000000130', now(), now() + interval '10 minutes',
    'passenger', 4000, 4000, 0, false, false
  );

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 17. **EL DOBLE TURNO (D246) SE RESPETA TAMBIEN AQUI.** El companero comparte
  --     la unidad del bueno, que ahora esta en un servicio. Asignarle a el
  --     pondria dos personas trabajando con un solo motorraton.
  --
  --     El bueno quedo no disponible al asignarle, asi que se le vuelve a
  --     conectar para reproducir el caso: dos con la misma unidad, uno conectado.
  execute 'reset role';
  update public.drivers set is_available = true where id = v_bueno;
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  begin
    perform public.admin_assign_driver(v_nueva, v_companero, 'Prueba');
    insert into resultados values (17, 'No se asigna si su companero de turno esta conectado',
      'COMPANION_ALREADY_AVAILABLE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (17, 'No se asigna si su companero de turno esta conectado',
      'COMPANION_ALREADY_AVAILABLE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'COMPANION_ALREADY_AVAILABLE');
  end;

  -- 20. **Y LA LISTA TIENE QUE DECIRLO ANTES**, que es lo que fallaba.
  --     La 17 comprueba que `admin_assign_driver` lo rechaza; esta comprueba que
  --     `admin_list_assignable_drivers` **no lo ofrece siquiera**. Sin esta, las
  --     dos funciones se contradecian: el usuario lo encontro en la pantalla el
  --     2026-09-01, eligiendo a alguien que la lista daba por bueno y que la
  --     asignacion despues rechazaba.
  --
  --     Se mira en este punto exacto a proposito: es el mismo escenario que
  --     acaba de rechazar la 17, con el companero conectado.
  declare v_ca boolean; v_mot text;
  begin
    select can_assign, blocked_reason into v_ca, v_mot
    from public.admin_list_assignable_drivers(v_nueva) where driver_id = v_companero;
    insert into resultados values (20,
      'La lista tampoco lo ofrece, y dice quien tiene la unidad',
      'false, nombra al companero',
      coalesce(v_ca::text, 'nulo') || ', ' || coalesce(v_mot, 'nulo'),
      coalesce(v_ca = false and v_mot like '%esta conectado con el motorraton%', false));
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 18. Un pasajero no asigna conductores. Si pudiera, se elegiria el suyo.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);
  begin
    perform public.admin_assign_driver(v_nueva, v_bueno, 'Prueba');
    insert into resultados values (18, 'Un pasajero NO puede asignar conductores',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (18, 'Un pasajero NO puede asignar conductores',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 19. Ni ve la lista de candidatos: saber que conductores hay y donde estan es
  --     informacion de la empresa.
  declare v_n integer;
  begin
    select count(*) into v_n from public.admin_list_assignable_drivers(v_nueva)
    where driver_id::text like 'b8000000%';
    insert into resultados values (19, 'Un pasajero NO ve la lista de candidatos',
      '0', v_n::text, v_n = 0);
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$resto$;


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
