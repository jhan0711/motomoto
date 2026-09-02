-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260902150000_blocked_driver_and_r10.sql` (Fase 20, paso 11:
-- que el bloqueo del conductor muerda, y la alerta de R10; D215, D216, D262).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_bloqueo_y_senal.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- **CASI TODO AQUI ES "QUE YA NO SE PUEDE".** Antes de esta migracion, bloquear
-- a un conductor le frenaba el inicio de sesion y **nada mas**: con la sesion
-- abierta seguia aceptando servicios. Lo que hay que demostrar es que esa puerta
-- esta cerrada, y **que la de terminar el viaje que lleva sigue abierta** (D262),
-- que es igual de importante y mucho mas facil de romper sin darse cuenta.
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
-- Montaje: un conductor conduciendo, otro libre y una oferta pendiente
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin uuid := 'e1000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'e1000000-0000-4000-8000-0000000000b1';
  v_pas2  uuid := 'e1000000-0000-4000-8000-0000000000b2';
  v_pas3  uuid := 'e1000000-0000-4000-8000-0000000000b3';
  v_cond  uuid := 'e1000000-0000-4000-8000-0000000000d1';
  v_cond2 uuid := 'e1000000-0000-4000-8000-0000000000d2';
  v_pend  uuid := 'e1000000-0000-4000-8000-0000000000d3';

  v_veh   uuid := 'e1000000-0000-4000-8000-0000000000e1';
  v_veh2  uuid := 'e1000000-0000-4000-8000-0000000000e2';
  v_veh3  uuid := 'e1000000-0000-4000-8000-0000000000e3';

  v_req   uuid := 'e1000000-0000-4000-8000-000000000001';
  v_req2  uuid := 'e1000000-0000-4000-8000-000000000002';
  v_req3  uuid := 'e1000000-0000-4000-8000-000000000003';
  v_ride  uuid := 'e1000000-0000-4000-8000-00000000c001';
  v_ride2 uuid := 'e1000000-0000-4000-8000-00000000c002';

  v_origen  extensions.geography;
  v_destino extensions.geography;
begin
  select p.location into v_origen from public.places p where p.is_active
   order by p.sort_order, p.name limit 1;
  select p.location into v_destino from public.places p where p.is_active and p.location <> v_origen
   order by p.sort_order, p.name limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  select x.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         x.correo, now(), now()
  from (values
    (v_admin, 'zz.blo.admin@motomoto-qa.co'), (v_pas,  'zz.blo.pas@motomoto-qa.co'),
    (v_pas2,  'zz.blo.pas2@motomoto-qa.co'),  (v_pas3, 'zz.blo.pas3@motomoto-qa.co'),
    (v_cond,  'zz.blo.cond@motomoto-qa.co'),  (v_cond2,'zz.blo.cond2@motomoto-qa.co'),
    (v_pend,  'zz.blo.pend@motomoto-qa.co')
  ) as x(id, correo);

  delete from public.profiles where id::text like 'e1000000%';
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz blo admin',  '3000000401', 'admin',     'active'),
    (v_pas,   'Zz blo pas',    '3000000402', 'passenger', 'active'),
    (v_pas2,  'Zz blo pas2',   '3000000403', 'passenger', 'active'),
    (v_pas3,  'Zz blo pas3',   '3000000404', 'passenger', 'active'),
    (v_cond,  'Zz blo cond',   '3000000405', 'driver',    'active'),
    (v_cond2, 'Zz blo cond2',  '3000000406', 'driver',    'active'),
    (v_pend,  'Zz blo pend',   '3000000407', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available) values
    (v_cond,  'approved', now(), true),
    (v_cond2, 'approved', now(), true),
    (v_pend,  'pending',  null,  false);

  insert into public.vehicles (id, unit_number, plate, max_passengers, status) values
    (v_veh,  9891, 'ZB1891', 3, 'active'),
    (v_veh2, 9892, 'ZB2892', 3, 'active'),
    (v_veh3, 9893, 'ZB3893', 3, 'active');

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id) values
    (v_cond, v_veh), (v_cond2, v_veh2), (v_pend, v_veh3);

  -- **LA POSICION DEL PRIMERO ES VIEJA A PROPOSITO**: nueve minutos, muy por
  -- encima de los tres de R10. La del segundo es de hace nada.
  insert into public.driver_locations (driver_id, location, updated_at) values
    (v_cond,  v_origen, now() - interval '9 minutes'),
    (v_cond2, v_origen, now() - interval '20 seconds')
  on conflict (driver_id) do update
    set location = excluded.location, updated_at = excluded.updated_at;

  -- El viaje que el primero lleva encima, con un pasajero dentro.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at
  ) values (
    v_req, v_pas, 'in_progress', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000402', now() - interval '20 minutes', now() + interval '10 minutes',
    now() - interval '18 minutes');

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride, v_req, v_cond, v_veh, 'in_progress', 1,
    now() - interval '18 minutes', now() - interval '15 minutes', now() - interval '12 minutes');

  -- Una solicitud buscando, con una oferta ya en manos del primero: es el hueco
  -- que esta migracion cierra. La oferta le llego ANTES de que lo bloquearan.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at
  ) values (
    v_req2, v_pas2, 'searching', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000403', now() - interval '1 minute', now() + interval '4 minutes');

  insert into public.ride_offers (id, request_id, driver_id, response, expires_at)
  values ('e1000000-0000-4000-8000-0000000000f1', v_req2, v_cond, 'pending',
          now() + interval '3 minutes');

  -- Y el viaje del segundo conductor, con senal fresca, para el contraste de R10.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at
  ) values (
    v_req3, v_pas3, 'in_progress', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000404', now() - interval '10 minutes', now() + interval '20 minutes',
    now() - interval '9 minutes');

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride2, v_req3, v_cond2, v_veh2, 'in_progress', 1,
    now() - interval '9 minutes', now() - interval '7 minutes', now() - interval '6 minutes');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- R10: la alerta de senal, ANTES de bloquear a nadie
-- -----------------------------------------------------------------------------

do $senal$
declare
  v_admin constant uuid := 'e1000000-0000-4000-8000-0000000000a1';
  v_req   constant uuid := 'e1000000-0000-4000-8000-000000000001';
  v_req2  constant uuid := 'e1000000-0000-4000-8000-000000000002';
  v_req3  constant uuid := 'e1000000-0000-4000-8000-000000000003';
  v_b boolean;
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. **NUEVE MINUTOS SIN SENAL SE AVISA.** Es R10: el tablero no puede mostrar
  --    un viaje en marcha con una posicion de hace un cuarto de hora como si
  --    todo fuera bien.
  select signal_lost into v_b from public.admin_list_active_services()
  where request_id = v_req;
  insert into resultados values (1, 'Un conductor con 9 minutos sin senal se avisa',
    'true', coalesce(v_b::text, 'nulo'), coalesce(v_b, false));

  -- 2. Y veinte segundos no, que es lo que evita que la alerta sea ruido.
  select signal_lost into v_b from public.admin_list_active_services()
  where request_id = v_req3;
  insert into resultados values (2, 'Un conductor con senal reciente NO se avisa',
    'false', coalesce(v_b::text, 'nulo'), v_b = false);

  -- 3. **EN `searching` NO HAY ALERTA QUE DAR**, y no es lo mismo que "hay senal":
  --    todavia no hay conductor de quien esperarla. Por eso es nulo y no falso.
  select signal_lost into v_b from public.admin_list_active_services()
  where request_id = v_req2;
  insert into resultados values (3, 'Sin conductor asignado no se habla de senal',
    'nulo', coalesce(v_b::text, 'nulo'), v_b is null);

  -- 4. R10 NO CANCELA NADA. Lo dice la regla desde la Fase 2: en la carretera de
  --    Amalfi quedarse sin cobertura tres minutos es normal, no una emergencia.
  select count(*) into v_n from public.ride_requests
  where id = v_req and status = 'in_progress';
  insert into resultados values (4, 'La alerta de senal no cancela el servicio',
    '1', v_n::text, v_n = 1);

  -- 5. El umbral sale de `app_settings`, para que la empresa lo ajuste mirando
  --    el tablero y sin tocar codigo.
  select count(*) into v_n from public.app_settings
  where key = 'driver_signal_lost_seconds';
  insert into resultados values (5, 'El umbral de la alerta es configurable',
    '1', v_n::text, v_n = 1);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 6. Y se respeta de verdad: subiendolo a media hora, el de nueve minutos deja
  --    de avisar. Sin esta, el umbral podria estar guardado y no usarse.
  update public.app_settings set value = '1800'::jsonb
  where key = 'driver_signal_lost_seconds';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  select signal_lost into v_b from public.admin_list_active_services()
  where request_id = v_req;
  insert into resultados values (6, 'Cambiar el umbral cambia a quien se avisa',
    'false', coalesce(v_b::text, 'nulo'), v_b = false);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  update public.app_settings set value = '180'::jsonb
  where key = 'driver_signal_lost_seconds';
end
$senal$;


-- -----------------------------------------------------------------------------
-- El bloqueo del conductor
-- -----------------------------------------------------------------------------

do $bloqueo$
declare
  v_admin constant uuid := 'e1000000-0000-4000-8000-0000000000a1';
  v_cond  constant uuid := 'e1000000-0000-4000-8000-0000000000d1';
  v_req   constant uuid := 'e1000000-0000-4000-8000-000000000001';
  v_oferta constant uuid := 'e1000000-0000-4000-8000-0000000000f1';
  v_h text;
  v_b boolean;
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 7. **BLOQUEAR A UN CONDUCTOR QUE VA CONDUCIENDO EXIGE MOTIVO**, y antes no:
  --    la comprobacion buscaba por `passenger_id`, asi que **el caso mas
  --    delicado de los dos era justo el que se colaba**.
  begin
    perform public.admin_set_account_status(v_cond, 'blocked');
    insert into resultados values (7, 'Bloquear a un conductor con pasajero dentro pide motivo',
      'ACTIVE_RIDE_NEEDS_REASON', 'lo permitio sin motivo', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Bloquear a un conductor con pasajero dentro pide motivo',
      'ACTIVE_RIDE_NEEDS_REASON', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'ACTIVE_RIDE_NEEDS_REASON');
  end;

  -- 8. Con el motivo escrito si se puede: no se prohibe, se explica.
  perform public.admin_set_account_status(v_cond, 'blocked',
    'Conduccion imprudente reportada por dos pasajeros');
  select status = 'blocked' into v_b from public.profiles where id = v_cond;
  insert into resultados values (8, 'Con motivo escrito el bloqueo se hace',
    'true', coalesce(v_b::text, 'nulo'), coalesce(v_b, false));

  -- 9. **SE LE APAGA LA DISPONIBILIDAD EN EL ACTO.** Sin esto seguiria figurando
  --    como conectado hasta que cerrara la aplicacion.
  select is_available into v_b from public.drivers where id = v_cond;
  insert into resultados values (9, 'Al bloquearlo se le apaga la disponibilidad',
    'false', coalesce(v_b::text, 'nulo'), v_b = false);

  -- 10. La auditoria guarda que se hizo con un servicio vivo, que es el dato que
  --     explicara la decision dentro de seis meses.
  select count(*) into v_n from public.admin_audit_logs
  where action = 'block_account' and entity_id = v_cond::text
    and (after_data->>'had_active_request')::boolean;
  insert into resultados values (10, 'Queda registrado que tenia un servicio en curso',
    '1', v_n::text, v_n = 1);

  -- 11. Y el tablero lo dice, que antes no lo decia por ningun lado.
  select driver_blocked into v_b from public.admin_list_active_services()
  where request_id = v_req;
  insert into resultados values (11, 'El tablero ensena que ese conductor esta bloqueado',
    'true', coalesce(v_b::text, 'nulo'), coalesce(v_b, false));

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$bloqueo$;


-- -----------------------------------------------------------------------------
-- Lo que el conductor bloqueado ya NO puede hacer, y lo que SI
-- -----------------------------------------------------------------------------

do $puertas$
declare
  v_cond  constant uuid := 'e1000000-0000-4000-8000-0000000000d1';
  v_pend  constant uuid := 'e1000000-0000-4000-8000-0000000000d3';
  v_ride  constant uuid := 'e1000000-0000-4000-8000-00000000c001';
  v_oferta constant uuid := 'e1000000-0000-4000-8000-0000000000f1';
  v_req2  constant uuid := 'e1000000-0000-4000-8000-000000000002';
  v_h text;
  v_b boolean;
  v_t text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);

  -- 12. **NO ACEPTA UNA OFERTA QUE YA TENIA EN LA MANO.** Es el hueco de verdad:
  --     el reparto ya no le ofrece nada -`find_available_drivers` filtra por
  --     estado desde la Fase 11-, pero una oferta recibida un minuto antes del
  --     bloqueo seguia siendo aceptable, y con ella volvia a la operacion.
  begin
    perform public.accept_ride_offer(v_oferta);
    insert into resultados values (12, 'Un conductor bloqueado NO acepta una oferta pendiente',
      'ACCOUNT_BLOCKED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'Un conductor bloqueado NO acepta una oferta pendiente',
      'ACCOUNT_BLOCKED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'ACCOUNT_BLOCKED');
  end;

  -- 13. Ni se vuelve a poner disponible por su cuenta.
  begin
    update public.drivers set is_available = true where id = v_cond;
    insert into resultados values (13, 'Un conductor bloqueado NO se pone disponible',
      'ACCOUNT_BLOCKED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'Un conductor bloqueado NO se pone disponible',
      'ACCOUNT_BLOCKED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'ACCOUNT_BLOCKED');
  end;

  -- 14. **PERO TERMINA EL VIAJE QUE LLEVA ENCIMA (D262).** Esta es la puerta que
  --     tiene que seguir abierta, y la mas facil de cerrar sin querer al escribir
  --     las otras: **el pasajero que va dentro no tiene la culpa**, y cortarlo lo
  --     dejaria a mitad de camino sin forma de conseguir otro motorraton.
  begin
    perform public.complete_ride(v_ride);
    insert into resultados values (14, 'PERO SI termina el viaje que ya llevaba (D262)',
      'lo termina', 'lo termina', true);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (14, 'PERO SI termina el viaje que ya llevaba (D262)',
      'lo termina', 'lo rechazo: ' || coalesce(nullif(v_h, ''), sqlstate), false);
  end;

  -- 15. Y el servicio del pasajero queda terminado de verdad, no a medias.
  select status::text into v_t from public.ride_requests
  where id = 'e1000000-0000-4000-8000-000000000001';
  insert into resultados values (15, 'El pasajero llega: su servicio queda terminado',
    'completed', coalesce(v_t, 'nulo'), coalesce(v_t = 'completed', false));

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 16. Apagarse siempre se puede, aunque este bloqueado. Es lo que hace la
  --     propia funcion de bloqueo, y prohibirlo la habria roto.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);
  begin
    update public.drivers set is_available = false where id = v_cond;
    insert into resultados values (16, 'Apagarse se puede siempre, incluso bloqueado',
      'lo deja', 'lo deja', true);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (16, 'Apagarse se puede siempre, incluso bloqueado',
      'lo deja', coalesce(nullif(v_h, ''), sqlstate), false);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 17. Y el que no esta aprobado tampoco acepta, con su propio motivo: no es lo
  --     mismo estar bloqueado que no haber sido aprobado todavia.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pend, 'role', 'authenticated')::text);
  begin
    perform public.accept_ride_offer(v_oferta);
    insert into resultados values (17, 'Un conductor sin aprobar tampoco acepta ofertas',
      'OFFER_NOT_FOUND o DRIVER_NOT_APPROVED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    -- La oferta no es suya, asi que lo primero que salta es que no es suya. Las
    -- dos respuestas valen: ninguna de las dos le deja tomar el servicio.
    insert into resultados values (17, 'Un conductor sin aprobar tampoco acepta ofertas',
      'OFFER_NOT_FOUND o DRIVER_NOT_APPROVED', coalesce(nullif(v_h, ''), sqlstate),
      v_h in ('OFFER_NOT_FOUND', 'DRIVER_NOT_APPROVED'));
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$puertas$;


-- -----------------------------------------------------------------------------
-- Desbloquear, y que lo de siempre siga funcionando
-- -----------------------------------------------------------------------------

do $vuelta$
declare
  v_admin constant uuid := 'e1000000-0000-4000-8000-0000000000a1';
  v_cond  constant uuid := 'e1000000-0000-4000-8000-0000000000d1';
  v_pas2  constant uuid := 'e1000000-0000-4000-8000-0000000000b2';
  v_h text;
  v_b boolean;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 18. Desbloquear no pide motivo: devolver a alguien al trabajo no es la
  --     decision delicada, quitarselo si.
  perform public.admin_set_account_status(v_cond, 'active');
  select status = 'active' into v_b from public.profiles where id = v_cond;
  insert into resultados values (18, 'Desbloquear no pide motivo',
    'true', coalesce(v_b::text, 'nulo'), coalesce(v_b, false));

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 19. Y entonces si puede volver a ponerse disponible.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);
  begin
    update public.drivers set is_available = true where id = v_cond;
    insert into resultados values (19, 'Desbloqueado vuelve a poder conectarse',
      'lo deja', 'lo deja', true);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (19, 'Desbloqueado vuelve a poder conectarse',
      'lo deja', coalesce(nullif(v_h, ''), sqlstate), false);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 20. **EL BLOQUEO DEL PASAJERO SIGUE COMO ESTABA (D253).** Esta migracion
  --     reescribio `admin_set_account_status` entera, asi que hay que demostrar
  --     que no se llevo por delante lo que ya funcionaba.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  begin
    perform public.admin_set_account_status(v_pas2, 'blocked');
    insert into resultados values (20, 'Bloquear a un pasajero con solicitud viva sigue pidiendo motivo',
      'ACTIVE_RIDE_NEEDS_REASON', 'lo permitio sin motivo', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (20, 'Bloquear a un pasajero con solicitud viva sigue pidiendo motivo',
      'ACTIVE_RIDE_NEEDS_REASON', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'ACTIVE_RIDE_NEEDS_REASON');
  end;

  -- 21. Y un pasajero cualquiera no bloquea a nadie.
  execute 'reset role';
  execute 'reset request.jwt.claims';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas2, 'role', 'authenticated')::text);
  begin
    perform public.admin_set_account_status(v_cond, 'blocked', 'Porque si me da la gana');
    insert into resultados values (21, 'Un pasajero NO bloquea a nadie',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (21, 'Un pasajero NO bloquea a nadie',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 22. **UN PASAJERO NO VE LOS SERVICIOS DE LOS DEMAS.** No se le prohibe llamar
  --     a la funcion -es `security invoker` a proposito desde el paso 3, y por
  --     RLS **ve la suya**, que ya podia ver-. Lo que no puede es enterarse de
  --     donde va el resto del pueblo ni de que conductor lleva cada servicio.
  --
  --     La primera version de esta comprobacion esperaba cero filas y decia
  --     FALLA teniendo el servidor razon: daba por supuesto un `is_admin()` que
  --     esa funcion nunca tuvo.
  declare v_n integer;
  begin
    select count(*) into v_n from public.admin_list_active_services()
    where request_id <> 'e1000000-0000-4000-8000-000000000002';
    insert into resultados values (22, 'Un pasajero NO ve los servicios de los demas',
      '0 ajenos', v_n::text || ' ajenos', v_n = 0);
  end;

  -- 23. Y de la suya no se lleva datos del conductor que no le tocan.
  declare v_t text;
  begin
    select coalesce(driver_name, '(ninguno)') into v_t
    from public.admin_list_active_services()
    where request_id = 'e1000000-0000-4000-8000-000000000002';
    insert into resultados values (23, 'De la suya, sin conductor asignado, no hay nombre que ver',
      '(ninguno)', coalesce(v_t, 'nulo'), v_t = '(ninguno)');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$vuelta$;


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
  -- `coalesce` a proposito: un `ok` NULL es un fallo, no algo que el total ignore.
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
