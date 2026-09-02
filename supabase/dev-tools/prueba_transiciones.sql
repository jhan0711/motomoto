-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de las funciones de transicion de la maquina de estados del viaje,
-- definidas en `20260729013123_ride_state_transition_functions.sql` y retocadas
-- despues por `20260805222621`, `20260812083511` y `20260812132825`.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_transiciones.sql
--
-- POR QUE ESTE ARCHIVO. La auditoria de la Fase 23 (seccion 15.25) encontro que
-- **ningun `prueba_*.sql` llamaba a `start_driving_to_pickup`,
-- `confirm_driver_arrival` ni `start_ride`**: todos montaban el viaje con un
-- `insert` directo del estado final. Las guardias de orden, la regla R5, la
-- propiedad del viaje, `NO_DRIVERS_AVAILABLE` y el interruptor de disponibilidad
-- (E32, D164) no las probaba nada. Este archivo absorbe lo que iban a cubrir los
-- perdidos `prueba_transiciones.sql`, `prueba_ciclo.sql`, `prueba_ciclo_completo.sql`
-- y `prueba_interruptor.sql`.
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

create temp table actores (
  pasajero uuid,
  otro uuid,
  conductor uuid,
  vehiculo uuid,
  capacidad smallint,
  lng double precision,
  lat double precision
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
  execute 'grant select on actores to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Montaje: un conductor aprobado, disponible y con motorraton, en el parque
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_pas  uuid;
  v_otro uuid;
  v_cond uuid;
  v_veh  uuid;
  v_cap  smallint;
  v_lng  double precision;
  v_lat  double precision;
  v_n    integer;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';

  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;

  select p.id into v_otro from public.profiles p
  where p.role = 'passenger' and p.status = 'active' and p.id <> v_pas
  order by p.created_at limit 1;

  -- Un conductor APROBADO, no el primero que haya (E11 / quinta vez).
  select d.id into v_cond from public.drivers d
  where d.approval_status = 'approved' order by d.id limit 1;

  -- La prueba monta su propia asignacion si el conductor no tiene una vigente.
  select a.vehicle_id, v.max_passengers into v_veh, v_cap
  from public.driver_vehicle_assignments a
    join public.vehicles v on v.id = a.vehicle_id
  where a.driver_id = v_cond and a.unassigned_at is null;

  if v_veh is null then
    select v.id, v.max_passengers into v_veh, v_cap
    from public.vehicles v where v.status = 'active' limit 1;
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (v_cond, v_veh);
  end if;

  -- El pasajero y el otro, sin nada vivo.
  update public.ride_requests set status = 'expired'
  where passenger_id in (v_pas, v_otro)
    and status in ('searching', 'assigned', 'in_progress');

  -- El conductor, sin viajes activos heredados.
  update public.rides
  set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where driver_id = v_cond
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

  -- Disponible, y solo el.
  update public.drivers set is_available = false where id <> v_cond;
  update public.drivers set is_available = true where id = v_cond;

  insert into public.driver_locations (driver_id, location, updated_at)
  values (v_cond,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    now())
  on conflict (driver_id) do update
    set location = excluded.location, updated_at = now();

  insert into actores values (v_pas, v_otro, v_cond, v_veh, v_cap, v_lng, v_lat);

  select count(*) into v_n
  from public.find_available_drivers(
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    1::smallint);
  insert into resultados values (1, 'Montaje: hay un conductor disponible en el parque',
    '1', v_n::text, v_n = 1);
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Las cuatro transiciones, una por una, en un viaje montado a mano
-- -----------------------------------------------------------------------------

do $transiciones$
declare
  a actores;
  v_req  uuid := 'c9000000-0000-4000-8000-000000000001';
  v_ride uuid := 'c9000000-0000-4000-8000-0000000000c1';
  v_geo  extensions.geography;
  v_r    public.rides;
  v_rq   public.ride_requests;
  v_h    text;
begin
  select * into a from actores;
  v_geo := extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography;

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req, a.pasajero, 'assigned', 1, v_geo, 'Zz transiciones origen',
    v_geo, 'Zz transiciones destino', '3000000101',
    now() - interval '10 minutes', now() + interval '10 minutes', now() - interval '9 minutes',
    'passenger', 4000, 4000, 0, false, false
  );

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at
  ) values (
    v_ride, v_req, a.conductor, a.vehiculo, 'assigned', 1, now() - interval '9 minutes'
  );

  -- 2. Un tercero no puede mover el viaje de otro.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.otro, 'role', 'authenticated')::text);
  begin
    perform public.start_driving_to_pickup(v_ride);
    insert into resultados values (2, 'Un tercero no puede arrancar el viaje ajeno',
      'RIDE_NOT_FOUND', 'LO MOVIO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (2, 'Un tercero no puede arrancar el viaje ajeno',
      'RIDE_NOT_FOUND', coalesce(v_h, sqlstate), v_h = 'RIDE_NOT_FOUND');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 3. El conductor sale hacia la recogida.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);

  perform public.start_driving_to_pickup(v_ride);
  select * into v_r from public.rides where id = v_ride;
  insert into resultados values (3, 'assigned -> driver_on_the_way',
    'driver_on_the_way', v_r.status::text, v_r.status = 'driver_on_the_way');

  -- 4. No se repite un paso ya dado.
  begin
    perform public.start_driving_to_pickup(v_ride);
    insert into resultados values (4, 'No se puede repetir start_driving_to_pickup',
      'INVALID_STATE_TRANSITION', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (4, 'No se puede repetir start_driving_to_pickup',
      'INVALID_STATE_TRANSITION', coalesce(v_h, sqlstate), v_h = 'INVALID_STATE_TRANSITION');
  end;

  -- 5. No se salta la confirmacion de llegada.
  begin
    perform public.start_ride(v_ride);
    insert into resultados values (5, 'No se puede empezar el viaje sin confirmar la llegada',
      'INVALID_STATE_TRANSITION', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (5, 'No se puede empezar el viaje sin confirmar la llegada',
      'INVALID_STATE_TRANSITION', coalesce(v_h, sqlstate), v_h = 'INVALID_STATE_TRANSITION');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 6. R5: sin posicion reciente se permite confirmar (zona montanosa, D... la
  --    cabecera de la migracion lo justifica).
  delete from public.driver_locations where driver_id = a.conductor;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  perform public.confirm_driver_arrival(v_ride);
  select * into v_r from public.rides where id = v_ride;
  insert into resultados values (6, 'R5: sin cobertura, confirmar la llegada se permite igual',
    'driver_arrived', v_r.status::text, v_r.status = 'driver_arrived');
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 7. R5: con posicion reciente y lejos, se rechaza.
  update public.rides set status = 'driver_on_the_way', driver_arrived_at = null
  where id = v_ride;
  insert into public.driver_locations (driver_id, location, updated_at)
  values (a.conductor,
    extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat + 0.02), 4326)::extensions.geography,
    now())
  on conflict (driver_id) do update
    set location = excluded.location, updated_at = now();

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    perform public.confirm_driver_arrival(v_ride);
    insert into resultados values (7, 'R5: a dos kilometros, confirmar la llegada se rechaza',
      'TOO_FAR_FROM_PICKUP', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'R5: a dos kilometros, confirmar la llegada se rechaza',
      'TOO_FAR_FROM_PICKUP', coalesce(v_h, sqlstate), v_h = 'TOO_FAR_FROM_PICKUP');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 8. R5: con posicion reciente y cerca, se permite.
  update public.driver_locations set location = v_geo, updated_at = now()
  where driver_id = a.conductor;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  perform public.confirm_driver_arrival(v_ride);
  select * into v_r from public.rides where id = v_ride;
  insert into resultados values (8, 'R5: en el punto de recogida, la llegada se confirma',
    'driver_arrived', v_r.status::text, v_r.status = 'driver_arrived');

  -- 9. start_ride: un tercero no.
  execute 'reset role';
  execute 'reset request.jwt.claims';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.otro, 'role', 'authenticated')::text);
  begin
    perform public.start_ride(v_ride);
    insert into resultados values (9, 'start_ride de un tercero se rechaza',
      'RIDE_NOT_FOUND', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (9, 'start_ride de un tercero se rechaza',
      'RIDE_NOT_FOUND', coalesce(v_h, sqlstate), v_h = 'RIDE_NOT_FOUND');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 10 y 11. start_ride mueve el viaje Y la solicitud, y fija started_at.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  perform public.start_ride(v_ride);
  select * into v_r from public.rides where id = v_ride;
  select * into v_rq from public.ride_requests where id = v_req;
  insert into resultados values (10, 'driver_arrived -> in_progress, con started_at',
    'in_progress / con fecha',
    v_r.status::text || ' / ' || case when v_r.started_at is null then 'sin fecha' else 'con fecha' end,
    v_r.status = 'in_progress' and v_r.started_at is not null);
  insert into resultados values (11, 'start_ride arrastra la solicitud a in_progress',
    'in_progress', v_rq.status::text, v_rq.status = 'in_progress');

  -- 12. complete_ride de un tercero.
  execute 'reset role';
  execute 'reset request.jwt.claims';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.otro, 'role', 'authenticated')::text);
  begin
    perform public.complete_ride(v_ride);
    insert into resultados values (12, 'complete_ride de un tercero se rechaza',
      'RIDE_NOT_FOUND', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'complete_ride de un tercero se rechaza',
      'RIDE_NOT_FOUND', coalesce(v_h, sqlstate), v_h = 'RIDE_NOT_FOUND');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 13, 14, 15. El conductor apago el interruptor antes de terminar. Completar
  --    cierra el viaje y la solicitud, pero NO vuelve a encender la
  --    disponibilidad (20260812083511, D164).
  update public.drivers set is_available = false where id = a.conductor;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  perform public.complete_ride(v_ride);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  select * into v_r from public.rides where id = v_ride;
  select * into v_rq from public.ride_requests where id = v_req;
  insert into resultados values (13, 'complete_ride: sin dos puntos de rastro, distancia nula',
    'completed / nulo',
    v_r.status::text || ' / ' || coalesce(v_r.distance_m::text, 'nulo'),
    v_r.status = 'completed' and v_r.distance_m is null);
  insert into resultados values (14, 'complete_ride arrastra la solicitud a completed',
    'completed', v_rq.status::text, v_rq.status = 'completed');
  insert into resultados values (15, 'Terminar NO reenciende la disponibilidad que el conductor apago',
    'false',
    (select is_available::text from public.drivers where id = a.conductor),
    (select not is_available from public.drivers where id = a.conductor));

  -- 16. Un viaje terminado no se vuelve a terminar.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    perform public.complete_ride(v_ride);
    insert into resultados values (16, 'Un viaje ya terminado no admite complete_ride',
      'INVALID_STATE_TRANSITION', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (16, 'Un viaje ya terminado no admite complete_ride',
      'INVALID_STATE_TRANSITION', coalesce(v_h, sqlstate), v_h = 'INVALID_STATE_TRANSITION');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$transiciones$;


-- -----------------------------------------------------------------------------
-- Sin conductores disponibles no se crea la solicitud (R1 revisada)
-- -----------------------------------------------------------------------------

do $sin_conductores$
declare
  a actores;
  v_h  text;
  v_id uuid;
begin
  select * into a from actores;
  update public.drivers set is_available = false;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint);
    insert into resultados values (17, 'Sin conductores disponibles, request_ride avisa en el acto',
      'NO_DRIVERS_AVAILABLE', 'LA CREO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (17, 'Sin conductores disponibles, request_ride avisa en el acto',
      'NO_DRIVERS_AVAILABLE', coalesce(v_h, sqlstate), v_h = 'NO_DRIVERS_AVAILABLE');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$sin_conductores$;


