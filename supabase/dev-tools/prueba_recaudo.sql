-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260826110000_driver_history_and_earnings.sql` (bloque especial,
-- paso 7: historial y recaudo del conductor).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_recaudo.sql
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

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Montaje: dos conductores, dos pasajeros, servicios en distintas fechas
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_pas    uuid;
  v_otro   uuid;
  v_cond   uuid;   -- el conductor que hace las pruebas
  v_cond2  uuid;   -- otro conductor, para probar que no ve lo ajeno
  v_veh    uuid;
  v_veh2   uuid;
  v_lng    double precision;
  v_lat    double precision;
  v_hosp_lng double precision;
  v_hosp_lat double precision;
  v_rural_id uuid;
  v_caja   uuid;

  v_rq_hoy     uuid := 'ea000000-0000-4000-8000-000000000001';  -- pasajero, hoy, urbano
  v_rq_semana  uuid := 'ea000000-0000-4000-8000-000000000002';  -- pasajero, esta semana, rural
  v_rq_vieja   uuid := 'ea000000-0000-4000-8000-000000000003';  -- pasajero, hace 10 dias
  v_rq_cancel  uuid := 'ea000000-0000-4000-8000-000000000004';  -- cancelado hoy, no cuenta
  v_rq_otro    uuid := 'ea000000-0000-4000-8000-000000000005';  -- de v_cond2, hoy
  v_rq_parcel  uuid := 'ea000000-0000-4000-8000-000000000006';  -- encomienda, hoy

begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';

  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_hosp_lng, v_hosp_lat
  from public.places where name = 'El hospital';

  -- Un lugar rural de prueba, para que la fila de la semana traiga referencia.
  insert into public.places (name, location, sort_order) values
    ('Zz prueba recaudo rural',
     extensions.st_setsrid(extensions.st_makepoint(-75.074987, 6.997792), 4326)::extensions.geography,
     999);
  select id into v_rural_id from public.places where name = 'Zz prueba recaudo rural';
  insert into public.rural_fares (place_id, amount) values (v_rural_id, 15000);

  select id into v_caja from public.cargo_types where name = 'Caja pequeña';

  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;
  select p.id into v_otro from public.profiles p
  where p.role = 'passenger' and p.status = 'active' and p.id <> v_pas
  order by p.created_at limit 1;

  select d.id into v_cond from public.drivers d order by d.id limit 1;
  select d.id into v_cond2 from public.drivers d where d.id <> v_cond order by d.id limit 1;

  -- LA PRUEBA CREA SU PROPIA ASIGNACION SI NO LA HAY, en vez de dar por hecho
  -- que el conductor tiene motorraton. Dejo de ser cierto el 2026-08-27, cuando
  -- el usuario probo la pantalla de motorratones del panel y quito y reasigno
  -- unidades: el conductor se quedo sin ninguna vigente y esta prueba se cayo
  -- con un 23502, sin que nada estuviera roto.
  --
  -- Es la cuarta vez que una prueba se pone roja por una premisa heredada del
  -- mundo real -antes: el `sum` de prueba_recaudo, y las dos de
  -- prueba_notificaciones-. La regla ya deberia estar aprendida: **una prueba
  -- monta lo que necesita, no lo encuentra.**
  select a.vehicle_id into v_veh
  from public.driver_vehicle_assignments a
  where a.driver_id = v_cond and a.unassigned_at is null;

  if v_veh is null then
    select v.id into v_veh from public.vehicles v where v.status = 'active' limit 1;
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (v_cond, v_veh);
  end if;

  select a.vehicle_id into v_veh2
  from public.driver_vehicle_assignments a
  where a.driver_id = v_cond2 and a.unassigned_at is null;

  if v_veh2 is null then
    select v.id into v_veh2 from public.vehicles v
    where v.status = 'active' and v.id <> v_veh limit 1;
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (v_cond2, v_veh2);
  end if;

  -- Las solicitudes, insertadas directamente con su valor ya calculado: lo que
  -- prueba este archivo es que el historial y el recaudo LEEN bien lo que ya
  -- hay, no el calculo de la tarifa, que ya tiene su propio archivo.
  insert into public.ride_requests (
    id, passenger_id, service_type, passenger_count,
    origin, origin_label, destination, destination_label, contact_phone, expires_at,
    status, requested_at,
    fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural, fare_reference,
    parcel_description
  ) values
    (v_rq_hoy, v_pas, 'passenger', 1,
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'El parque',
     extensions.st_setsrid(extensions.st_makepoint(v_hosp_lng, v_hosp_lat), 4326)::extensions.geography, 'El hospital',
     '3001111111', now() + interval '5 minutes', 'completed', now(),
     4000, 4000, 0, false, false, null, null),
    (v_rq_semana, v_pas, 'passenger', 2,
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'El parque',
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'Zz prueba recaudo rural',
     '3001111111', now() + interval '5 minutes', 'completed', now(),
     15000, 15000, 0, false, true, 'Zz prueba recaudo rural', null),
    (v_rq_vieja, v_otro, 'passenger', 1,
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'El parque',
     extensions.st_setsrid(extensions.st_makepoint(v_hosp_lng, v_hosp_lat), 4326)::extensions.geography, 'El hospital',
     '3002222222', now() + interval '5 minutes', 'completed', now() - interval '10 days',
     4000, 4000, 0, false, false, null, null),
    (v_rq_cancel, v_pas, 'passenger', 1,
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'El parque',
     extensions.st_setsrid(extensions.st_makepoint(v_hosp_lng, v_hosp_lat), 4326)::extensions.geography, 'El hospital',
     '3001111111', now() + interval '5 minutes', 'searching', now(),
     4000, 4000, 0, false, false, null, null),
    (v_rq_otro, v_otro, 'passenger', 1,
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'El parque',
     extensions.st_setsrid(extensions.st_makepoint(v_hosp_lng, v_hosp_lat), 4326)::extensions.geography, 'El hospital',
     '3002222222', now() + interval '5 minutes', 'completed', now(),
     4000, 4000, 0, false, false, null, null),
    (v_rq_parcel, v_pas, 'parcel', 0,
     extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography, 'El parque',
     extensions.st_setsrid(extensions.st_makepoint(v_hosp_lng, v_hosp_lat), 4326)::extensions.geography, 'El hospital',
     '3001111111', now() + interval '5 minutes', 'completed', now(),
     4000, 4000, 1700, false, false, null, 'Caja con documentos');

  -- La cancelada se inserto como 'searching' y se pasa a 'cancelled' aqui, en
  -- la misma sentencia que pone cancelled_at/cancelled_by: la restriccion
  -- `rr_cancelled_status_matches` mira el estado final de la fila, y las dos
  -- columnas tienen que llegar juntas con el cambio de estado, no en un
  -- `insert` con el estado ya en 'cancelled' y las horas todavia nulas.
  update public.ride_requests
  set status = 'cancelled', cancelled_at = now(), cancelled_by = 'passenger'
  where id = v_rq_cancel;
  insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
  values (v_rq_parcel, v_caja, 1, 1700);

  -- Las ofertas, todas aceptadas: sin oferta no hay fila en `list_driver_history`
  -- ni en `get_driver_job`, aunque el recaudo si vive directo de `rides`.
  insert into public.ride_offers (request_id, driver_id, response, offered_at, responded_at, expires_at, distance_m)
  values
    (v_rq_hoy, v_cond, 'accepted', now(), now(), now() + interval '30 seconds', 100),
    (v_rq_semana, v_cond, 'accepted', now(), now(), now() + interval '30 seconds', 100),
    (v_rq_vieja, v_cond, 'accepted', now() - interval '10 days', now() - interval '10 days', now() - interval '10 days' + interval '30 seconds', 100),
    (v_rq_cancel, v_cond, 'accepted', now(), now(), now() + interval '30 seconds', 100),
    (v_rq_otro, v_cond2, 'accepted', now(), now(), now() + interval '30 seconds', 100),
    (v_rq_parcel, v_cond, 'accepted', now(), now(), now() + interval '30 seconds', 100);

  -- El orden de la linea de tiempo es una restriccion de verdad
  -- (`rides_timeline_order`): un viaje completado necesita tambien
  -- `driver_arrived_at` y `started_at`, no solo `accepted_at` y
  -- `completed_at`. Las cuatro horas van juntas en cada fila.
  insert into public.rides (
    request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at
  )
  values
    (v_rq_hoy, v_cond, v_veh, 'completed', 1, now(), now(), now(), now()),
    (v_rq_semana, v_cond, v_veh, 'completed', 2, now(), now(), now(), now()),
    (v_rq_vieja, v_cond, v_veh, 'completed', 1,
      now() - interval '10 days', now() - interval '10 days',
      now() - interval '10 days', now() - interval '10 days'),
    (v_rq_cancel, v_cond, v_veh, 'cancelled', 1, now(), null, null, null),
    (v_rq_otro, v_cond2, v_veh2, 'completed', 1, now(), now(), now(), now()),
    (v_rq_parcel, v_cond, v_veh, 'completed', 0, now(), now(), now(), now());

  update public.rides set cancelled_at = now(), cancelled_by = 'passenger'
  where request_id = v_rq_cancel;
end
$montaje$;


-- -----------------------------------------------------------------------------
-- El historial: nuevas columnas
-- -----------------------------------------------------------------------------

do $historial$
declare
  v_cond uuid;
  v_of_semana uuid;
  v_of_parcel uuid;
  v_row record;
begin
  select d.id into v_cond from public.drivers d order by d.id limit 1;
  select o.id into v_of_semana from public.ride_offers o
  where o.request_id = 'ea000000-0000-4000-8000-000000000002';
  select o.id into v_of_parcel from public.ride_offers o
  where o.request_id = 'ea000000-0000-4000-8000-000000000006';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);

  -- 1. El historial trae el tipo de servicio, el valor y la referencia rural.
  select service_type, fare_amount, fare_is_rural, fare_reference
    into v_row
  from public.list_driver_history(50, 0)
  where offer_id = v_of_semana;

  insert into resultados values (1, 'El historial trae tipo de servicio y valor del viaje rural',
    'passenger, 15000, rural, Zz prueba recaudo rural',
    coalesce(v_row.service_type::text, 'nulo') || ', ' ||
      coalesce(v_row.fare_amount::text, 'nulo') || ', ' ||
      case when v_row.fare_is_rural then 'rural' else 'urbano' end || ', ' ||
      coalesce(v_row.fare_reference, 'sin referencia'),
    v_row.service_type = 'passenger' and v_row.fare_amount = 15000
      and v_row.fare_is_rural and v_row.fare_reference = 'Zz prueba recaudo rural');

  -- 2. El detalle de la encomienda trae la descripcion y el desglose.
  select service_type, parcel_description, fare_trip_amount, fare_cargo_amount, fare_amount
    into v_row
  from public.get_driver_job(v_of_parcel);

  insert into resultados values (2, 'El detalle de la encomienda trae descripcion y desglose',
    'parcel, Caja con documentos, viaje 4000, carga 1700, total 4000',
    coalesce(v_row.service_type::text, 'nulo') || ', ' ||
      coalesce(v_row.parcel_description, 'nulo') || ', viaje ' ||
      coalesce(v_row.fare_trip_amount::text, 'nulo') || ', carga ' ||
      coalesce(v_row.fare_cargo_amount::text, 'nulo') || ', total ' ||
      coalesce(v_row.fare_amount::text, 'nulo'),
    v_row.service_type = 'parcel' and v_row.parcel_description = 'Caja con documentos'
      and v_row.fare_trip_amount = 4000 and v_row.fare_cargo_amount = 1700
      and v_row.fare_amount = 4000);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$historial$;


-- -----------------------------------------------------------------------------
-- El recaudo
-- -----------------------------------------------------------------------------

do $recaudo$
declare
  v_cond  uuid;
  v_cond2 uuid;
  v_total integer;
  v_n     integer;
  v_h     text;
begin
  select d.id into v_cond from public.drivers d order by d.id limit 1;
  -- Se busca ANTES de cambiar de rol. `drivers` tiene RLS, y buscarlo ya como
  -- 'authenticated' sin `auth.uid()' puesto todavia devolveria cero filas, no
  -- un error: `json_build_object('sub', null, ...)` construye una reclamacion
  -- valida pero vacia, y `auth.uid()` sale nulo sin que nada avise.
  select d.id into v_cond2 from public.drivers d where d.id <> v_cond order by d.id limit 1;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);

  -- LOS CUATRO SIGUIENTES FILTRAN POR request_id::text LIKE 'ea000000%',
  -- LOS DE ESTE ARCHIVO. Este conductor de pruebas acumula servicios reales de
  -- otras sesiones de prueba en el emulador, y sin el filtro el conteo total
  -- dependeria de cuantos haya para cuando se corra esto -es la misma leccion
  -- de `rural_fares` en `prueba_calculo_tarifa.sql`, aplicada aqui a `rides`-.
  -- El total en pesos no necesita el filtro porque los servicios ajenos, de
  -- antes de esta correccion, no tienen `fare_amount` (D217 es posterior a
  -- ellos): sumarlos no cambia el numero, solo el conteo de filas.

  -- 3. HOY trae el urbano y el rural de hoy, no el de hace 10 dias, no el
  --    cancelado, no el de la encomienda... la encomienda SI cuenta, es un
  --    servicio completado. Total: 4.000 + 15.000 + 4.000 = 23.000.
  -- El `sum` tambien lleva el filtro, no solo el `count`: sin el, un servicio
  -- de verdad completado hoy en esta misma cuenta de prueba -de otra sesion,
  -- fuera de esta transaccion- sumaria su valor aunque su `request_id` no sea
  -- de aqui. Es la misma leccion que D233/D234 con `rural_fares`, aplicada al
  -- recaudo: no basta con filtrar el conteo si el total no lleva el mismo
  -- filtro.
  select count(*) filter (where request_id::text like 'ea000000%'),
         sum(fare_amount) filter (where request_id::text like 'ea000000%')
    into v_n, v_total
  from public.list_driver_earnings('today');

  insert into resultados values (3, 'Hoy: tres servicios completados, 23.000 en total',
    '3 servicios, 23000', v_n::text || ' servicios, ' || coalesce(v_total::text, 'nulo'),
    v_n = 3 and v_total = 23000);

  -- 4. El cancelado de hoy NO aparece en ningun periodo.
  insert into resultados values (4, 'Lo cancelado no cuenta como recaudo',
    'ninguna fila con ese request_id', 'comprobado dentro de la 3 por conteo', true);

  -- 5. ESTA SEMANA trae al menos lo de hoy (los tres); lo de hace 10 dias
  --    queda fuera por definicion -una semana ISO dura 7 dias-.
  select count(*) filter (where request_id::text like 'ea000000%')
    into v_n
  from public.list_driver_earnings('week');

  insert into resultados values (5, 'Esta semana: lo de hoy, y lo de hace 10 dias queda fuera',
    '3 de las mias', v_n::text || ' de las mias', v_n = 3);

  -- 6. Un rango personalizado que SI cubre los 10 dias atras trae la fila
  --    vieja ademas de las tres de hoy: cuatro de las mias.
  select count(*) filter (where request_id::text like 'ea000000%')
    into v_n
  from public.list_driver_earnings('custom', (now() - interval '15 days')::date, now()::date);

  insert into resultados values (6, 'Rango que cubre los 10 dias atras: cuatro de las mias',
    '4 de las mias', v_n::text || ' de las mias', v_n = 4);

  -- 7. Un rango personalizado que NO cubre ni hoy ni los 10 dias no trae
  --    ninguna de las mias -puede traer otras, de sesiones de prueba
  --    anteriores, y eso no es lo que se comprueba aqui-.
  select count(*) filter (where request_id::text like 'ea000000%')
    into v_n
  from public.list_driver_earnings('custom', (now() - interval '30 days')::date, (now() - interval '20 days')::date);

  insert into resultados values (7, 'Rango vacio: ninguna de las mias',
    '0 de las mias', v_n::text || ' de las mias', v_n = 0);

  -- 8. Personalizado sin las dos fechas se rechaza.
  begin
    perform public.list_driver_earnings('custom', null, now()::date);
    insert into resultados values (8, 'Personalizado sin fecha de inicio se rechaza',
      'EARNINGS_RANGE_REQUIRED', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'Personalizado sin fecha de inicio se rechaza',
      'EARNINGS_RANGE_REQUIRED', coalesce(v_h, sqlstate), v_h = 'EARNINGS_RANGE_REQUIRED');
  end;

  -- 9. Fecha final antes que la inicial se rechaza.
  begin
    perform public.list_driver_earnings('custom', now()::date, (now() - interval '5 days')::date);
    insert into resultados values (9, 'Fecha final antes que la inicial se rechaza',
      'EARNINGS_RANGE_INVALID', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (9, 'Fecha final antes que la inicial se rechaza',
      'EARNINGS_RANGE_INVALID', coalesce(v_h, sqlstate), v_h = 'EARNINGS_RANGE_INVALID');
  end;

  -- 10. Un periodo que no es 'today', 'week' ni 'custom' se rechaza.
  begin
    perform public.list_driver_earnings('mes');
    insert into resultados values (10, 'Un periodo desconocido se rechaza',
      'EARNINGS_PERIOD_INVALID', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (10, 'Un periodo desconocido se rechaza',
      'EARNINGS_PERIOD_INVALID', coalesce(v_h, sqlstate), v_h = 'EARNINGS_PERIOD_INVALID');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 11. El otro conductor, mirando su propio recaudo de hoy, ve el suyo y no
  --     el de v_cond: un servicio, 4.000.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond2, 'role', 'authenticated')::text);

  -- Mismo filtro que la 3, por la misma razon: sin el, un servicio real de
  -- este conductor completado hoy en otra sesion se colaria en la cuenta.
  select count(*) filter (where request_id::text like 'ea000000%'),
         sum(fare_amount) filter (where request_id::text like 'ea000000%')
    into v_n, v_total
  from public.list_driver_earnings('today');

  insert into resultados values (11, 'Cada conductor ve solo lo suyo: el otro tiene 1 servicio, 4.000',
    '1 servicio, 4000', v_n::text || ' servicios, ' || coalesce(v_total::text, 'nulo'),
    v_n = 1 and v_total = 4000);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 12. Sin sesion, ni siquiera se puede llamar: el permiso se revoco de anon.
  execute 'set local role anon';
  begin
    perform public.list_driver_earnings('today');
    insert into resultados values (12, 'Sin sesion no se puede consultar el recaudo',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (12, 'Sin sesion no se puede consultar el recaudo',
      'rechaza', sqlstate, true);
  end;
  execute 'reset role';
end
$recaudo$;


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
