-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de la capacidad por asientos que sustituyo a R7 (D161, D220), el filtro
-- de `find_available_drivers`, y la restriccion + normalizacion + privacidad de
-- `pickup_reference` (columna de `20260811184748`, D172).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_capacidad.sql
--
-- Absorbe los perdidos `prueba_capacidad.sql`, `prueba_asientos.sql` y la parte
-- de `prueba_referencia.sql` que no era regresion de E30 (esa ya vive en
-- `prueba_solicitud_con_valor.sql`).
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
-- Montaje
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

  update public.drivers set is_available = false where id <> v_cond;
  update public.drivers set is_available = true where id = v_cond;
  insert into public.driver_locations (driver_id, location, updated_at)
  values (v_cond,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, now())
  on conflict (driver_id) do update set location = excluded.location, updated_at = now();

  insert into actores values (v_pas, v_otro, v_cond, v_veh, v_cap, v_lng, v_lat);

  insert into resultados values (1, 'Montaje: el motorraton de prueba tiene al menos 2 asientos',
    '>= 2', v_cap::text, v_cap >= 2);
end
$montaje$;


-- -----------------------------------------------------------------------------
-- find_available_drivers descuenta los asientos ocupados
-- -----------------------------------------------------------------------------

do $asientos$
declare
  a actores;
  v_geo extensions.geography;
  v_rq uuid := 'cb000000-0000-4000-8000-000000000001';
  v_n integer;
begin
  select * into a from actores;
  v_geo := extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography;

  -- 2. Motorraton vacio: candidato para un grupo de su capacidad entera.
  select count(*) into v_n from public.find_available_drivers(v_geo, a.capacidad)
  where driver_id = a.conductor;
  insert into resultados values (2, 'Vacio, sirve para un grupo de su capacidad entera',
    '1', v_n::text, v_n = 1);

  -- Se le mete un viaje que ocupa todos los asientos menos uno.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_rq, a.otro, 'assigned', (a.capacidad - 1)::smallint, v_geo, 'Zz capacidad A',
    v_geo, 'Zz capacidad B', '3000000301', now() + interval '5 minutes',
    'passenger', 4000, 4000, 0, false, false
  );
  insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at)
  values ('cb000000-0000-4000-8000-0000000000c1', v_rq, a.conductor, a.vehiculo, 'assigned',
    (a.capacidad - 1)::smallint, now());

  -- 3. Con un asiento libre, sirve para uno.
  select count(*) into v_n from public.find_available_drivers(v_geo, 1::smallint)
  where driver_id = a.conductor;
  insert into resultados values (3, 'Con un asiento libre, sigue sirviendo para una persona',
    '1', v_n::text, v_n = 1);

  -- 4. Pero no para dos.
  select count(*) into v_n from public.find_available_drivers(v_geo, 2::smallint)
  where driver_id = a.conductor;
  insert into resultados values (4, 'Con un solo asiento libre, ya no sirve para dos',
    '0', v_n::text, v_n = 0);
end
$asientos$;


-- -----------------------------------------------------------------------------
-- El disparador enforce_ride_capacity al aceptar una oferta
-- -----------------------------------------------------------------------------

do $aceptar$
declare
  a actores;
  v_geo extensions.geography;
  v_rq uuid := 'cb000000-0000-4000-8000-000000000002';
  v_offer uuid;
  v_h text;
  v_resp text;
  v_estado text;
  v_ride uuid;
begin
  select * into a from actores;
  v_geo := extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography;

  -- Una solicitud de dos personas, buscando, con oferta pendiente al conductor
  -- que ya lleva capacidad-1 asientos ocupados.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_rq, a.pasajero, 'searching', 2, v_geo, 'Zz aceptar origen',
    v_geo, 'Zz aceptar destino', '3000000302', now() + interval '5 minutes',
    'passenger', 4000, 4000, 0, false, false
  );
  insert into public.ride_offers (request_id, driver_id, expires_at, response, offered_at, distance_m)
  values (v_rq, a.conductor, now() + interval '2 minutes', 'pending', now(), 120)
  returning id into v_offer;

  -- 5. Aceptar deberia desbordar el motorraton: (capacidad-1) + 2 > capacidad.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    v_ride := public.accept_ride_offer(v_offer);
    insert into resultados values (5, 'Aceptar un grupo que no cabe se rechaza',
      'VEHICLE_CAPACITY_EXCEEDED', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (5, 'Aceptar un grupo que no cabe se rechaza',
      'VEHICLE_CAPACITY_EXCEEDED', coalesce(v_h, sqlstate), v_h = 'VEHICLE_CAPACITY_EXCEEDED');
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 6. Y el rechazo no dejo la oferta ni la solicitud a medias.
  select response::text into v_resp from public.ride_offers where id = v_offer;
  select status::text into v_estado from public.ride_requests where id = v_rq;
  insert into resultados values (6, 'El rechazo deja la oferta pendiente y la solicitud buscando',
    'pending / searching',
    coalesce(v_resp::text, 'nulo') || ' / ' || coalesce(v_estado::text, 'nulo'),
    v_resp = 'pending' and v_estado = 'searching');

  -- Se liberan los asientos y se reintenta la MISMA oferta.
  update public.rides set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where id = 'cb000000-0000-4000-8000-0000000000c1';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  begin
    v_ride := public.accept_ride_offer(v_offer);
    insert into resultados values (7, 'Con los asientos libres, la misma oferta ya entra',
      'la acepta', case when v_ride is null then 'nulo' else 'la acepto' end, v_ride is not null);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Con los asientos libres, la misma oferta ya entra',
      'la acepta', 'LA RECHAZO ' || coalesce(v_h, sqlstate), false);
  end;
  execute 'reset role';
  execute 'reset request.jwt.claims';

  select status::text into v_estado from public.ride_requests where id = v_rq;
  insert into resultados values (8, 'Y la solicitud queda asignada',
    'assigned', coalesce(v_estado::text, 'nulo'), v_estado = 'assigned');