-- -----------------------------------------------------------------------------
-- E32 / D164: aceptar una oferta no enciende la disponibilidad apagada a mano
-- -----------------------------------------------------------------------------

do $interruptor$
declare
  a actores;
  v_id    uuid;
  v_offer uuid;
begin
  select * into a from actores;

  update public.drivers set is_available = true where id = a.conductor;
  update public.driver_locations set updated_at = now() where driver_id = a.conductor;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);
  v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- El conductor apaga el interruptor a mano DESPUES de recibir la oferta.
  update public.drivers set is_available = false where id = a.conductor;

  select id into v_offer from public.ride_offers
  where request_id = v_id and driver_id = a.conductor and response = 'pending';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  perform public.accept_ride_offer(v_offer);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  insert into resultados values (18, 'E32: aceptar no reenciende la disponibilidad que el conductor apago',
    'false',
    (select is_available::text from public.drivers where id = a.conductor),
    (select not is_available from public.drivers where id = a.conductor));

  update public.ride_requests set status = 'expired' where id = v_id;
  update public.rides set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where request_id = v_id;
end
$interruptor$;


-- -----------------------------------------------------------------------------
-- El ciclo organico entero, por las funciones reales
-- -----------------------------------------------------------------------------

do $ciclo$
declare
  a actores;
  v_id    uuid;
  v_offer uuid;
  v_ride  uuid;
  v_r     public.rides;
  v_rq    public.ride_requests;
