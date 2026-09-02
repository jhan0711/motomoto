-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260902190000_h15_counterpart_access_expires.sql`
-- (Fase 22, paso 2: el acceso al nombre y al telefono de la contraparte caduca
-- al terminar el servicio).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_h15_telefono_contraparte.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- EL EJE: durante el servicio, las dos partes se ven el perfil y el telefono;
-- en cuanto el viaje termina, por consulta directa a la tabla no sale nada, y el
-- nombre solo sigue viniendo por las funciones de historial.
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
-- Montaje: un viaje EN CURSO y un viaje TERMINADO, cada uno con su pasajero.
-- Y una oferta caducada de un tercer conductor, para el caso del que solo miro.
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_pas_vivo  uuid := 'f3000000-0000-4000-8000-0000000000b1';
  v_pas_fin   uuid := 'f3000000-0000-4000-8000-0000000000b2';
  v_cond      uuid := 'f3000000-0000-4000-8000-0000000000d1';
  v_cond_miro uuid := 'f3000000-0000-4000-8000-0000000000d2';
  v_veh       uuid := 'f3000000-0000-4000-8000-0000000000e1';
  v_veh2      uuid := 'f3000000-0000-4000-8000-0000000000e2';
  v_req_vivo  uuid := 'f3000000-0000-4000-8000-000000000001';
  v_req_fin   uuid := 'f3000000-0000-4000-8000-000000000002';
  v_ride_vivo uuid := 'f3000000-0000-4000-8000-00000000c001';
  v_ride_fin  uuid := 'f3000000-0000-4000-8000-00000000c002';
  v_carga_id  uuid;
  v_origen  extensions.geography;
  v_destino extensions.geography;
begin
  select p.location into v_origen from public.places p
   where p.is_active order by p.sort_order, p.name limit 1;
  select p.location into v_destino from public.places p
   where p.is_active and p.location <> v_origen
   order by p.sort_order, p.name limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  values
    (v_pas_vivo,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.h15.pv@motomoto-qa.co', now(), now()),
    (v_pas_fin,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.h15.pf@motomoto-qa.co', now(), now()),
    (v_cond,      '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.h15.c1@motomoto-qa.co', now(), now()),
    (v_cond_miro, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.h15.c2@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_pas_vivo, v_pas_fin, v_cond, v_cond_miro);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_pas_vivo,  'Zz h15 pasajero vivo',  '3000000601', 'passenger', 'active'),
    (v_pas_fin,   'Zz h15 pasajero fin',   '3000000602', 'passenger', 'active'),
    (v_cond,      'Zz h15 conductor',      '3000000603', 'driver',    'active'),
    (v_cond_miro, 'Zz h15 conductor miro', '3000000604', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available) values
    (v_cond,      'approved', now(), true),
    (v_cond_miro, 'approved', now(), true);
  insert into public.vehicles (id, unit_number, plate, max_passengers, status) values
    (v_veh,  9961, 'ZH1961', 3, 'active'),
    (v_veh2, 9962, 'ZH2962', 3, 'active');
  insert into public.driver_vehicle_assignments (driver_id, vehicle_id) values
    (v_cond, v_veh), (v_cond_miro, v_veh2);

  -- Viaje EN CURSO
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req_vivo, v_pas_vivo, 'in_progress', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000601', now() - interval '20 min', now() + interval '10 min', now() - interval '18 min',
    'passenger', 4000, 4000, 0, false, false);
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride_vivo, v_req_vivo, v_cond, v_veh, 'in_progress', 1,
    now() - interval '18 min', now() - interval '15 min', now() - interval '12 min');

  -- Viaje TERMINADO, hace dos horas
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at, completed_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req_fin, v_pas_fin, 'completed', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000602', now() - interval '3 hour', now() - interval '2 hour 50 min', now() - interval '2 hour 55 min',
    now() - interval '2 hour',
    'passenger', 4000, 4000, 0, false, false);
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at, distance_m, duration_s
  ) values (
    v_ride_fin, v_req_fin, v_cond, v_veh, 'completed', 1,
    now() - interval '2 hour 55 min', now() - interval '2 hour 50 min', now() - interval '2 hour 45 min',
    now() - interval '2 hour', 2400, 600);
  insert into public.ride_offers (request_id, driver_id, response, offered_at, responded_at, expires_at)
  values (v_req_fin, v_cond, 'accepted', now() - interval '3 hour', now() - interval '2 hour 56 min', now() - interval '2 hour 57 min');

  -- Una linea de carga en el viaje terminado, para list_request_cargo
  select id into v_carga_id from public.cargo_types where is_active order by sort_order limit 1;
  if v_carga_id is not null then
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (v_req_fin, v_carga_id, 1, 2000);
  end if;

  -- El tercer conductor SOLO recibio una oferta del viaje terminado, ya caducada
  insert into public.ride_offers (request_id, driver_id, response, offered_at, responded_at, expires_at)
  values (v_req_fin, v_cond_miro, 'expired', now() - interval '3 hour',
          now() - interval '2 hour 58 min', now() - interval '2 hour 58 min');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- DURANTE el servicio: las dos partes se ven
-- -----------------------------------------------------------------------------

do $vivo$
declare
  v_pas  constant uuid := 'f3000000-0000-4000-8000-0000000000b1';
  v_cond constant uuid := 'f3000000-0000-4000-8000-0000000000d1';
  v_req  constant uuid := 'f3000000-0000-4000-8000-000000000001';
  v_t text;
  v_n integer;
begin
  -- 1. El pasajero ve el telefono del conductor
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);
  select phone into v_t from public.profiles where id = v_cond;
  insert into resultados values (1, 'En curso: el pasajero ve el telefono del conductor',
    '3000000603', coalesce(v_t, 'nulo'), v_t = '3000000603');

  -- 2. El conductor ve el nombre del pasajero y el contact_phone de la solicitud
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);
  select full_name into v_t from public.profiles where id = v_pas;
  insert into resultados values (2, 'En curso: el conductor ve el nombre del pasajero',
    'Zz h15 pasajero vivo', coalesce(v_t, 'nulo'), v_t = 'Zz h15 pasajero vivo');

  select contact_phone into v_t from public.ride_requests where id = v_req;
  insert into resultados values (3, 'En curso: el conductor ve el contact_phone de la solicitud',
    '3000000601', coalesce(v_t, 'nulo'), v_t = '3000000601');

  -- 4. Y list_driver_active_rides sigue trayendo el telefono
  select passenger_phone into v_t from public.list_driver_active_rides() where request_id = v_req;
  insert into resultados values (4, 'En curso: list_driver_active_rides trae el telefono',
    '3000000601', coalesce(v_t, 'nulo'), v_t = '3000000601');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$vivo$;


-- -----------------------------------------------------------------------------
-- DESPUES del servicio: por consulta directa no sale nada
-- -----------------------------------------------------------------------------

do $fin$
declare
  v_pas  constant uuid := 'f3000000-0000-4000-8000-0000000000b2';
  v_cond constant uuid := 'f3000000-0000-4000-8000-0000000000d1';
  v_cmiro constant uuid := 'f3000000-0000-4000-8000-0000000000d2';
  v_req  constant uuid := 'f3000000-0000-4000-8000-000000000002';
  v_t text;
  v_n integer;
begin
  -- 5. El conductor YA NO ve el perfil del pasajero de un viaje terminado
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);
  select count(*) into v_n from public.profiles where id = v_pas;
  insert into resultados values (5, 'Terminado: el conductor NO ve el perfil del pasajero',
    '0 filas', v_n::text || ' filas', v_n = 0);

  -- 6. Ni el contact_phone de la solicitud terminada
  select count(*) into v_n from public.ride_requests where id = v_req;
  insert into resultados values (6, 'Terminado: el conductor NO ve la solicitud',
    '0 filas', v_n::text || ' filas', v_n = 0);

  -- 7. Pero el HISTORIAL sigue diciendo con quien fue: list_driver_history
  select passenger_name into v_t from public.list_driver_history(50, 0)
  where request_id = v_req;
  insert into resultados values (7, 'Terminado: el historial del conductor da el nombre',
    'Zz h15 pasajero fin', coalesce(v_t, 'nulo'), v_t = 'Zz h15 pasajero fin');

  -- 8. Y list_request_cargo le sigue dando la carga de ese viaje
  select cargo_type_name into v_t from public.list_request_cargo(v_req) limit 1;
  insert into resultados values (8, 'Terminado: el conductor ve la carga de su viaje pasado',
    'un nombre de carga', coalesce(v_t, 'nulo'), v_t is not null);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 9. El pasajero YA NO ve el perfil del conductor por consulta directa
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);
  select count(*) into v_n from public.profiles where id = v_cond;
  insert into resultados values (9, 'Terminado: el pasajero NO ve el perfil del conductor',
    '0 filas', v_n::text || ' filas', v_n = 0);

  -- 10. Pero su historial le da el nombre del conductor
  select driver_name into v_t from public.list_passenger_history(50, 0)
  where request_id = v_req;
  insert into resultados values (10, 'Terminado: el historial del pasajero da el nombre del conductor',
    'Zz h15 conductor', coalesce(v_t, 'nulo'), v_t = 'Zz h15 conductor');

  -- 11. El pasajero SIGUE viendo su propio perfil (camino de fetchProfile)
  select phone into v_t from public.profiles where id = v_pas;
  insert into resultados values (11, 'El usuario ve su propio perfil y telefono',
    '3000000602', coalesce(v_t, 'nulo'), v_t = '3000000602');

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 12. El conductor que SOLO recibio una oferta caducada no ve nada
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cmiro, 'role', 'authenticated')::text);
  select count(*) into v_n from public.ride_requests where id = v_req;
  insert into resultados values (12, 'Una oferta caducada no da acceso a la solicitud',
    '0 filas', v_n::text || ' filas', v_n = 0);
  select count(*) into v_n from public.profiles where id = v_pas;
  insert into resultados values (13, 'Una oferta caducada no da acceso al perfil del pasajero',
    '0 filas', v_n::text || ' filas', v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$fin$;


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
