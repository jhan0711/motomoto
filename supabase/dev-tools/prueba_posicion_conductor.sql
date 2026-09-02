-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260902220000_driver_locations_lat_lng.sql` (Fase 22, paso 7: la
-- latitud y la longitud sueltas en `driver_locations`, para que el pasajero
-- pinte el motorraton con el propio evento de tiempo real).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_posicion_conductor.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LO QUE DEMUESTRA:
--   1. El disparador rellena lat/lng al insertar.
--   2. Y las mantiene en sincronia al mover la posicion.
--   3. `get_driver_location` sigue devolviendo lo de siempre mas `updated_at`.
--   4. El pasajero con servicio activo ve la fila; un extrano no.
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


do $prueba$
declare
  v_pas    uuid := 'f4000000-0000-4000-8000-0000000000b1';
  v_otro   uuid := 'f4000000-0000-4000-8000-0000000000b2';
  v_cond   uuid := 'f4000000-0000-4000-8000-0000000000d1';
  v_veh    uuid := 'f4000000-0000-4000-8000-0000000000e1';
  v_req    uuid := 'f4000000-0000-4000-8000-000000000001';
  v_ride   uuid := 'f4000000-0000-4000-8000-00000000c001';
  v_origen  extensions.geography;
  v_destino extensions.geography;
  v_lat double precision;
  v_lng double precision;
  v_check_lat double precision;
  v_at timestamptz;
  v_n integer;
begin
  select p.location into v_origen from public.places p
   where p.is_active order by p.sort_order, p.name limit 1;
  select p.location into v_destino from public.places p
   where p.is_active and p.location <> v_origen
   order by p.sort_order, p.name limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_pas,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.pos.pas@motomoto-qa.co',  now(), now()),
    (v_otro, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.pos.otro@motomoto-qa.co', now(), now()),
    (v_cond, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.pos.cond@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_pas, v_otro, v_cond);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_pas,  'Zz pos pas',  '3000000701', 'passenger', 'active'),
    (v_otro, 'Zz pos otro', '3000000702', 'passenger', 'active'),
    (v_cond, 'Zz pos cond', '3000000703', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available)
  values (v_cond, 'approved', now(), true);
  insert into public.vehicles (id, unit_number, plate, max_passengers, status)
  values (v_veh, 9971, 'ZP1971', 3, 'active');
  insert into public.driver_vehicle_assignments (driver_id, vehicle_id) values (v_cond, v_veh);

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at
  ) values (
    v_req, v_pas, 'in_progress', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000701', now() - interval '15 min', now() + interval '10 min', now() - interval '13 min');
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride, v_req, v_cond, v_veh, 'in_progress', 1,
    now() - interval '13 min', now() - interval '10 min', now() - interval '8 min');

  -- 1. Al INSERTAR, el disparador rellena lat/lng
  insert into public.driver_locations (driver_id, location)
  values (v_cond, extensions.st_setsrid(extensions.st_makepoint(-75.0810, 6.9100), 4326)::extensions.geography);

  select lat, lng, extensions.st_y(location::extensions.geometry)
    into v_lat, v_lng, v_check_lat
  from public.driver_locations where driver_id = v_cond;
  insert into resultados values (1, 'Al insertar, lat/lng se rellenan solas',
    'lat = st_y(location)',
    'lat=' || round(v_lat::numeric, 6) || ' st_y=' || round(v_check_lat::numeric, 6),
    round(v_lat::numeric, 6) = round(v_check_lat::numeric, 6) and v_lng is not null);

  -- 2. Al MOVER la posicion, se mantienen en sincronia
  update public.driver_locations
  set location = extensions.st_setsrid(extensions.st_makepoint(-75.0755, 6.9070), 4326)::extensions.geography
  where driver_id = v_cond;

  select lat, lng, extensions.st_x(location::extensions.geometry)
    into v_lat, v_lng, v_check_lat
  from public.driver_locations where driver_id = v_cond;
  insert into resultados values (2, 'Al mover la posicion, lng sigue a st_x(location)',
    '-75.0755', round(v_lng::numeric, 4)::text, round(v_lng::numeric, 4) = -75.0755);

  -- 3. `get_driver_location` devuelve latitud, longitud y updated_at
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  select latitude, updated_at into v_check_lat, v_at
  from public.get_driver_location(v_cond);
  insert into resultados values (3, 'get_driver_location trae la latitud',
    '6.907', round(v_check_lat::numeric, 3)::text, round(v_check_lat::numeric, 3) = 6.907);
  insert into resultados values (4, 'get_driver_location trae updated_at',
    'no nulo', coalesce(v_at::text, 'nulo'), v_at is not null);

  -- 4. El pasajero del servicio ve la fila; un extrano no
  select count(*) into v_n from public.driver_locations where driver_id = v_cond;
  insert into resultados values (5, 'El pasajero del servicio ve la posicion',
    '1', v_n::text, v_n = 1);

  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_otro, 'role', 'authenticated')::text);
  select count(*) into v_n from public.driver_locations where driver_id = v_cond;
  insert into resultados values (6, 'Un extrano NO ve la posicion del conductor',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$prueba$;


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