begin
  select * into a from actores;

  update public.drivers set is_available = true where id = a.conductor;
  update public.driver_locations set location =
    extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography,
    updated_at = now()
  where driver_id = a.conductor;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);
  v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  select id into v_offer from public.ride_offers
  where request_id = v_id and driver_id = a.conductor and response = 'pending';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  v_ride := public.accept_ride_offer(v_offer);
  perform public.start_driving_to_pickup(v_ride);
  perform public.confirm_driver_arrival(v_ride);
  perform public.start_ride(v_ride);
  perform public.complete_ride(v_ride);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  select * into v_r from public.rides where id = v_ride;
  select * into v_rq from public.ride_requests where id = v_id;
  insert into resultados values (19, 'El ciclo entero por las funciones deja el viaje en completed',
    'completed', v_r.status::text, v_r.status = 'completed');
  insert into resultados values (20, 'Y la solicitud en completed',
    'completed', v_rq.status::text, v_rq.status = 'completed');
end
$ciclo$;


-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------

do $permisos2$
declare
  v_ok boolean;
begin
  select has_function_privilege('anon', 'public.start_ride(uuid)', 'execute') into v_ok;
  insert into resultados values (21, 'Sin sesion no se puede llamar a start_ride',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('authenticated', 'public.start_ride(uuid)', 'execute') into v_ok;
  insert into resultados values (22, 'El conductor SI puede llamar a start_ride',
    'true', v_ok::text, v_ok = true);

  select has_function_privilege('authenticated',
    'public.assert_ride_driver(uuid,public.ride_status[])', 'execute') into v_ok;
  insert into resultados values (23, 'La auxiliar assert_ride_driver no es accesible desde la app',
    'false', v_ok::text, v_ok = false);
end
$permisos2$;


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
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
