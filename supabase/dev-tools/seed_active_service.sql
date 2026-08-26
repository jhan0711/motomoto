-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Crea DOS servicios en curso para poder mirar el tablero del panel (Fase 20,
-- paso 3) con contenido de verdad. Sin esto el tablero se ve vacio: al empezar
-- el paso, las 57 solicitudes de la base estaban todas terminadas, canceladas o
-- caducadas.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_active_service.sql
--
-- **ESTE SI DEJA FILAS**, a diferencia de los `prueba_*.sql`, porque el tablero
-- tiene que poder mirarse desde el navegador. Para limpiarlas:
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/remove_active_service.sql
--
-- Es idempotente: se puede ejecutar varias veces sin duplicar nada.
-- =============================================================================

do $semilla$
declare
  -- Identificadores fijos y reconocibles, para poder borrarlos despues.
  c_req_busca constant uuid := 'ad000000-0000-4000-8000-000000000001';
  c_req_curso constant uuid := 'ad000000-0000-4000-8000-000000000002';
  c_ride      constant uuid := 'ad000000-0000-4000-8000-00000000c002';

  v_pas1 uuid;
  v_pas2 uuid;
  v_cond uuid;
  v_veh  uuid;
  v_o_lng double precision;
  v_o_lat double precision;
  v_d_lng double precision;
  v_d_lat double precision;
  v_o_lbl text;
  v_d_lbl text;
begin
  -- Dos pasajeros distintos: la regla R6 solo admite un servicio vivo por
  -- pasajero, asi que dos servicios activos necesitan dos personas.
  select id into v_pas1 from public.profiles
  where role = 'passenger' and status = 'active' order by created_at limit 1;

  select id into v_pas2 from public.profiles
  where role = 'passenger' and status = 'active' and id <> v_pas1
  order by created_at limit 1;

  select d.id into v_cond from public.drivers d
  join public.profiles p on p.id = d.id
  where d.approval_status = 'approved' order by p.created_at limit 1;

  select v.id into v_veh from public.vehicles v where v.status = 'active' limit 1;

  -- Dos lugares reales de Amalfi, para que las etiquetas del tablero digan algo
  -- y no "punto en el mapa".
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry), name
    into v_o_lng, v_o_lat, v_o_lbl
  from public.places where is_active order by sort_order, name limit 1;

  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry), name
    into v_d_lng, v_d_lat, v_d_lbl
  from public.places where is_active order by sort_order, name offset 1 limit 1;

  -- Se limpia antes de sembrar, para que el archivo se pueda repetir.
  delete from public.ride_offers where request_id in (c_req_busca, c_req_curso);
  delete from public.rides where request_id in (c_req_busca, c_req_curso);
  delete from public.ride_requests where id in (c_req_busca, c_req_curso);

  -- 1. Uno BUSCANDO, pedido hace tres minutos, para que el tablero lo marque en
  --    amarillo y se vea que la espera se calcula de verdad.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural, pickup_reference
  ) values (
    c_req_busca, v_pas1, 'searching', 2,
    extensions.st_setsrid(extensions.st_makepoint(v_o_lng, v_o_lat), 4326)::extensions.geography,
    v_o_lbl,
    extensions.st_setsrid(extensions.st_makepoint(v_d_lng, v_d_lat), 4326)::extensions.geography,
    v_d_lbl,
    '3001234567', now() - interval '3 minutes', now() + interval '10 minutes',
    'passenger', 6200, 6200, 0, false, false,
    'Frente a la tienda, portón verde'
  );

  -- Con una oferta viva encima, para ver el recuento de ofertas del tablero.
  insert into public.ride_offers (request_id, driver_id, expires_at, response, offered_at)
  values (c_req_busca, v_cond, now() + interval '5 minutes', 'pending', now());

  -- 2. Uno EN RECORRIDO, para ver el bloque del conductor y la antiguedad de su
  --    posicion.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    assigned_at, started_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  ) values (
    c_req_curso, v_pas2, 'in_progress', 1,
    extensions.st_setsrid(extensions.st_makepoint(v_d_lng, v_d_lat), 4326)::extensions.geography,
    v_d_lbl,
    extensions.st_setsrid(extensions.st_makepoint(v_o_lng, v_o_lat), 4326)::extensions.geography,
    v_o_lbl,
    '3007654321', now() - interval '12 minutes', now() + interval '10 minutes',
    now() - interval '10 minutes', now() - interval '6 minutes',
    'passenger', 4000, 4000, 0, false, false
  );

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    c_ride, c_req_curso, v_cond, v_veh, 'in_progress', 1,
    now() - interval '10 minutes', now() - interval '7 minutes',
    now() - interval '6 minutes'
  );
end
$semilla$;


-- Comprobacion: se pregunta a la MISMA funcion que usa el panel, no a las
-- tablas por separado. Si esto devuelve dos filas, el tablero mostrara dos
-- tarjetas; si devuelve cero, algo falta por mucho que las tablas parezcan bien.
select
  status::text as estado,
  origin_label || ' -> ' || destination_label as ruta,
  passenger_name,
  fare_amount,
  waiting_seconds,
  pending_offers,
  coalesce(driver_name, '(sin conductor)') as conductor
from public.admin_list_active_services()
where request_id::text like 'ad000000%';
