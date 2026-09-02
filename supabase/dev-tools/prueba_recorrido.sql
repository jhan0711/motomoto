-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba del rastro del viaje: quien puede escribir en `ride_locations`, quien
-- puede leerlo, que `complete_ride` mide solo el recorrido y no la aproximacion
-- (E33, `20260812132825`), y que `list_driver_active_rides` lista los varios
-- servicios de un conductor con su referencia de recogida (D161, D172).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_recorrido.sql
--
-- Absorbe los perdidos `prueba_recorrido.sql` y `prueba_paradas.sql`.
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
-- =============================================================================

begin;

create temp table resultados (
  n integer, comprobacion text, esperado text, obtenido text, ok boolean
) on commit drop;

create temp table actores (
  pasajero uuid, otro uuid, conductor uuid, vehiculo uuid, capacidad smallint,
  lng double precision, lat double precision
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
-- Montaje: un conductor con DOS viajes en el mismo motorraton, D161
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
  v_geo  extensions.geography;
  v_ride1 uuid := 'ca000000-0000-4000-8000-0000000000c1';
  v_ride2 uuid := 'ca000000-0000-4000-8000-0000000000c2';
  v_req1  uuid := 'ca000000-0000-4000-8000-000000000001';
  v_req2  uuid := 'ca000000-0000-4000-8000-000000000002';
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';
  v_geo := extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography;

  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;
  select p.id into v_otro from public.profiles p
  where p.role = 'passenger' and p.status = 'active' and p.id <> v_pas
  order by p.created_at limit 1;

  select d.id into v_cond from public.drivers d
  where d.approval_status = 'approved' order by d.id limit 1;

  select a.vehicle_id, v.max_passengers into v_veh, v_cap
  from public.driver_vehicle_assignments a
    join public.vehicles v on v.id = a.vehicle_id
  where a.driver_id = v_cond and a.unassigned_at is null;
  if v_veh is null then
    select v.id, v.max_passengers into v_veh, v_cap
    from public.vehicles v where v.status = 'active' limit 1;
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id) values (v_cond, v_veh);
  end if;

  update public.ride_requests set status = 'expired'
  where passenger_id in (v_pas, v_otro)
    and status in ('searching', 'assigned', 'in_progress');
  update public.rides
  set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where driver_id = v_cond
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

  insert into actores values (v_pas, v_otro, v_cond, v_veh, v_cap, v_lng, v_lat);

  -- Viaje 1: en curso, aceptado antes.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    assigned_at, started_at, service_type, fare_amount, fare_trip_amount,
    fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req1, v_pas, 'in_progress', 1, v_geo, 'Zz recorrido origen 1',
    v_geo, 'Zz recorrido destino 1', '3000000201',
    now() - interval '40 minutes', now() - interval '35 minutes',
    now() - interval '30 minutes', now() - interval '20 minutes',
    'passenger', 4000, 4000, 0, false, false
  );
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride1, v_req1, v_cond, v_veh, 'in_progress', 1,
    now() - interval '30 minutes', now() - interval '22 minutes', now() - interval '20 minutes'
  );

  -- Viaje 2: asignado, aceptado despues, con referencia de recogida.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    assigned_at, pickup_reference, service_type, fare_amount, fare_trip_amount,
    fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req2, v_otro, 'assigned', 1, v_geo, 'Zz recorrido origen 2',
    v_geo, 'Zz recorrido destino 2', '3000000202',
    now() - interval '12 minutes', now() + interval '10 minutes',
    now() - interval '10 minutes', 'Zz junto al porton verde',
    'passenger', 4000, 4000, 0, false, false
  );
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at
  ) values (
    v_ride2, v_req2, v_cond, v_veh, 'assigned', 1, now() - interval '10 minutes'
  );
end
$montaje$;


-- -----------------------------------------------------------------------------
-- list_driver_active_rides: los dos servicios, en orden, con su referencia
-- -----------------------------------------------------------------------------

do $lista$
declare
  a actores;
  v_req1 constant uuid := 'ca000000-0000-4000-8000-000000000001';
  v_req2 constant uuid := 'ca000000-0000-4000-8000-000000000002';
  v_n integer;
  v_primero uuid;
  v_ref text;