end
$aceptar$;


-- -----------------------------------------------------------------------------
-- pickup_reference: la restriccion de la columna, y su privacidad (D172)
-- -----------------------------------------------------------------------------

do $referencia$
declare
  a actores;
  v_geo extensions.geography;
  v_base uuid := 'cb000000-0000-4000-8000-00000000000f';
  v_rq uuid := 'cb000000-0000-4000-8000-000000000003';
  v_offer uuid;
  v_ride uuid;
  v_ok boolean;
  v_ref text;
  v_n integer;
  v_tiene boolean;
begin
  select * into a from actores;
  v_geo := extensions.st_setsrid(extensions.st_makepoint(a.lng, a.lat), 4326)::extensions.geography;

  -- Los dos pasajeros y el conductor, sin nada vivo heredado de los bloques
  -- anteriores: aqui se prueba la restriccion de la columna, no rr_one_active.
  update public.ride_requests set status = 'expired'
  where passenger_id in (a.pasajero, a.otro)
    and status in ('searching', 'assigned', 'in_progress');
  update public.rides set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where driver_id = a.conductor
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

  -- 9. 81 caracteres: la restriccion rr_pickup_reference_length lo rechaza.
  begin
    insert into public.ride_requests (
      id, passenger_id, status, passenger_count, origin, origin_label,
      destination, destination_label, contact_phone, expires_at, pickup_reference,
      service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_base, a.pasajero, 'searching', 1, v_geo, 'Zz ref A', v_geo, 'Zz ref B',
      '3000000303', now() + interval '5 minutes', repeat('x', 81),
      'passenger', 4000, 4000, 0, false, false
    );
    insert into resultados values (9, 'Una referencia de 81 caracteres la rechaza la base',
      '23514', 'LA ACEPTO', false);
  exception when check_violation then
    insert into resultados values (9, 'Una referencia de 81 caracteres la rechaza la base',
      '23514', sqlstate, true);
  end;

  -- 10. Solo espacios: length(trim(...)) = 0, fuera del rango 1..80.
  begin
    insert into public.ride_requests (
      id, passenger_id, status, passenger_count, origin, origin_label,
      destination, destination_label, contact_phone, expires_at, pickup_reference,
      service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_base, a.pasajero, 'searching', 1, v_geo, 'Zz ref A', v_geo, 'Zz ref B',
      '3000000303', now() + interval '5 minutes', '    ',
      'passenger', 4000, 4000, 0, false, false
    );
    insert into resultados values (10, 'Una referencia de solo espacios la rechaza la base',
      '23514', 'LA ACEPTO', false);
  exception when check_violation then
    insert into resultados values (10, 'Una referencia de solo espacios la rechaza la base',
      '23514', sqlstate, true);
  end;

  -- 11. 80 caracteres justos: entra.
  begin
    insert into public.ride_requests (
      id, passenger_id, status, passenger_count, origin, origin_label,
      destination, destination_label, contact_phone, expires_at, pickup_reference,
      service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
    ) values (
      v_base, a.otro, 'searching', 1, v_geo, 'Zz ref A', v_geo, 'Zz ref B',
      '3000000304', now() + interval '5 minutes', repeat('x', 80),
      'passenger', 4000, 4000, 0, false, false
    );
    insert into resultados values (11, 'Una referencia de 80 caracteres justos entra',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (11, 'Una referencia de 80 caracteres justos entra',
      'entra', 'RECHAZADA ' || sqlstate, false);
  end;
  update public.ride_requests set status = 'expired' where id = v_base;

  -- D172: la referencia NO viaja en la oferta, solo la ve el conductor que acepto.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, expires_at, pickup_reference,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_rq, a.otro, 'searching', 1, v_geo, 'Zz ref origen', v_geo, 'Zz ref destino',
    '3000000305', now() + interval '5 minutes', 'Zz frente al kiosco azul',
    'passenger', 4000, 4000, 0, false, false
  );
  insert into public.ride_offers (request_id, driver_id, expires_at, response, offered_at, distance_m)
  values (v_rq, a.conductor, now() + interval '2 minutes', 'pending', now(), 90)
  returning id into v_offer;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);

  -- 12. La oferta se ve.
  select count(*) into v_n from public.list_driver_offers() where request_id = v_rq;
  insert into resultados values (12, 'La oferta le llega al conductor',
    '1', v_n::text, v_n = 1);

  -- 13. Pero sin la referencia de recogida: no es una columna de la oferta.
  select (to_jsonb(o) ? 'pickup_reference') into v_tiene
  from public.list_driver_offers() o where o.request_id = v_rq;
  insert into resultados values (13, 'D172: la oferta NO lleva la referencia de recogida',
    'false', coalesce(v_tiene::text, 'nulo'), v_tiene = false);

  -- 14. Al aceptar, ya la ve.
  select public.accept_ride_offer(v_offer) into v_ride;
  select pickup_reference into v_ref from public.list_driver_active_rides() where request_id = v_rq;
  insert into resultados values (14, 'D172: aceptada, el conductor SI ve la referencia',
    'Zz frente al kiosco azul', coalesce(v_ref, 'nulo'), v_ref = 'Zz frente al kiosco azul');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$referencia$;


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