begin
  select * into a from actores;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);

  select count(*) into v_n from public.list_driver_active_rides()
  where request_id in (v_req1, v_req2);
  insert into resultados values (1, 'El conductor ve sus dos servicios activos a la vez (D161)',
    '2', v_n::text, v_n = 2);

  select request_id into v_primero from public.list_driver_active_rides()
  where request_id in (v_req1, v_req2)
  order by accepted_at limit 1;
  insert into resultados values (2, 'Vienen ordenados por hora de aceptacion',
    v_req1::text, coalesce(v_primero::text, 'nulo'), v_primero = v_req1);

  select pickup_reference into v_ref from public.list_driver_active_rides()
  where request_id = v_req2;
  insert into resultados values (3, 'D172: el conductor que acepto ve la referencia de recogida',
    'Zz junto al porton verde', coalesce(v_ref, 'nulo'),
    v_ref = 'Zz junto al porton verde');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$lista$;


-- -----------------------------------------------------------------------------
-- Quien puede ESCRIBIR un punto del rastro
-- -----------------------------------------------------------------------------

do $escritura$
declare
  a actores;
  v_ride1 constant uuid := 'ca000000-0000-4000-8000-0000000000c1';
  v_ride2 constant uuid := 'ca000000-0000-4000-8000-0000000000c2';
  v_geo extensions.geography;
  v_n integer;
begin
  select * into a from actores;
  v_geo := extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography;

  -- 4. El conductor del viaje en curso puede insertar puntos.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    insert into public.ride_locations (ride_id, location, recorded_at)
    values (v_ride1, v_geo, now());
    insert into resultados values (4, 'El conductor del viaje in_progress puede grabar el rastro',
      'lo graba', 'lo grabo', true);
  exception when others then
    insert into resultados values (4, 'El conductor del viaje in_progress puede grabar el rastro',
      'lo graba', 'RECHAZADO ' || sqlstate, false);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 5. El pasajero no puede grabar puntos de su viaje.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);
  begin
    insert into public.ride_locations (ride_id, location, recorded_at)
    values (v_ride1, v_geo, now());
    insert into resultados values (5, 'El pasajero NO puede grabar el rastro',
      'RLS lo rechaza', 'LO GRABO', false);
  exception when insufficient_privilege then
    insert into resultados values (5, 'El pasajero NO puede grabar el rastro',
      'RLS lo rechaza', 'rechazado', true);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 6. El conductor tampoco puede grabar en un viaje suyo que aun esta 'assigned':
  --    is_active_driver_of_ride solo abre en on_the_way / arrived / in_progress.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    insert into public.ride_locations (ride_id, location, recorded_at)
    values (v_ride2, v_geo, now());
    insert into resultados values (6, 'En un viaje aun en assigned no se graba rastro',
      'RLS lo rechaza', 'LO GRABO', false);
  exception when insufficient_privilege then
    insert into resultados values (6, 'En un viaje aun en assigned no se graba rastro',
      'RLS lo rechaza', 'rechazado', true);
  end;

  -- 7. En cuanto el viaje pasa a driver_on_the_way, si.
  execute 'reset role';
  execute 'reset request.jwt.claims';
  update public.rides set status = 'driver_on_the_way' where id = v_ride2;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    insert into public.ride_locations (ride_id, location, recorded_at)
    values (v_ride2, v_geo, now());
    insert into resultados values (7, 'Yendo hacia la recogida ya se puede grabar rastro',
      'lo graba', 'lo grabo', true);
  exception when others then
    insert into resultados values (7, 'Yendo hacia la recogida ya se puede grabar rastro',
      'lo graba', 'RECHAZADO ' || sqlstate, false);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$escritura$;


-- -----------------------------------------------------------------------------
-- Quien puede LEER el rastro
-- -----------------------------------------------------------------------------

do $lectura$
declare
  a actores;
  v_ride1 constant uuid := 'ca000000-0000-4000-8000-0000000000c1';
  v_admin uuid;
  v_n integer;
begin
  select * into a from actores;
  select p.id into v_admin from public.profiles p
  where p.role in ('admin', 'super_admin') and p.status = 'active' order by p.created_at limit 1;

  -- 8. El pasajero del viaje ve su rastro.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);
  select count(*) into v_n from public.ride_locations where ride_id = v_ride1;
  insert into resultados values (8, 'El pasajero del viaje ve su propio rastro',
    '>= 1', v_n::text, v_n >= 1);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 9. Otro pasajero, que no participa en ese viaje, no ve nada.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.otro, 'role', 'authenticated')::text);
  select count(*) into v_n from public.ride_locations where ride_id = v_ride1;
  insert into resultados values (9, 'Quien no participa en el viaje no ve su rastro',
    '0', v_n::text, v_n = 0);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 10. El administrador si.
  if v_admin is not null then
    execute 'set local role authenticated';
    execute format('set local request.jwt.claims to %L',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text);
    select count(*) into v_n from public.ride_locations where ride_id = v_ride1;
    insert into resultados values (10, 'El administrador ve el rastro de cualquier viaje',
      '>= 1', v_n::text, v_n >= 1);
    execute 'reset role';
    execute 'reset request.jwt.claims';
  else
    insert into resultados values (10, 'El administrador ve el rastro de cualquier viaje',
      'sin admin en la base', 'omitida', true);
  end if;
end
$lectura$;


-- -----------------------------------------------------------------------------
-- E33: complete_ride mide el recorrido, no la aproximacion
-- -----------------------------------------------------------------------------

do $distancia$
declare
  a actores;
  v_req3  uuid := 'ca000000-0000-4000-8000-000000000003';
  v_ride3 uuid := 'ca000000-0000-4000-8000-0000000000c3';
  v_geo extensions.geography;
  v_arranco timestamptz := now() - interval '10 minutes';
  v_r public.rides;
  v_rq public.ride_requests;
begin
  select * into a from actores;
  v_geo := extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography;

  -- Se apartan los dos viajes del montaje para dejar sitio de asientos.
  update public.rides set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where id in ('ca000000-0000-4000-8000-0000000000c1', 'ca000000-0000-4000-8000-0000000000c2');
  update public.ride_requests set status = 'expired'
  where id in ('ca000000-0000-4000-8000-000000000001', 'ca000000-0000-4000-8000-000000000002');

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    assigned_at, started_at, service_type, fare_amount, fare_trip_amount,
    fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req3, a.pasajero, 'in_progress', 1, v_geo, 'Zz distancia origen',
    v_geo, 'Zz distancia destino', '3000000203',
    now() - interval '25 minutes', now() - interval '20 minutes',
    now() - interval '15 minutes', v_arranco,
    'passenger', 4000, 4000, 0, false, false
  );
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride3, v_req3, a.conductor, a.vehiculo, 'in_progress', 1,
    now() - interval '15 minutes', v_arranco - interval '1 minute', v_arranco
  );

  -- Dos puntos de APROXIMACION, a ~1 km uno de otro, ANTES de started_at.
  insert into public.ride_locations (ride_id, location, recorded_at) values
    (v_ride3, extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography,
     v_arranco - interval '5 minutes'),
    (v_ride3, extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat + 0.009), 4326)::extensions.geography,
     v_arranco - interval '4 minutes');

  -- Dos puntos del RECORRIDO, a ~110 m uno de otro, DESPUES de started_at.
  insert into public.ride_locations (ride_id, location, recorded_at) values
    (v_ride3, extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography,
     v_arranco + interval '1 minute'),
    (v_ride3, extensions.st_setsrid(extensions.st_makepoint(a.lng + 0.001, a.lat), 4326)::extensions.geography,
     v_arranco + interval '2 minutes');

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  perform public.complete_ride(v_ride3);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  select * into v_r from public.rides where id = v_ride3;
  select * into v_rq from public.ride_requests where id = v_req3;

  insert into resultados values (11,
    'E33: la distancia cuenta solo el recorrido (~110 m), no el km de aproximacion',
    'entre 1 y 400 m',
    coalesce(v_r.distance_m::text, 'nulo'),
    v_r.distance_m is not null and v_r.distance_m between 1 and 400);

  insert into resultados values (12, 'complete_ride cierra tambien la solicitud',
    'completed', v_rq.status::text, v_rq.status = 'completed');
end
$distancia$;


select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion, r.esperado, r.obtenido
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
